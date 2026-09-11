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

  static const Map<String, List<String>> muqattaat = {
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

  static List<String> collapseMuqattaat(
    List<String> expected,
    List<String> heard,
  ) {
    final result = List<String>.from(heard);
    for (final token in expected) {
      final spoken = muqattaat[token];
      if (spoken == null || spoken.isEmpty) continue;
      var i = 0;
      while (i <= result.length - spoken.length) {
        var matches = true;
        for (var j = 0; j < spoken.length; j++) {
          if (result[i + j] != spoken[j]) {
            matches = false;
            break;
          }
        }
        if (matches) {
          result.replaceRange(i, i + spoken.length, [token]);
          i++;
        } else {
          i++;
        }
      }
    }
    return result;
  }
}

/// Keeps already-confirmed Qur'an positions stable during one recitation test.
///
/// Android speech services may replace or shorten their partial transcript at
/// any time. The UI should therefore not use the latest hypothesis as the sole
/// source of truth. Once a reliable run of Qur'an words has been matched, those
/// positions are locked for the remainder of the test and can never turn back
/// into hidden/missed words because of a later provider reset.
class _CommittedRecitationLedger {
  final Set<int> correctIndices = <int>{};
  bool finalized = false;
  DateTime lastSeen = DateTime.now();

  void reset() {
    correctIndices.clear();
    finalized = false;
    lastSeen = DateTime.now();
  }
}

class RecitationComparator {
  const RecitationComparator();

  /// The page currently owns a const comparator, so the live commitment ledger
  /// is kept by normalized expected passage. A completed result marks the
  /// ledger finalized; the next live attempt for the same passage starts clean.
  /// A stale unfinished attempt is also discarded after 30 minutes.
  static final Map<String, _CommittedRecitationLedger> _ledgers = {};

  RecitationComparison compare({
    required String expectedText,
    required String transcript,
    bool live = false,
  }) {
    final expected = QuranTextNormalizer.words(expectedText);
    final rawHeard = QuranTextNormalizer.words(transcript);
    final heard = QuranTextNormalizer.collapseMuqattaat(expected, rawHeard);
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

    while (i > 0 || j > 0) {
      if (i > 0 && j > 0 && expected[i - 1] == heard[j - 1]) {
        aligned.add(
          WordAssessment(
            expected: expected[i - 1],
            heard: heard[j - 1],
            state: WordAssessmentState.correct,
          ),
        );
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
        i--;
      } else {
        j--;
      }
    }

    final ordered = aligned.reversed.toList(growable: false);
    final key = expected.join(' ');
    final now = DateTime.now();
    var ledger = _ledgers.putIfAbsent(
      key,
      () => _CommittedRecitationLedger(),
    );

    final stale = now.difference(ledger.lastSeen) > const Duration(minutes: 30);
    if (stale || (live && ledger.finalized)) {
      ledger = _CommittedRecitationLedger();
      _ledgers[key] = ledger;
    }
    ledger.lastSeen = now;

    if (live) {
      _commitReliableRuns(ledger, ordered);
    } else {
      // A final Android result is stable enough to preserve every exact match,
      // including isolated words, while keeping all matches locked earlier in
      // the session.
      for (var index = 0; index < ordered.length; index++) {
        if (ordered[index].state == WordAssessmentState.correct) {
          ledger.correctIndices.add(index);
        }
      }
    }

    final merged = <WordAssessment>[];
    for (var index = 0; index < ordered.length; index++) {
      final word = ordered[index];
      if (ledger.correctIndices.contains(index)) {
        merged.add(
          WordAssessment(
            expected: word.expected,
            heard: word.heard ?? word.expected,
            state: WordAssessmentState.correct,
          ),
        );
      } else {
        merged.add(word);
      }
    }

    var correct = 0;
    var missing = 0;
    var substituted = 0;
    for (final word in merged) {
      switch (word.state) {
        case WordAssessmentState.correct:
          correct++;
        case WordAssessmentState.missing:
          missing++;
        case WordAssessmentState.substituted:
          substituted++;
        case WordAssessmentState.pending:
          break;
      }
    }

    final denominator = m == 0 ? 1 : m;
    final penalty = missing + substituted;
    final score = ((denominator - penalty) / denominator).clamp(0.0, 1.0);

    if (!live) ledger.finalized = true;

    return RecitationComparison(
      score: score,
      correctWords: correct,
      missingWords: missing,
      substitutedWords: substituted,
      words: merged,
    );
  }

  /// Lock only reliable live evidence. A run of two or more consecutive exact
  /// Qur'an words is strong evidence of position; an isolated word is accepted
  /// only when it touches an already-locked position. This avoids false jumps
  /// on very common words such as من / في / لا / هم.
  void _commitReliableRuns(
    _CommittedRecitationLedger ledger,
    List<WordAssessment> words,
  ) {
    var start = -1;

    void commitRun(int endExclusive) {
      if (start < 0) return;
      final length = endExclusive - start;
      if (length >= 2) {
        for (var index = start; index < endExclusive; index++) {
          ledger.correctIndices.add(index);
        }
      } else {
        final index = start;
        if (ledger.correctIndices.contains(index - 1) ||
            ledger.correctIndices.contains(index + 1)) {
          ledger.correctIndices.add(index);
        }
      }
      start = -1;
    }

    for (var index = 0; index < words.length; index++) {
      if (words[index].state == WordAssessmentState.correct) {
        if (start < 0) start = index;
      } else {
        commitRun(index);
      }
    }
    commitRun(words.length);
  }

  int _min3(int a, int b, int c) {
    var result = a < b ? a : b;
    if (c < result) result = c;
    return result;
  }
}