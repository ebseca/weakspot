import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  const WeakspotApp({super.key, this.repository});

  /// Injected by tests; the app builds its own in production.
  final LibraryRepository? repository;

  @override
  State<WeakspotApp> createState() => _WeakspotAppState();
}

class _WeakspotAppState extends State<WeakspotApp> {
  late final LibraryRepository _repository =
      widget.repository ?? LibraryRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weakspot',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: HomeScreen(repository: _repository),
    );
  }
}
