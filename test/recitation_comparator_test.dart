import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_journey/core/recitation/recitation_comparator.dart';

void main() {
  test('Quran text normalizer ignores Uthmani marks', () {
    expect(QuranTextNormalizer.normalize('الْحَمْدُ لِلَّهِ'), 'الحمد لله');
  });

  test('recitation comparator detects a substituted word', () {
    const comparator = RecitationComparator();
    final result = comparator.compare(
      expectedText: 'الحمد لله رب العالمين',
      transcript: 'الحمد لله رب المؤمنين',
    );
    expect(result.correctWords, 3);
    expect(result.substitutedWords, 1);
    expect(result.score, closeTo(0.75, 0.001));
  });
}
