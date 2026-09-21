import 'package:flutter_test/flutter_test.dart';
import 'package:weakspot/ui/theme.dart';

void main() {
  group('card sizing', () {
    test('a single glyph fills the card', () {
      expect(Type.cardSizeFor('あ'), 104);
      expect(Type.cardSizeFor('ก'), 104);
    });

    test('longer text steps down', () {
      final sizes = [
        Type.cardSizeFor('あ'),
        Type.cardSizeFor('こんにちは'),
        Type.cardSizeFor('un café con leche'),
        Type.cardSizeFor('What does a torque wrench actually do?'),
      ];
      for (var i = 1; i < sizes.length; i++) {
        expect(sizes[i], lessThan(sizes[i - 1]));
      }
    });

    test('never goes below the readable floor', () {
      final essay = 'a' * 500;
      expect(Type.cardSizeFor(essay), Type.minCardSize);
      expect(Type.minCardSize, greaterThanOrEqualTo(16));
    });

    test('counts characters, not bytes', () {
      // Three kana are three characters, however many bytes they take.
      expect(Type.cardSizeFor('あいう'), Type.cardSizeFor('abc'));
    });

    test('the answer is always quieter than the prompt', () {
      for (final text in ['a', 'gor', 'un café con leche']) {
        expect(Type.answerSizeFor(text),
            lessThanOrEqualTo(Type.cardSizeFor(text)));
      }
    });

    test('a long answer also stops at the floor', () {
      expect(Type.answerSizeFor('a' * 200), Type.minCardSize);
    });
  });
}
