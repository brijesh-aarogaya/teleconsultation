/// Non-web stub: Agora RTC uses native libraries on mobile/desktop,
/// so no JavaScript script injection is needed.
class WebAgoraScriptLoader {
  WebAgoraScriptLoader._();

  static Future<void> ensureScriptsLoaded() async {
    // No-op on mobile and desktop
  }
}
