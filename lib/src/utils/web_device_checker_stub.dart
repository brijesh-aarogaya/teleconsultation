/// Native / non-web stub.  All device flags default to `true` so native code
/// continues through the normal `permission_handler` flow.
library;

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
    return const WebDeviceAvailability(hasCamera: true, hasMicrophone: true);
  }
}
