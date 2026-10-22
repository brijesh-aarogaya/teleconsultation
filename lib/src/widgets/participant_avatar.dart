import 'package:flutter/material.dart';

/// Reusable participant avatar widget.
///
/// Ensures consistent initials, colors, and styling across waiting screens,
/// camera-off placeholders, PiP thumbnails, and grid layouts.
///
/// Correctly handles grapheme clusters for non-Latin scripts (Gujarati, Hindi),
/// accented characters, leading/trailing spaces, and empty names.
class ParticipantAvatar extends StatelessWidget {
  final String? name;
  final double size;
  final double? fontSize;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final Widget? badge;

  const ParticipantAvatar({
    super.key,
    required this.name,
    this.size = 96,
    this.fontSize,
    this.backgroundColor = const Color(0xFF2A3942),
    this.borderColor = const Color(0x3DFFFFFF), // white24
    this.borderWidth = 1.5,
    this.badge,
  });

  /// Extracts the first visible grapheme cluster as the initial.
  static String extractInitial(String? raw) {
    if (raw == null) return '?';
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initial = extractInitial(name);
    final calculatedFontSize = fontSize ?? (size * 0.42);

    Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: borderWidth > 0
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
        boxShadow: size > 60
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: Colors.white,
            fontSize: calculatedFontSize,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (badge != null) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(right: 0, bottom: 0, child: badge!),
        ],
      );
    }

    return avatar;
  }
}
