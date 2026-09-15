import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_journey/features/quran/tajweed_text.dart';

void main() {
  test('parses QUL rule markup without changing Quran text', () {
    const source =
        'بِسۡمِ <rule class=ham_wasl>ٱ</rule>للَّهِ '
        '<rule class=qalaqah>قۡ</rule>';
    final segments = parseTajweedText(source);

    expect(segments.map((segment) => segment.text).join(), 'بِسۡمِ ٱللَّهِ قۡ');
    expect(segments.where((segment) => segment.rule != null).length, 2);
    expect(segments[1].rule, 'ham_wasl');
    expect(segments[3].rule, 'qalaqah');
  });

  test('uses distinct accessible colors for core rule families', () {
    expect(
      tajweedRuleColor('qalaqah', Brightness.light),
      isNot(tajweedRuleColor('ghunnah', Brightness.light)),
    );
    expect(
      tajweedRuleColor('ikhafa', Brightness.dark),
      isNot(tajweedRuleColor('iqlab', Brightness.dark)),
    );
  });
}
