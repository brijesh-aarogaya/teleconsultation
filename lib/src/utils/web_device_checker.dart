/// Checks camera / microphone availability in the browser before Agora's
/// iris-web-rtc tries to create media tracks, preventing `NotFoundError`.
///
/// Uses conditional exports so this file compiles on all platforms.
library;

export 'web_device_checker_stub.dart'
    if (dart.library.html) 'web_device_checker_web.dart';
