import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hifz_journey/data/repositories/tajweed_repository.dart';
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

  test('parses quoted QUL rule classes', () {
    const source =
        "ٱهۡدِنَا <rule class='ham_wasl'>ٱ</rule>لصِّرَٰطَ "
        '<rule class="madda_normal">ٰ</rule>';
    final segments = parseTajweedText(source);

    expect(segments.where((segment) => segment.rule != null).length, 2);
    expect(segments[1].rule, 'ham_wasl');
    expect(segments[3].rule, 'madda_normal');
  });

  test('repairs mojibake Tajweed Arabic', () {
    const broken = 'Ø¨ÙØ³Û¡Ù…Ù';
    expect(repairQulTajweedEncoding(broken), 'بِسۡمِ');
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
