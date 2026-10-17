import 'package:flutter/widgets.dart';
import '../../theme/compass_colors.dart';
import '../../theme/compass_typography.dart';
import '../../icons/compass_svg_icons.dart';

/// Converted from src/components/ExportLanguageModal.tsx
/// Includes Dart / Flutter mongo_dart code generation!
class ExportLanguageModal extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final String dbName;
  final String collName;
  final String filter;
  final String sort;

  const ExportLanguageModal({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.dbName,
    required this.collName,
    required this.filter,
    required this.sort,
  });

  @override
  State<ExportLanguageModal> createState() => _ExportLanguageModalState();
}

class _ExportLanguageModalState extends State<ExportLanguageModal> {
  String _selectedLang = 'dart'; // dart, node, python, java, csharp

  String _generateSnippet() {
    final f = widget.filter.isEmpty ? '{}' : widget.filter;
    switch (_selectedLang) {
      case 'dart':
        return '''// Flutter / Dart (using mongo_dart)
import 'package:mongo_dart/mongo_dart.dart';

Future<void> runQuery() async {
  final db = await Db.create('mongodb://localhost:27017/${widget.dbName}');
  await db.open();
  
  final coll = db.collection('${widget.collName}');
  final cursor = coll.find(where.raw($f));
  
  await for (final doc in cursor) {
    print(doc);
  }
  
  await db.close();
}''';
      case 'node':
        return '''// Node.js (MongoDB Driver)
const { MongoClient } = require('mongodb');

async function run() {
  const client = new MongoClient('mongodb://localhost:27017');
  await client.connect();
  const db = client.db('${widget.dbName}');
  const coll = db.collection('${widget.collName}');
  
  const cursor = coll.find($f);
  const results = await cursor.toArray();
  console.log(results);
  await client.close();
}
run();''';
      case 'python':
        return '''# Python (PyMongo)
from pymongo import MongoClient

client = MongoClient('mongodb://localhost:27017')
db = client['${widget.dbName}']
coll = db['${widget.collName}']

cursor = coll.find($f)
for doc in cursor:
    print(doc)''';
      default:
        return '// Query exported';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isOpen) return const SizedBox.shrink();

    return Positioned.fill(
      child: Container(
        color: CompassColors.modalOverlay,
        alignment: Alignment.center,
        child: Container(
          width: 580.0,
          margin: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
            color: CompassColors.darkBgPanel,
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(color: CompassColors.darkBorder, width: 1.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66000000),
                blurRadius: 24.0,
                offset: Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const CompassSvg(
                        svgString: CompassSvgIcons.code,
                        size: 16.0,
                        color: CompassColors.greenAccent,
                      ),
                      const SizedBox(width: 8.0),
                      Text('Export Query to Language', style: CompassTypography.title()),
                    ],
                  ),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const CompassSvg(
                      svgString: CompassSvgIcons.close,
                      size: 14.0,
                      color: CompassColors.darkTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14.0),

              // Language selector tabs
              Row(
                children: [
                  _buildLangTab('dart', 'Dart (Flutter)'),
                  const SizedBox(width: 6.0),
                  _buildLangTab('node', 'Node.js'),
                  const SizedBox(width: 6.0),
                  _buildLangTab('python', 'Python'),
                ],
              ),

              const SizedBox(height: 12.0),

              // Generated code block
              Container(
                height: 220.0,
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: CompassColors.darkBgInput,
                  borderRadius: BorderRadius.circular(6.0),
                  border: Border.all(color: CompassColors.darkBorder, width: 1.0),
                ),
                child: Text(
                  _generateSnippet(),
                  style: CompassTypography.monoRegular(color: CompassColors.darkTextSecondary, size: 12.0),
                ),
              ),

              const SizedBox(height: 16.0),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: widget.onClose,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
                      decoration: BoxDecoration(
                        color: CompassColors.greenAccent,
                        borderRadius: BorderRadius.circular(6.0),
                      ),
                      child: Text('Done', style: CompassTypography.header(color: CompassColors.greenNavy)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangTab(String langKey, String label) {
    final isSelected = _selectedLang == langKey;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLang = langKey);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
        decoration: BoxDecoration(
          color: isSelected ? CompassColors.greenBadgeBg : CompassColors.darkBgSubtle,
          borderRadius: BorderRadius.circular(6.0),
          border: Border.all(
            color: isSelected ? CompassColors.greenBadgeBorder : CompassColors.darkBorder,
            width: 1.0,
          ),
        ),
        child: Text(
          label,
          style: isSelected
              ? CompassTypography.header(color: CompassColors.greenAccent)
              : CompassTypography.bodyRegular(color: CompassColors.darkTextSecondary),
        ),
      ),
    );
  }
}
