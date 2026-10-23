import 'package:flutter/widgets.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_density.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../models/mongo_models.dart';
import 'compass_hover.dart';
import 'compass_icon_button.dart';

/// Converted from src/components/Header.tsx
/// Adheres strictly to:
/// 1. Layout & Flexbox (h-14 / 56px, Row, exact SizedBox gap values)
/// 2. Color & Styling (Color(0xFF...))
/// 3. Typography (explicit CompassTypography)
/// 4. Platform Agnosticism (no native AppBar)
/// 5. Icons (CompassSvg instead of Icon)
class CompassHeader extends StatelessWidget {
  final ConnectionProfile? connection;
  final VoidCallback onOpenConnectModal;
  final VoidCallback onDisconnect;
  final VoidCallback? onResetData;
  final bool showResetSample;
  final bool isTerminalOpen;
  final VoidCallback onToggleTerminal;
  final bool isDarkMode;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onToggleMobileSidebar;

  /// Whether the drawer toggle is offered. The sidebar is permanently docked
  /// on desktop, so the hamburger is dead weight there.
  final bool isMobile;

  /// Opens the overflow sheet that hosts the header actions which do not fit
  /// on a narrow screen (reset samples, `_mongosh`, disconnect). Only wired up
  /// on touch layouts.
  final VoidCallback? onOpenActions;

