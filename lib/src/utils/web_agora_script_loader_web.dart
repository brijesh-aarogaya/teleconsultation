// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;

import 'teleconsultation_logger.dart';

class WebAgoraScriptLoader {
  WebAgoraScriptLoader._();

  static const String agoraRtcJsUrl =
      'https://download.agora.io/sdk/release/AgoraRTC_N-4.22.0.js';
  static const String irisWebRtcJsUrl =
      'https://download.agora.io/sdk/release/iris-web-rtc_n450_w4220_0.8.6.js';

  /// Ensures that AgoraRTC and Iris Web RTC scripts are loaded in the browser DOM.
  /// If already loaded (e.g. from web/index.html), this is a fast no-op.
  /// If missing, it dynamically loads them in sequence.
  static Future<void> ensureScriptsLoaded() async {
    try {
      final bool hasAgora = _isScriptPresent('AgoraRTC') ||
          js.context.hasProperty('AgoraRTC');
      final bool hasIris = _isScriptPresent('iris-web-rtc') ||
          js.context.hasProperty('IrisWebRtc');

      if (hasAgora && hasIris) {
        teleconsultationLog('Web: AgoraRTC and iris-web-rtc already loaded in DOM.');
        return;
      }

      if (!hasAgora) {
        teleconsultationLog('Web: AgoraRTC script missing from DOM. Loading dynamically...');
        await _loadScript(agoraRtcJsUrl);
      }

      if (!hasIris) {
        teleconsultationLog('Web: iris-web-rtc script missing from DOM. Loading dynamically...');
        await _loadScript(irisWebRtcJsUrl);
      }

      teleconsultationLog('Web: Agora Web SDK scripts successfully loaded.');
    } catch (e) {
      teleconsultationLog('Web: Failed to load Agora Web SDK scripts: $e');
      throw StateError(
        'Agora RTC Web SDK scripts could not be loaded.\n'
        'Please ensure the following tags are present in your web/index.html body before flutter_bootstrap.js:\n\n'
        '<script src="$agoraRtcJsUrl"></script>\n'
        '<script src="$irisWebRtcJsUrl"></script>\n\n'
        'Original error: $e',
      );
    }
  }

  static bool _isScriptPresent(String keyword) {
    final scripts = html.document.querySelectorAll('script');
    for (final s in scripts) {
      if (s is html.ScriptElement && s.src.contains(keyword)) {
        return true;
      }
    }
    return false;
  }

  static Future<void> _loadScript(String url) async {
    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..src = url
      ..type = 'text/javascript'
      ..async = false;

    late StreamSubscription onLoadSub;
    late StreamSubscription onErrorSub;

    onLoadSub = script.onLoad.listen((_) {
      onLoadSub.cancel();
      onErrorSub.cancel();
      completer.complete();
    });

    onErrorSub = script.onError.listen((event) {
      onLoadSub.cancel();
      onErrorSub.cancel();
      completer.completeError('Failed to load script: $url');
    });

    html.document.body?.append(script) ?? html.document.head?.append(script);

    return completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        onLoadSub.cancel();
        onErrorSub.cancel();
        throw TimeoutException('Timed out while loading Agora script: $url');
      },
    );
  }
}
