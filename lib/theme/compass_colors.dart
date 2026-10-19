import 'package:flutter/painting.dart';

/// Exact hexadecimal colors extracted from the MongoDB Compass React web implementation.
/// Adheres strictly to the UI constraints: no Material 3 default colors or system gradients.
class CompassColors {
  // Dark theme palette (MongoDB Compass Signature Dark)
  static const Color darkBgApp = Color(0xFF0C1014);
  static const Color darkBgSidebar = Color(0xFF11161B);
  static const Color darkBgPanel = Color(0xFF11161B);
  static const Color darkBgSubtle = Color(0xFF162029);
  static const Color darkBgHover = Color(0xFF1C2D38);
  static const Color darkBgInput = Color(0xFF0C1014);
  static const Color darkBorder = Color(0xFF21313C);
  static const Color darkBorderHover = Color(0xFF2B4050);
  
  static const Color darkTextPrimary = Color(0xFFF9FBFA);
  static const Color darkTextSecondary = Color(0xFFC1C7C6);
  static const Color darkTextMuted = Color(0xFF889397);

  // MongoDB Signature Forest & Spring Green Accents
  static const Color greenAccent = Color(0xFF00ED64);
  static const Color greenHover = Color(0xFF00C954);
  static const Color greenForest = Color(0xFF00684A);
  static const Color greenDeep = Color(0xFF023430);
  static const Color greenNavy = Color(0xFF001E2B);

  // Accent Badge Tokens (dark mode)
  static const Color greenBadgeBg = Color(0x1A00ED64); // rgba(0, 237, 100, 0.10)
  static const Color greenBadgeBorder = Color(0x4000ED64); // rgba(0, 237, 100, 0.25)
  static const Color greenBadgeText = Color(0xFF00ED64);

  // Accent Badge Tokens (light mode) - forest green tints read better on white
  static const Color lightGreenBadgeBg = Color(0x1400684A); // rgba(0, 104, 74, 0.08)
  static const Color lightGreenBadgeBorder = Color(0x3300684A); // rgba(0, 104, 74, 0.20)

  // Content colour drawn on top of an accent-coloured fill
  static const Color lightOnAccent = Color(0xFFFFFFFF);

  // Light theme palette
  static const Color lightBgApp = Color(0xFFF9FBFA);
  static const Color lightBgSidebar = Color(0xFFF4F6F8);
  static const Color lightBgPanel = Color(0xFFFFFFFF);
  static const Color lightBgSubtle = Color(0xFFF0F4F2);
  static const Color lightBgHover = Color(0xFFE8EDEB);
  static const Color lightBgInput = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8EDEB);
  static const Color lightBorderHover = Color(0xFFC1C7C6);
  static const Color lightTextPrimary = Color(0xFF1C2D38);
  static const Color lightTextSecondary = Color(0xFF5C6C75);
  static const Color lightTextMuted = Color(0xFF889397);

  // Semantic Alert & Status Colors
  static const Color errorRed = Color(0xFFF43F5E);
  static const Color errorRedBg = Color(0x1AF43F5E);
  static const Color errorRedBorder = Color(0x4DF43F5E);

  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningAmberBg = Color(0x1AF59E0B);
  static const Color warningAmberBorder = Color(0x4DF59E0B);

  static const Color infoBlue = Color(0xFF3B82F6);
  static const Color infoBlueBg = Color(0x1A3B82F6);
  static const Color infoBlueBorder = Color(0x4D3B82F6);

  static const Color purpleBadge = Color(0xFFA855F7);
  static const Color cyanBadge = Color(0xFF06B6D4);

  // BSON Type specific syntax colors (Dark Mode)
  static const Color bsonObjectId = Color(0xFF00ED64);
  static const Color bsonString = Color(0xFF6EE7B7);
  static const Color bsonNumber = Color(0xFFFDE047);
  static const Color bsonBoolean = Color(0xFF93C5FD);
  static const Color bsonDate = Color(0xFFC084FC);
  static const Color bsonNull = Color(0xFFFB7185);

  // BSON Type specific syntax colors (Light Mode) - darker tones for contrast on white
  static const Color lightBsonObjectId = Color(0xFF00684A);
  static const Color lightBsonString = Color(0xFF047857);
  static const Color lightBsonNumber = Color(0xFF9A6700);
  static const Color lightBsonBoolean = Color(0xFF1D4ED8);
  static const Color lightBsonDate = Color(0xFF7E22CE);
  static const Color lightBsonNull = Color(0xFFBE123C);

  // Scrollbar colors
  static const Color scrollbarThumb = Color(0xFF21313C);
  static const Color scrollbarHover = Color(0xFF2B4050);

  // Modal backdrop
  static const Color modalOverlay = Color(0x99000000); // 60% black
}
