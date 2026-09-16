import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled Tajweed asset is valid UTF-8 with full Quran coverage', () async {
    final source = await rootBundle.loadString(
      'assets/quran/qpc-hafs-tajweed.json',
    );
    final decoded = jsonDecode(source) as Map<String, dynamic>;

    expect(decoded.length, 6236);
    for (final key in const ['1:1', '2:25', '114:6']) {
      expect(decoded.containsKey(key), isTrue, reason: 'Missing $key');
      final row = decoded[key] as Map<String, dynamic>;
      final text = row['text'] as String;
      expect(RegExp(r'[\u0600-\u06FF]').hasMatch(text), isTrue);
    }

    final pageFive = decoded['2:25'] as Map<String, dynamic>;
    expect(pageFive['text'] as String, contains('<rule'));
  });
}