  const CompassHeader({
    super.key,
    required this.connection,
    required this.onOpenConnectModal,
    required this.onDisconnect,
    this.onResetData,
    this.showResetSample = true,
    required this.isTerminalOpen,
    required this.onToggleTerminal,
    required this.isDarkMode,
    required this.onToggleDarkMode,
    required this.onToggleMobileSidebar,
    this.isMobile = false,
    this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
    final density = CompassDensity.of(context);

    // The full header (logo, version, connection pill, reset samples,
    // `_mongosh`, theme, disconnect) needs roughly 780 px. Below that the
    // secondary controls move into the overflow sheet.
    final windowWidth = MediaQuery.maybeOf(context)?.size.width ?? 1200.0;
    final compact = windowWidth < 1100.0;

    return Container(
      decoration: BoxDecoration(
        color: theme.bgPanel,
        border: Border(
          bottom: BorderSide(
            color: theme.border,
            width: 1.0,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56.0, // CSS h-14
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Zone: Mobile toggle, Logo, Version, Connection Pill
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Mobile Drawer toggle button
              if (isMobile)
                CompassIconButton(
                  svgString: CompassSvgIcons.menu,
                  onTap: onToggleMobileSidebar,
                  size: 18.0,
                  padding: 6.0,
                  color: theme.textSecondary,
                  semanticLabel: 'Toggle sidebar',
                ),

              // MongoDB Leaf Logo Button
              GestureDetector(
                onTap: onOpenConnectModal,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28.0,
                      height: 28.0,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            CompassColors.greenAccent,
                            CompassColors.greenForest,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6.0),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 4.0,
                            offset: Offset(0, 1),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: const CompassSvg(
                        svgString: CompassSvgIcons.mongoLeaf,
                        size: 18.0,
                      ),
                    ),
                    const SizedBox(width: 8.0), // exact CSS gap
                    Text(
                      'Compass',
                      style: CompassTypography.title(color: theme.textPrimary),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 3.0),
                      Text(
                        'Flutter',
                        style: CompassTypography.title(color: theme.accent),
                      ),
                      const SizedBox(width: 6.0),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5.0, vertical: 2.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4.0),
                          border: Border.all(color: theme.border, width: 1.0),
                        ),
                        child: Text(
                          '7.0.8',
                          style: CompassTypography.caption(color: theme.textMuted),
                        ),
                      ),
                    ] else ...[
                      // On a phone the version badge and the connection pill do
                      // not fit; a status dot keeps the state visible.
                      const SizedBox(width: 8.0),
                      Container(
                        width: 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          color: connection != null
                              ? theme.accent
                              : CompassColors.warningAmber,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              if (!compact) ...[
                const SizedBox(width: 12.0),
                // Vertical divider
                Container(
                  width: 1.0,
                  height: 20.0,
                  color: theme.border,
                ),
                const SizedBox(width: 12.0),
              ],

              // Active Connection Pill
              if (connection != null && !compact)
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: density.minTapTarget),
                  child: CompassHover(
                    onTap: onOpenConnectModal,
                    semanticLabel: 'Change connection',
                    builder: (hovered) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: hovered ? theme.bgHover : theme.bgSubtle,
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: hovered ? theme.borderHover : theme.border,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8.0,
                            height: 8.0,
                            decoration: BoxDecoration(
                              color: theme.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            connection!.name,
                            style: CompassTypography.bodyMedium(color: theme.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              else if (!compact)
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: density.minTapTarget),
                  child: CompassHover(
                    onTap: onOpenConnectModal,
                    semanticLabel: 'Connect to a database',
                    builder: (hovered) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                      decoration: BoxDecoration(
                        color: CompassColors.warningAmberBg,
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: hovered
                              ? CompassColors.warningAmber
                              : CompassColors.warningAmberBorder,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CompassSvg(
                            svgString: CompassSvgIcons.zap,
                            size: 14.0,
                            color: CompassColors.warningAmber,
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            'Connect',
                            style: CompassTypography.bodyMedium(color: CompassColors.warningAmber),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Right Zone: Reset, Terminal, Theme Toggle, Disconnect
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Everything below only fits on a wide screen; on a narrow
              // window the actions move into the overflow sheet.
              if (!compact) ...[
                // Reset Samples Button (hidden when connected to a real database)
                if (showResetSample && onResetData != null) ...[
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: density.minTapTarget),
                    child: CompassHover(
                      onTap: onResetData,
                      semanticLabel: 'Reset sample data',
                      builder: (hovered) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: hovered ? theme.bgHover : null,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CompassSvg(
                              svgString: CompassSvgIcons.rotateCcw,
                              size: 14.0,
                              color: theme.textSecondary,
                            ),
                            const SizedBox(width: 6.0),
                            Text(
                              'Reset Samples',
                              style: CompassTypography.bodyRegular(color: theme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                ],

                // _mongosh Shell Toggle
                ConstrainedBox(
                  constraints: BoxConstraints(minHeight: density.minTapTarget),
                  child: CompassHover(
                    onTap: onToggleTerminal,
                    semanticLabel: 'Toggle mongosh terminal',
                    builder: (hovered) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                      decoration: BoxDecoration(
                        color: isTerminalOpen
                            ? CompassColors.greenForest
                            : (hovered ? theme.bgHover : theme.bgSubtle),
                        borderRadius: BorderRadius.circular(6.0),
                        border: Border.all(
                          color: isTerminalOpen ? CompassColors.greenAccent : theme.border,
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CompassSvg(
                            svgString: CompassSvgIcons.terminal,
                            size: 14.0,
                            color: isTerminalOpen ? const Color(0xFFFFFFFF) : theme.accent,
                          ),
                          const SizedBox(width: 6.0),
                          Text(
                            '_mongosh',
                            style: CompassTypography.monoMedium(
                              color: isTerminalOpen ? const Color(0xFFFFFFFF) : theme.textPrimary,
                              size: 11.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8.0),
              ],

              // Theme toggle button
              CompassIconButton(
                svgString: isDarkMode ? CompassSvgIcons.sun : CompassSvgIcons.moon,
                onTap: onToggleDarkMode,
                size: 16.0,
                padding: 7.0,
                color: isDarkMode ? CompassColors.warningAmber : theme.textSecondary,
                semanticLabel: isDarkMode ? 'Switch to light theme' : 'Switch to dark theme',
              ),

              if (!compact) ...[
                const SizedBox(width: 8.0),

                // Disconnect / Connect Button
                if (connection != null)
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: density.minTapTarget),
                    child: CompassHover(
                      onTap: onDisconnect,
                      semanticLabel: 'Disconnect',
                      builder: (hovered) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: hovered
                              ? const Color(0x33F43F5E)
                              : CompassColors.errorRedBg,
                          borderRadius: BorderRadius.circular(6.0),
                          border: Border.all(
                            color: hovered
                                ? CompassColors.errorRed
                                : CompassColors.errorRedBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          'Disconnect',
                          style: CompassTypography.bodyMedium(color: CompassColors.errorRed),
                        ),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: BoxConstraints(minHeight: density.minTapTarget),
                    child: CompassHover(
                      onTap: onOpenConnectModal,
                      semanticLabel: 'Connect',
                      builder: (hovered) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                        decoration: BoxDecoration(
                          color: hovered ? CompassColors.greenHover : theme.accent,
                          borderRadius: BorderRadius.circular(6.0),
                        ),
                        child: Text(
                          'Connect',
                          style: CompassTypography.header(color: theme.onAccent),
                        ),
                      ),
                    ),
                  ),
              ] else ...[
                const SizedBox(width: 4.0),

                // Overflow trigger: hosts the header actions that do not fit.
                CompassIconButton(
                  svgString: CompassSvgIcons.moreVertical,
                  onTap: onOpenActions,
                  size: 18.0,
                  padding: 7.0,
                  color: theme.textSecondary,
                  semanticLabel: 'More actions',
                ),
              ],
            ],
          ),
        ],
      ),
    ),
  ),
);
  }
}
