import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import '../../icons/compass_svg_icons.dart';
import '../../models/mongo_models.dart';
import '../../services/mongo_engine.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_theme.dart';
import '../../theme/compass_typography.dart';
import 'compass_modal.dart';

enum ImportExportMode { export, import }

/// Converted from src/components/ImportExportModal.tsx
///
/// The React version triggers a browser file download. Here export can either
/// write the serialized collection to the system clipboard (and preview it) or
/// save it to disk via the native "Save As" dialog, while import accepts either
/// pasted JSON or a `.json` file chosen from disk via the `file_selector`
/// plugin.
class ImportExportModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final ImportExportMode mode;
  final String dbName;
  final String collName;
  final List<MongoDocument> documents;
  final VoidCallback onImportComplete;

  const ImportExportModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.mode,
    required this.dbName,
    required this.collName,
    required this.documents,
    required this.onImportComplete,
  });

  @override
  State<ImportExportModal> createState() => _ImportExportModalState();
}

class _ImportExportModalState extends State<ImportExportModal> {
  String _format = 'json';
  late final TextEditingController _importController = TextEditingController();
  String? _statusText;
  bool _statusIsError = false;
  String _exportPreview = '';
  String? _fileName;
  int? _fileDocumentCount;
  bool _isPickingFile = false;

  CompassTheme get _theme => CompassTheme.of(context);

