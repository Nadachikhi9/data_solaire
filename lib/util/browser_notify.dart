import 'browser_notify_stub.dart'
    if (dart.library.html) 'browser_notify_web.dart'
    as notify_impl;

/// Notification navigateur (Web). No-op hors plate-forme JS.
Future<void> requestAndShowBrowserNotification(String title, String body) =>
    notify_impl.requestAndShowBrowserNotification(title, body);
