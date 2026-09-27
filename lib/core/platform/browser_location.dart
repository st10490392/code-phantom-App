// Browser address-bar helpers. No-ops on Android/iOS/desktop; the web
// implementation is selected by conditional import.
export 'browser_location_stub.dart' if (dart.library.js_interop) 'browser_location_web.dart';
