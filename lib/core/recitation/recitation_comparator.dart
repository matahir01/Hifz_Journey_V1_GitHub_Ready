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
  final int nextExpectedIndex;

  const RecitationComparison({
    required this.score,
    required this.correctWords,
    required this.missingWords,
    required this.substitutedWords,
    required this.words,
    this.nextExpectedIndex = 0,
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

  static const Map<String, String> _speechAliases = {
    // Common Uthmani spellings versus the spelling normally returned by
    // Android/iOS Arabic speech recognizers.
    'الصلوه': 'الصلاه',
    'صلوه': 'صلاه',
    'الزكوه': 'الزكاه',
    'زكوه': 'زكاه',
    'الحيوه': 'الحياه',
    'حيوه': 'حياه',
    'المشكوه': 'المشكاه',
    'مشكوه': 'مشكاه',
    'النجوه': 'النجاه',
    'نجوه': 'نجاه',
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

  /// A comparison-only representation for speech-recognition output.
  ///
  /// We deliberately keep [normalize] suitable for display, then apply the
  /// extra speech aliases here so a phone returning الصلاه is accepted for
  /// الصلاة without changing the Qur'an text shown to the user.
  static String speechCanonical(String input) {
    var value = normalize(input).replaceAll('ة', 'ه');
    value = _speechAliases[value] ?? value;
    return value;
  }

  static bool wordsEquivalent(String expected, String heard) {
    final a = speechCanonical(expected);
    final b = speechCanonical(heard);
    return a.isNotEmpty && a == b;
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
          if (!wordsEquivalent(spoken[j], result[i + j])) {
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

class _CommittedRecitationLedger {
  final Set<int> correctIndices = <int>{};
  final Set<int> missedIndices = <int>{};
  int nextExpectedIndex = 0;
  bool finalized = false;
  DateTime lastSeen = DateTime.now();

  void reset() {
    correctIndices.clear();
    missedIndices.clear();
    nextExpectedIndex = 0;
    finalized = false;
    lastSeen = DateTime.now();
  }
}

class RecitationComparator {
  const RecitationComparator();

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
    final passageKey = expected.join(' ');

    if (live || _ledgers.containsKey(passageKey)) {
      return _compareSequential(
        expected: expected,
        heard: heard,
        key: passageKey,
        live: live,
      );
    }

    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= n; j++) {
      dp[0][j] = j;
    }

    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = QuranTextNormalizer.wordsEquivalent(
          expected[i - 1],
          heard[j - 1],
        )
            ? 0
            : 1;
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
      if (i > 0 &&
          j > 0 &&
          QuranTextNormalizer.wordsEquivalent(
            expected[i - 1],
            heard[j - 1],
          )) {
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
    var correct = 0;
    var missing = 0;
    var substituted = 0;
    for (final word in ordered) {
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

    return RecitationComparison(
      score: score,
      correctWords: correct,
      missingWords: missing,
      substitutedWords: substituted,
      words: ordered,
      nextExpectedIndex: correct + missing + substituted,
    );
  }

  /// Live matching is monotonic but no longer blocks on one unrecognized word.
  ///
  /// If the recognizer misses the current word and then clearly recognizes one
  /// of the next few Qur'an words, the skipped word is marked missed and the
  /// cursor advances. This is important for real recitation: one STT spelling
  /// error must not freeze the entire remainder of a page.
  RecitationComparison _compareSequential({
    required List<String> expected,
    required List<String> heard,
    required String key,
    required bool live,
  }) {
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

    // Re-evaluate the cumulative transcript. Both sets are cleared so a later
    // corrected speech hypothesis can repair an earlier false miss.
    ledger.correctIndices.clear();
    ledger.missedIndices.clear();

    var cursor = 0;
    const lookAhead = 4;

    for (final token in heard) {
      if (cursor >= expected.length) break;

      if (QuranTextNormalizer.wordsEquivalent(expected[cursor], token)) {
        ledger.correctIndices.add(cursor);
        cursor++;
        continue;
      }

      // A speech engine can simply fail to recognize one word. Look a short
      // distance ahead for the word the user has already moved on to.
      final lastCandidate = cursor + lookAhead < expected.length
          ? cursor + lookAhead
          : expected.length - 1;
      var matchedIndex = -1;
      for (var index = cursor + 1; index <= lastCandidate; index++) {
        if (QuranTextNormalizer.wordsEquivalent(expected[index], token)) {
          matchedIndex = index;
          break;
        }
      }

      if (matchedIndex >= 0) {
        for (var skipped = cursor; skipped < matchedIndex; skipped++) {
          ledger.missedIndices.add(skipped);
        }
        ledger.correctIndices.add(matchedIndex);
        cursor = matchedIndex + 1;
      }
      // Otherwise treat this token as recognizer noise. Do not force a wrong
      // substitution and do not block subsequent words from realigning us.
    }

    ledger.nextExpectedIndex = cursor;

    final words = <WordAssessment>[];
    var correct = 0;
    var missing = 0;
    for (var index = 0; index < expected.length; index++) {
      final wasRecognized = ledger.correctIndices.contains(index);
      final wasMissed = ledger.missedIndices.contains(index);
      final state = wasRecognized
          ? WordAssessmentState.correct
          : wasMissed
              ? WordAssessmentState.missing
              : live
                  ? WordAssessmentState.pending
                  : WordAssessmentState.missing;

      if (state == WordAssessmentState.correct) correct++;
      if (state == WordAssessmentState.missing) missing++;

      words.add(
        WordAssessment(
          expected: expected[index],
          heard: wasRecognized ? expected[index] : null,
          state: state,
        ),
      );
    }

    if (!live) ledger.finalized = true;
    final denominator = expected.isEmpty ? 1 : expected.length;
    final score =
        ((denominator - missing) / denominator).clamp(0.0, 1.0);

    return RecitationComparison(
      score: score,
      correctWords: correct,
      missingWords: missing,
      substitutedWords: 0,
      words: words,
      nextExpectedIndex: cursor,
    );
  }

  int _min3(int a, int b, int c) {
    var result = a < b ? a : b;
    if (c < result) result = c;
    return result;
  }
}
