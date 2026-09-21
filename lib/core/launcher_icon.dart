/// Which icon the launcher shows.
///
/// Android has no "set my icon" API. The manifest declares two
/// `activity-alias` entries pointing at the same activity — one carrying
/// the everyday icon, one the Pro icon — and `MainActivity.kt` enables one
/// and disables the other. This is the Dart side of that channel.
///
/// Everywhere that is not Android this does nothing, quietly: the setting
/// still works, there is simply no home-screen icon to change.
library;

import 'package:flutter/services.dart';

/// Swaps the launcher icon between the everyday mark and the Pro one.
abstract class LauncherIcon {
  /// Show the Pro icon, or the everyday one.
  ///
  /// Safe to call with the icon that is already showing — Android treats
  /// setting a component to the state it is already in as a no-op.
  Future<void> use({required bool pro});
}

/// The real one, over a method channel.
class PlatformLauncherIcon implements LauncherIcon {
  const PlatformLauncherIcon();

  static const MethodChannel _channel =
      MethodChannel('com.ebseca.weakspot/launcher_icon');

  @override
  Future<void> use({required bool pro}) async {
    try {
      await _channel.invokeMethod<void>('setIcon', {'pro': pro});
    } on MissingPluginException {
      // Web, desktop, and widget tests have no such channel. Not being
      // able to change an icon that does not exist is not a failure.
    } on PlatformException {
      // A launcher that refuses the change is the launcher's business.
      // The in-app mark has already changed either way.
    }
  }
}

/// Does nothing. For tests and for platforms with no launcher.
class NoLauncherIcon implements LauncherIcon {
  const NoLauncherIcon();

  @override
  Future<void> use({required bool pro}) async {}
}
