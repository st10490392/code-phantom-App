import 'package:web/web.dart' as web;

/// Replaces the current history entry's URL without navigating, so values
/// such as auth-callback tokens in the `#fragment` do not stay in the
/// address bar or in browser history.
void replaceBrowserUrl(String path) {
  web.window.history.replaceState(null, '', path);
}
