import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_journey/domain/hifz/recitation_assessor.dart';

void main() {
  const assessor = QuranTextRecitationAssessor();

  test('normalizes Quranic diacritics and alif forms', () {
    expect(
      QuranTextRecitationAssessor.normalizeArabic('ٱلْحَمْدُ لِلَّهِ'),
      'الحمد لله',
    );
  });

  test('perfect text gives full score', () async {
    final result = await assessor.assessText(
      ayahId: 1,
      expectedText: 'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
      transcript: 'الحمد لله رب العالمين',
    );
    expect(result.recallScore, 1.0);
    expect(result.alignment.every((t) => t.status == RecitationTokenStatus.correct), isTrue);
  });

  test('missing word lowers score and is aligned', () async {
    final result = await assessor.assessText(
      ayahId: 1,
      expectedText: 'الحمد لله رب العالمين',
      transcript: 'الحمد لله العالمين',
    );
    expect(result.recallScore, lessThan(1.0));
    expect(result.alignment.any((t) => t.status == RecitationTokenStatus.missed), isTrue);
  });
}
