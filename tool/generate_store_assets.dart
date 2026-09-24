/// Draws the Play Store graphics from the same painter as the app icon.
///
/// ```bash
/// flutter test tool/generate_store_assets.dart
/// ```
///
/// Writes `store/assets/icon-512.png` and `store/assets/feature-graphic.png`.
///
/// Widget tests render every font as the Ahem test face (solid boxes), so the
/// feature graphic's lettering loads Segoe UI from the Windows font directory
/// by hand. This tool is therefore Windows-only, which is where it is run.
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/ui/logo.dart';

const String _out = 'store/assets';

/// Colours from `lib/ui/theme.dart`, repeated so the listing art is an
/// explicit, reviewable palette like the launcher icon's.
const Color _ground = Color(0xFF15171C);
const Color _ink = Color(0xFFE7EAF1);
const Color _dim = Color(0xFF8D95A6);
const Color _accent = Color(0xFFC9633C);

const String _family = 'StoreSegoe';

void main() {
  setUpAll(() async {
    final loader = FontLoader(_family);
    for (final file in ['segoeui.ttf', 'segoeuib.ttf']) {
      final bytes = File('C:/Windows/Fonts/$file').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  });

  test('writes the Play icon and feature graphic', () async {
    await _write('$_out/icon-512.png', await _icon());
    await _write('$_out/feature-graphic.png', await _feature());

    for (final name in ['icon-512.png', 'feature-graphic.png']) {
      expect(File('$_out/$name').lengthSync(), greaterThan(1000), reason: name);
    }
  });
}

/// 512x512, full bleed. Play applies its own corner mask, so the ground is
/// a plain square rather than the rounded one the legacy launcher icon uses.
Future<Uint8List> _icon() => _render(512, 512, (canvas) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 512, 512),
        Paint()..color = _ground,
      );
      const mark = 512 * 0.56;
      const inset = (512 - mark) / 2;
      canvas.save();
      canvas.translate(inset, inset);
      paintMark(canvas, mark, MarkColors.standard);
      canvas.restore();
    });

/// 1024x500. Play crops and overlays this, so nothing important goes near
/// the edges and the mark sits left of centre.
Future<Uint8List> _feature() => _render(1024, 500, (canvas) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 1024, 500),
        Paint()..color = _ground,
      );

      const mark = 220.0;
      canvas.save();
      canvas.translate(120, (500 - mark) / 2);
      paintMark(canvas, mark, MarkColors.standard);
      canvas.restore();

      _label(canvas, 'Weakspot', 420, 150,
          size: 64, weight: FontWeight.w700, color: _ink);
      _label(canvas, 'Flashcards that hunt your weak spots', 424, 250,
          size: 26, color: _dim);
      _label(canvas, 'Offline. No account. Bring your own AI.', 424, 292,
          size: 26, color: _dim);

      // A short rule in the struggling orange, echoing the lit card.
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(426, 238, 56, 5),
          const Radius.circular(2.5),
        ),
        Paint()..color = _accent,
      );
    });


void _label(
  Canvas canvas,
  String value,
  double x,
  double y, {
  required double size,
  required Color color,
  FontWeight weight = FontWeight.w400,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: value,
      style: TextStyle(
        fontFamily: _family,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: weight == FontWeight.w700 ? -1.2 : 0,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, Offset(x, y));
}

Future<Uint8List> _render(
  int width,
  int height,
  void Function(Canvas) paint,
) async {
  final recorder = ui.PictureRecorder();
  paint(Canvas(recorder));
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}

Future<void> _write(String path, Uint8List bytes) async {
  final file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes);
}
