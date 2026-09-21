import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'core/settings.dart';
import 'core/store.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Palette.ground,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const WeakspotApp());
}

class WeakspotApp extends StatefulWidget {
  const WeakspotApp({super.key, this.repository, this.settings});

  /// Injected by tests; the app builds its own in production.
  final LibraryRepository? repository;

  /// Injected by tests. A controller handed in is already loaded, so the
  /// app goes straight to the library list.
  final SettingsController? settings;

  @override
  State<WeakspotApp> createState() => _WeakspotAppState();
}

class _WeakspotAppState extends State<WeakspotApp> {
  late final LibraryRepository _repository =
      widget.repository ?? LibraryRepository();
  late final SettingsController _settings =
      widget.settings ?? SettingsController();

  @override
  void initState() {
    super.initState();
    if (!_settings.isLoaded) _settings.load();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weakspot',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // The first frame waits on settings so a Pro install never flashes
      // the everyday mark on the way in. It is one read of
      // shared_preferences, and the library list loads behind its own
      // spinner anyway.
      home: ListenableBuilder(
        listenable: _settings,
        builder: (context, _) => _settings.isLoaded
            ? HomeScreen(repository: _repository, settings: _settings)
            : const Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
      ),
    );
  }
}
