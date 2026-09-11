class WordAssessment {
  final String expected;
  final String? heard;
  final WordAssessmentState state;

  const WordAssessment({
    required this.expected,
    required this.heard,
    required this.state,
  });
}

enum WordAssessmentState { correct, substituted, missing, pending }

class RecitationComparison {
  final double score;
  final int correctWords;
  final int missingWords;
  final int substitutedWords;
  final List<WordAssessment> words;

  const RecitationComparison({
    required this.score,
    required this.correctWords,
    required this.missingWords,
    required this.substitutedWords,
    required this.words,
  });
}

class QuranTextNormalizer {
  static final RegExp _marks = RegExp(
    r'[\u0610-\u061A\u064B-\u065F\u0670\u06D6-\u06ED\u0640]',
  );
  static final RegExp _nonArabic = RegExp(r'[^\u0621-\u064A\s]');
  static final RegExp _spaces = RegExp(r'\s+');

  static const Map<String, List<String>> _muqattaat = {
    'الم': ['الف', 'لام', 'ميم'],
    'المص': ['الف', 'لام', 'ميم', 'صاد'],
    'الر': ['الف', 'لام', 'را'],
    'المر': ['الف', 'لام', 'ميم', 'را'],
    'كهيعص': ['كاف', 'ها', 'يا', 'عين', 'صاد'],
    'طه': ['طا', 'ها'],
    'طسم': ['طا', 'سين', 'ميم'],
    'طس': ['طا', 'سين'],
    'يس': ['يا', 'سين'],
    'ص': ['صاد'],
    'حم': ['حا', 'ميم'],
    'عسق': ['عين', 'سين', 'قاف'],
    'ق': ['قاف'],
    'ن': ['نون'],
  };

  static String normalize(String input) {
    return input
        .replaceAll(_marks, '')
        .replaceAll('ٱ', 'ا')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ئ', 'ي')
        .replaceAll(_nonArabic, ' ')
        .replaceAll(_spaces, ' ')
        .trim();
  }

  static List<String> words(String input) {
    final value = normalize(input);
    return value.isEmpty ? const [] : value.split(' ');
  }

  static List<String> comparisonWords(String input) {
    final source = words(input);
    if (source.isEmpty) return const [];
    final expanded = <String>[];
    for (final word in source) {
      final replacement = _muqattaat[word];
      if (replacement == null) {
        expanded.add(word);
      } else {
        expanded.addAll(replacement);
      }
    }
    return expanded;
  }
}

class RecitationComparator {
  const RecitationComparator();

  RecitationComparison compare({
    required String expectedText,
    required String transcript,
    bool live = false,
  }) {
    final expected = QuranTextNormalizer.comparisonWords(expectedText);
    final heard = QuranTextNormalizer.comparisonWords(transcript);
    final m = expected.length;
    final n = heard.length;

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = expected[i - 1] == heard[j - 1] ? 0 : 1;
        final deletion = dp[i - 1][j] + 1;
        final insertion = dp[i][j - 1] + 1;
        final substitution = dp[i - 1][j - 1] + cost;
        dp[i][j] = _min3(deletion, insertion, substitution);
      }
    }

    var i = m;
    var j = n;
    final aligned = <WordAssessment>[];
    var correct = 0;
    var missing = 0;
    var substituted = 0;

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && expected[i - 1] == heard[j - 1]) {
        aligned.add(
          WordAssessment(
            expected: expected[i - 1],
            heard: heard[j - 1],
            state: WordAssessmentState.correct,
          ),
        );
        correct++;
        i--;
        j--;
      } else if (i > 0 &&
          j > 0 &&
          dp[i][j] == dp[i - 1][j - 1] + 1) {
        aligned.add(
          WordAssessment(
            expected: expected[i - 1],
            heard: heard[j - 1],
            state: WordAssessmentState.substituted,
          ),
        );
        substituted++;
        i--;
        j--;
      } else if (i > 0 && dp[i][j] == dp[i - 1][j] + 1) {
        aligned.add(
          WordAssessment(
            expected: expected[i - 1],
            heard: null,
            state: live
                ? WordAssessmentState.pending
                : WordAssessmentState.missing,
          ),
        );
        if (!live) missing++;
        i--;
      } else {
        j--;
      }
    }

    final ordered = aligned.reversed.toList(growable: false);
    final denominator = m == 0 ? 1 : m;
    final penalty = missing + substituted;
    final score = ((denominator - penalty) / denominator).clamp(0.0, 1.0);

    return RecitationComparison(
      score: score,
      correctWords: correct,
      missingWords: missing,
      substitutedWords: substituted,
      words: ordered,
    );
  }

  int _min3(int a, int b, int c) {
    var result = a < b ? a : b;
    if (c < result) result = c;
    return result;
  }
}
