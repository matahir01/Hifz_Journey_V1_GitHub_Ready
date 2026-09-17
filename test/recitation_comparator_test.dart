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

  test('Alif Lam Mim matches spoken letter names', () {
    const comparator = RecitationComparator();
    final result = comparator.compare(
      expectedText: 'الٓمٓ',
      transcript: 'ألف لام ميم',
    );
    expect(result.correctWords, 1);
    expect(result.words.single.expected, 'الم');
    expect(result.missingWords, 0);
    expect(result.substitutedWords, 0);
    expect(result.score, 1.0);
  });

  test('Kaf Ha Ya Ain Sad matches spoken letter names', () {
    const comparator = RecitationComparator();
    final result = comparator.compare(
      expectedText: 'كهيعص',
      transcript: 'كاف ها يا عين صاد',
    );
    expect(result.correctWords, 1);
    expect(result.words.single.expected, 'كهيعص');
    expect(result.score, 1.0);
  });

  test('speech spelling accepts taa marbuta as haa', () {
    const comparator = RecitationComparator();
    final result = comparator.compare(
      expectedText: 'ويقيمون الصلاة ومما رزقناهم ينفقون',
      transcript: 'ويقيمون الصلاه ومما رزقناهم ينفقون',
      live: true,
    );

    expect(result.correctWords, 5);
    expect(result.missingWords, 0);
    expect(result.nextExpectedIndex, 5);
  });

  test('speech spelling accepts common Uthmani salaah orthography', () {
    expect(
      QuranTextNormalizer.wordsEquivalent('ٱلصَّلَوٰةَ', 'الصلاه'),
      isTrue,
    );
  });

  test('live comparison skips a missed word and keeps moving', () {
    const comparator = RecitationComparator();
    final result = comparator.compare(
      expectedText: 'الحمد لله رب العالمين',
      transcript: 'الحمد رب العالمين',
      live: true,
    );

    expect(result.words[0].state, WordAssessmentState.correct);
    expect(result.words[1].state, WordAssessmentState.missing);
    expect(result.words[2].state, WordAssessmentState.correct);
    expect(result.words[3].state, WordAssessmentState.correct);
    expect(result.nextExpectedIndex, 4);
  });

  test('recognizer noise does not block later realignment', () {
    const comparator = RecitationComparator();
    final result = comparator.compare(
      expectedText: 'بسم الله الرحمن الرحيم',
      transcript: 'بسم كلام غير واضح الرحمن الرحيم',
      live: true,
    );

    expect(result.words[0].state, WordAssessmentState.correct);
    expect(result.words[1].state, WordAssessmentState.missing);
    expect(result.words[2].state, WordAssessmentState.correct);
    expect(result.words[3].state, WordAssessmentState.correct);
    expect(result.nextExpectedIndex, 4);
  });
}
