// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
library;

import 'dart:html' as html;

class WebFullscreen {
  WebFullscreen._();

  static bool get isFullscreen => html.document.fullscreenElement != null;

  static Future<void> toggleFullscreen() async {
    try {
      if (isFullscreen) {
        html.document.exitFullscreen();
      } else {
        html.document.documentElement?.requestFullscreen();
      }
    } catch (_) {}
  }
}
