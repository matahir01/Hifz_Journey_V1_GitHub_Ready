class RecitationToken {
  final String expected;
  final String? spoken;
  final RecitationTokenStatus status;

  const RecitationToken({
    required this.expected,
    required this.spoken,
    required this.status,
  });
}

enum RecitationTokenStatus { correct, substituted, missed }

class RecitationAssessment {
  final double recallScore;
  final List<String> issues;
  final List<RecitationToken> alignment;
  final String normalizedExpected;
  final String normalizedTranscript;
  final int extraWords;

  const RecitationAssessment({
    required this.recallScore,
    required this.issues,
    this.alignment = const [],
    this.normalizedExpected = '',
    this.normalizedTranscript = '',
    this.extraWords = 0,
  });
}

abstract class RecitationAssessor {
  Future<RecitationAssessment> assessText({
    required int ayahId,
    required String expectedText,
    required String transcript,
  });
}

class QuranTextRecitationAssessor implements RecitationAssessor {
  const QuranTextRecitationAssessor();

  static String normalizeArabic(String input) {
    var value = input;
    value = value.replaceAll(RegExp(r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED]'), '');
    value = value.replaceAll(RegExp(r'[ٱأإآ]'), 'ا');
    value = value.replaceAll('ى', 'ي');
    value = value.replaceAll('ؤ', 'و');
    value = value.replaceAll('ئ', 'ي');
    value = value.replaceAll('ة', 'ه');
    value = value.replaceAll(RegExp(r'[﴾﴿۝۞۩0-9٠-٩۰-۹]'), ' ');
    value = value.replaceAll(RegExp(r'[^\u0621-\u063A\u0641-\u064A\s]'), ' ');
    value = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return value;
  }

  @override
  Future<RecitationAssessment> assessText({
    required int ayahId,
    required String expectedText,
    required String transcript,
  }) async {
    final expectedNormalized = normalizeArabic(expectedText);
    final transcriptNormalized = normalizeArabic(transcript);
    final expected = expectedNormalized.isEmpty ? <String>[] : expectedNormalized.split(' ');
    final spoken = transcriptNormalized.isEmpty ? <String>[] : transcriptNormalized.split(' ');

    final n = expected.length;
    final m = spoken.length;
    final dp = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = 0; i <= n; i++) dp[i][0] = i;
    for (var j = 0; j <= m; j++) dp[0][j] = j;

    for (var i = 1; i <= n; i++) {
      for (var j = 1; j <= m; j++) {
        final cost = expected[i - 1] == spoken[j - 1] ? 0 : 1;
        final deletion = dp[i - 1][j] + 1;
        final insertion = dp[i][j - 1] + 1;
        final substitution = dp[i - 1][j - 1] + cost;
        dp[i][j] = [deletion, insertion, substitution].reduce((a, b) => a < b ? a : b);
      }
    }

    final reversed = <RecitationToken>[];
    var extras = 0;
    var i = n;
    var j = m;
    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && expected[i - 1] == spoken[j - 1] && dp[i][j] == dp[i - 1][j - 1]) {
        reversed.add(RecitationToken(
          expected: expected[i - 1],
          spoken: spoken[j - 1],
          status: RecitationTokenStatus.correct,
        ));
        i--;
        j--;
      } else if (i > 0 && j > 0 && dp[i][j] == dp[i - 1][j - 1] + 1) {
        reversed.add(RecitationToken(
          expected: expected[i - 1],
          spoken: spoken[j - 1],
          status: RecitationTokenStatus.substituted,
        ));
        i--;
        j--;
      } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        reversed.add(RecitationToken(
          expected: expected[i - 1],
          spoken: null,
          status: RecitationTokenStatus.missed,
        ));
        i--;
      } else if (j > 0) {
        extras++;
        j--;
      } else {
        break;
      }
    }
    final alignment = reversed.reversed.toList(growable: false);
    final editDistance = dp[n][m];
    final denominator = n == 0 ? 1 : n;
    final score = (1 - (editDistance / denominator)).clamp(0.0, 1.0).toDouble();
    final missed = alignment.where((e) => e.status == RecitationTokenStatus.missed).length;
    final substitutions = alignment.where((e) => e.status == RecitationTokenStatus.substituted).length;
    final issues = <String>[];
    if (missed > 0) issues.add('$missed missed word${missed == 1 ? '' : 's'}');
    if (substitutions > 0) issues.add('$substitutions changed word${substitutions == 1 ? '' : 's'}');
    if (extras > 0) issues.add('$extras extra word${extras == 1 ? '' : 's'}');
    if (issues.isEmpty && transcriptNormalized.isNotEmpty) issues.add('No text-level differences detected.');
    if (transcriptNormalized.isEmpty) issues.add('No Arabic speech was recognized.');

    return RecitationAssessment(
      recallScore: score,
      issues: issues,
      alignment: alignment,
      normalizedExpected: expectedNormalized,
      normalizedTranscript: transcriptNormalized,
      extraWords: extras,
    );
  }
}