  @override
  void didUpdateWidget(covariant ImportExportModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOpen && !oldWidget.isOpen) {
      _format = 'json';
      _importController.text = '';
      _statusText = null;
      _statusIsError = false;
      _exportPreview = '';
      _fileName = null;
      _fileDocumentCount = null;
      _isPickingFile = false;
    }
  }

  @override
  void dispose() {
    _importController.dispose();
    super.dispose();
  }

  String _buildExportContent() {
    if (_format == 'json') {
      return const JsonEncoder.withIndent('  ')
          .convert(widget.documents.map((d) => d.data).toList());
    }

    if (widget.documents.isEmpty) return '';
    final keys = <String>[];
    for (final doc in widget.documents) {
      for (final key in doc.data.keys) {
        if (!keys.contains(key)) keys.add(key);
      }
    }
    final header = keys.join(',');
    final rows = widget.documents.map((d) {
      return keys.map((k) {
        final val = d.data[k];
        if (val == null) return '';
        final str = val is Map || val is List ? jsonEncode(val) : '$val';
        return '"${str.replaceAll('"', '""')}"';
      }).join(',');
    }).toList();
    return [header, ...rows].join('\n');
  }

  Future<void> _handleExport() async {
    final content = _buildExportContent();
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) return;
    setState(() {
      _exportPreview = content;
      _statusText = 'Copied ${widget.documents.length} documents to clipboard.';
      _statusIsError = false;
    });
  }

  /// Opens the native "Save As" dialog and writes the serialized collection to
  /// the chosen file (the port of React's browser download).
  Future<void> _handleDownload() async {
    final content = _buildExportContent();
    final isJson = _format == 'json';
    final extension = isJson ? 'json' : 'csv';
    final suggestedName = '${widget.collName}.$extension';

    try {
      final location = await getSaveLocation(
        suggestedName: suggestedName,
        acceptedTypeGroups: [
          XTypeGroup(
            label: isJson ? 'JSON files' : 'CSV files',
            extensions: [extension],
          ),
        ],
      );
      if (!mounted) return;
      // User cancelled the dialog.
      if (location == null) return;

      await File(location.path).writeAsString(content);
      if (!mounted) return;
      setState(() {
        _exportPreview = content;
        _statusText =
            'Saved ${widget.documents.length} documents to ${location.path}';
        _statusIsError = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _statusText = 'Could not save file: $err';
        _statusIsError = true;
      });
    }
  }

  /// Opens the native file picker, reads the chosen `.json` file, and loads it
  /// into the importer (so the user can review/edit before importing).
  Future<void> _pickJsonFile() async {
    if (_isPickingFile) return;
    setState(() => _isPickingFile = true);
    try {
      const typeGroup = XTypeGroup(label: 'JSON files', extensions: ['json']);
      final file = await openFile(acceptedTypeGroups: [typeGroup]);
      if (!mounted) return;
      if (file == null) {
        // User cancelled the dialog.
        setState(() => _isPickingFile = false);
        return;
      }

      final content = await file.readAsString();
      if (!mounted) return;

      int? documentCount;
      String? parseError;
      try {
        final parsed = jsonDecode(content);
        documentCount = parsed is List ? parsed.length : 1;
      } catch (err) {
        parseError = err.toString();
      }

      setState(() {
        _isPickingFile = false;
        _fileName = file.name;
        _fileDocumentCount = documentCount;
        _importController.text = content;
        if (parseError != null) {
          _statusText =
              'File loaded, but the JSON could not be parsed: $parseError';
          _statusIsError = true;
        } else {
          _statusText = 'Loaded "${file.name}" ($documentCount document'
              '${documentCount == 1 ? '' : 's'}). Ready to import.';
          _statusIsError = false;
        }
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isPickingFile = false;
        _statusText = 'Could not read file: $err';
        _statusIsError = true;
      });
    }
  }

  void _handleImport() {
    if (_importController.text.trim().isEmpty) {
      setState(() {
        _statusText = 'Please paste JSON documents';
        _statusIsError = true;
      });
      return;
    }

    try {
      final parsed = jsonDecode(_importController.text);
      final docsToInsert = parsed is List ? parsed : [parsed];
      final service = mongoEngine;

      for (final d in docsToInsert) {
        if (d is Map) {
          service.insertDocument(
              widget.dbName, widget.collName, Map<String, dynamic>.from(d));
        }
      }

      setState(() {
        _statusText = 'Successfully imported ${docsToInsert.length} documents!';
        _statusIsError = false;
      });

      Future.delayed(const Duration(seconds: 1), () {
        if (!mounted) return;
        widget.onImportComplete();
        widget.onClose();
      });
    } catch (err) {
      setState(() {
        _statusText = 'Import parsing error: $err';
        _statusIsError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExport = widget.mode == ImportExportMode.export;
    return CompassModalShell(
      isOpen: widget.isOpen,
      maxWidth: 512.0,
      onBackdropTap: widget.onClose,
      children: [
        CompassModalHeader(
          title: isExport
              ? 'Export Collection "${widget.collName}"'
              : 'Import into "${widget.collName}"',
          iconSvg: isExport ? CompassSvgIcons.download : CompassSvgIcons.upload,
          onClose: widget.onClose,
        ),
        const SizedBox(height: 14.0),
        if (isExport) ..._buildExportBody() else ..._buildImportBody(),
      ],
    );
  }

  List<Widget> _buildExportBody() {
    return [
      const CompassFieldLabel(label: 'Select Export Format'),
      Row(
        children: [
          Expanded(
            child: _formatCard(
              id: 'json',
              title: 'JSON',
              description: 'Full BSON / nested structures',
            ),
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: _formatCard(
              id: 'csv',
              title: 'CSV',
              description: 'Spreadsheet comma-separated',
            ),
          ),
        ],
      ),
      const SizedBox(height: 12.0),
      Text(
        'Will export currently matched ${widget.documents.length} documents.',
        style: CompassTypography.caption(color: _theme.textMuted),
      ),
      if (_exportPreview.isNotEmpty) ...[
        const SizedBox(height: 10.0),
        Container(
          constraints: const BoxConstraints(maxHeight: 140.0),
          padding: const EdgeInsets.all(10.0),
          decoration: BoxDecoration(
            color: _theme.bgInput,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(color: _theme.border, width: 1.0),
          ),
          child: SingleChildScrollView(
            child: Text(
              _exportPreview,
              style: CompassTypography.monoSmall(
                  color: _theme.textSecondary),
            ),
          ),
        ),
      ],
      if (_statusText != null) ...[
        const SizedBox(height: 10.0),
        _statusBanner(),
      ],
      CompassModalFooter(
        children: [
          CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
          CompassSecondaryButton(
            label: 'Copy to Clipboard',
            iconSvg: CompassSvgIcons.copy,
            onTap: _handleExport,
          ),
          CompassPrimaryButton(
            label: 'Download',
            iconSvg: CompassSvgIcons.download,
            onTap: _handleDownload,
          ),
        ],
      ),
    ];
  }

  List<Widget> _buildImportBody() {
    return [
      const CompassFieldLabel(label: 'Upload JSON File'),
      _buildFilePicker(),
      const SizedBox(height: 14.0),
      const CompassFieldLabel(label: 'or Paste JSON Data'),
      CompassInput(
        controller: _importController,
        placeholder: "[ { title: 'Document 1' }, { title: 'Document 2' } ]",
        maxLines: 8,
        autoIndent: true,
        onChanged: (_) {
          if (_statusText != null) setState(() => _statusText = null);
        },
      ),
      if (_statusText != null) ...[
        const SizedBox(height: 10.0),
        _statusBanner(),
      ],
      CompassModalFooter(
        children: [
          CompassSecondaryButton(label: 'Cancel', onTap: widget.onClose),
          CompassPrimaryButton(
            label: 'Import Documents',
            iconSvg: CompassSvgIcons.upload,
            onTap: _handleImport,
          ),
        ],
      ),
    ];
  }

  Widget _buildFilePicker() {
    final hasFile = _fileName != null;
    final subtitle = hasFile
        ? (_fileDocumentCount != null
            ? '$_fileDocumentCount document${_fileDocumentCount == 1 ? '' : 's'} ready'
            : 'Selected file')
        : 'Choose a .json file exported from Compass or MongoDB';

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: hasFile ? _theme.greenBadgeBg : _theme.bgInput,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: hasFile ? _theme.accent : _theme.border,
          width: 1.0,
        ),
      ),
      child: Row(
        children: [
          CompassSvg(
            svgString: hasFile ? CompassSvgIcons.file : CompassSvgIcons.upload,
            size: 18.0,
            color: hasFile
                ? _theme.accent
                : _theme.textMuted,
          ),
          const SizedBox(width: 10.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasFile ? _fileName! : 'No file selected',
                  style: CompassTypography.bodyMedium(
                    color: hasFile
                        ? _theme.textPrimary
                        : _theme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2.0),
                Text(
                  subtitle,
                  style: CompassTypography.caption(
                      color: _theme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          CompassSecondaryButton(
            label: _isPickingFile
                ? 'Opening…'
                : (hasFile ? 'Change File' : 'Choose JSON File'),
            onTap: _isPickingFile ? null : _pickJsonFile,
          ),
        ],
      ),
    );
  }

  Widget _formatCard({
    required String id,
    required String title,
    required String description,
  }) {
    final selected = _format == id;
    return GestureDetector(
      onTap: () => setState(() {
        _format = id;
        _exportPreview = '';
        _statusText = null;
      }),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color:
              selected ? _theme.greenBadgeBg : _theme.bgInput,
          borderRadius: BorderRadius.circular(8.0),
          border: Border.all(
            color:
                selected ? _theme.accent : _theme.border,
            width: 1.0,
          ),
        ),
        child: Row(
          children: [
            CompassSvg(
                svgString: CompassSvgIcons.code,
                size: 15.0,
                color: _theme.accent),
            const SizedBox(width: 8.0),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: CompassTypography.header(
                        color: _theme.textPrimary)),
                Text(description,
                    style: CompassTypography.caption(
                        color: _theme.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBanner() {
    final color =
        _statusIsError ? CompassColors.errorRed : _theme.accent;
    final bg =
        _statusIsError ? CompassColors.errorRedBg : _theme.greenBadgeBg;
    final border = _statusIsError
        ? CompassColors.errorRedBorder
        : _theme.greenBadgeBorder;
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: border, width: 1.0),
      ),
      child: Row(
        children: [
          CompassSvg(
            svgString: _statusIsError
                ? CompassSvgIcons.activity
                : CompassSvgIcons.check,
            size: 13.0,
            color: color,
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(_statusText!,
                style: CompassTypography.caption(color: color)),
          ),
        ],
      ),
    );
  }
}
