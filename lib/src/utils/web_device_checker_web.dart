/// Web implementation using `dart:html` to enumerate media devices.
///
/// This file is only compiled when `dart.library.html` is available (i.e. on
/// Flutter Web).  It calls `navigator.mediaDevices.enumerateDevices()` without
/// requesting a permission prompt — the browser returns device *kinds* even
/// when labels are empty (which happens before permission is granted).
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
library;

import 'dart:async';
import 'dart:html' as html;

class WebDeviceAvailability {
  final bool hasCamera;
  final bool hasMicrophone;

  const WebDeviceAvailability({
    required this.hasCamera,
    required this.hasMicrophone,
  });
}

class WebDeviceChecker {
  WebDeviceChecker._();

  static Future<WebDeviceAvailability> checkDevices() async {
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        // Very old browser – let Agora try anyway.
        return const WebDeviceAvailability(
          hasCamera: true,
          hasMicrophone: true,
        );
      }

      final devices = await mediaDevices.enumerateDevices();
      bool hasCamera = false;
      bool hasMicrophone = false;

      for (final device in devices) {
        if (device.kind == 'videoinput') hasCamera = true;
        if (device.kind == 'audioinput') hasMicrophone = true;
        if (hasCamera && hasMicrophone) break;
      }

      return WebDeviceAvailability(
        hasCamera: hasCamera,
        hasMicrophone: hasMicrophone,
      );
    } catch (_) {
      // If enumeration throws (permissions API blocked, etc.) assume devices
      // exist and let Agora surface the real error itself.
      return const WebDeviceAvailability(hasCamera: true, hasMicrophone: true);
    }
  }
}
