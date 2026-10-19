import 'package:flutter/widgets.dart';
import '../theme/compass_colors.dart';
import '../theme/compass_theme.dart';
import '../theme/compass_typography.dart';
import '../icons/compass_svg_icons.dart';
import '../models/mongo_models.dart';

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
  });

  @override
  Widget build(BuildContext context) {
    final theme = CompassTheme.of(context);
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
              GestureDetector(
                onTap: onToggleMobileSidebar,
                child: Container(
                  padding: const EdgeInsets.all(6.0),
                  margin: const EdgeInsets.only(right: 8.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: CompassSvg(
                    svgString: CompassSvgIcons.menu,
                    size: 18.0,
                    color: theme.textSecondary,
                  ),
                ),
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
                  ],
                ),
              ),

              const SizedBox(width: 12.0),
              // Vertical divider
              Container(
                width: 1.0,
                height: 20.0,
                color: theme.border,
              ),
              const SizedBox(width: 12.0),

              // Active Connection Pill
              if (connection != null)
                GestureDetector(
                  onTap: onOpenConnectModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: theme.bgSubtle,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: theme.border, width: 1.0),
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
                )
              else
                GestureDetector(
                  onTap: onOpenConnectModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
                    decoration: BoxDecoration(
                      color: CompassColors.warningAmberBg,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: CompassColors.warningAmberBorder, width: 1.0),
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
            ],
          ),

          // Right Zone: Reset, Terminal, Theme Toggle, Disconnect
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Reset Samples Button (hidden when connected to a real database)
              if (showResetSample && onResetData != null) ...[
                GestureDetector(
                  onTap: onResetData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                    decoration: BoxDecoration(
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
                const SizedBox(width: 8.0),
              ],

              // _mongosh Shell Toggle
              GestureDetector(
                onTap: onToggleTerminal,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 6.0),
                  decoration: BoxDecoration(
                    color: isTerminalOpen ? CompassColors.greenForest : theme.bgSubtle,
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

              const SizedBox(width: 8.0),

              // Theme toggle button
              GestureDetector(
                onTap: onToggleDarkMode,
                child: Container(
                  padding: const EdgeInsets.all(7.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6.0),
                  ),
                  child: CompassSvg(
                    svgString: isDarkMode ? CompassSvgIcons.sun : CompassSvgIcons.moon,
                    size: 16.0,
                    color: isDarkMode ? CompassColors.warningAmber : theme.textSecondary,
                  ),
                ),
              ),

              const SizedBox(width: 8.0),

              // Disconnect / Connect Button
              if (connection != null)
                GestureDetector(
                  onTap: onDisconnect,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: CompassColors.errorRedBg,
                      borderRadius: BorderRadius.circular(6.0),
                      border: Border.all(color: CompassColors.errorRedBorder, width: 1.0),
                    ),
                    child: Text(
                      'Disconnect',
                      style: CompassTypography.bodyMedium(color: CompassColors.errorRed),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onOpenConnectModal,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: theme.accent,
                      borderRadius: BorderRadius.circular(6.0),
                    ),
                    child: Text(
                      'Connect',
                      style: CompassTypography.header(color: theme.onAccent),
                    ),
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
}
