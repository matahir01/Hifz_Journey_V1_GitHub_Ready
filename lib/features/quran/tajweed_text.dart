import 'package:flutter/material.dart';

class TajweedSegment {
  final String text;
  final String? rule;

  const TajweedSegment(this.text, [this.rule]);
}

List<TajweedSegment> parseTajweedText(String source) {
  final result = <TajweedSegment>[];
  final pattern = RegExp(
    r'''<rule\s+class\s*=\s*(?:['"])?([a-z_]+)(?:['"])?>(.*?)</rule>''',
    caseSensitive: false,
    dotAll: true,
  );
  var offset = 0;
  for (final match in pattern.allMatches(source)) {
    if (match.start > offset) {
      result.add(TajweedSegment(source.substring(offset, match.start)));
    }
    result.add(TajweedSegment(match.group(2)!, match.group(1)!.toLowerCase()));
    offset = match.end;
  }
  if (offset < source.length) {
    result.add(TajweedSegment(source.substring(offset)));
  }
  return result;
}

Color tajweedRuleColor(String? rule, Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return switch (rule) {
    'ham_wasl' || 'laam_shamsiyah' || 'slnt' =>
      dark ? const Color(0xFF9CA3AF) : const Color(0xFF667085),
    'madda_normal' => dark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
    'madda_permissible' =>
      dark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
    'madda_necessary' ||
    'madda_obligatory_monfasel' ||
    'madda_obligatory_mottasel' =>
      dark ? const Color(0xFFC084FC) : const Color(0xFF7E22CE),
    'qalaqah' => dark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
    'ikhafa' || 'ikhafa_shafawi' =>
      dark ? const Color(0xFFF472B6) : const Color(0xFFBE185D),
    'iqlab' => dark ? const Color(0xFF22D3EE) : const Color(0xFF0E7490),
    'ghunnah' => dark ? const Color(0xFFFB923C) : const Color(0xFFEA580C),
    'idgham_ghunnah' ||
    'idgham_shafawi' ||
    'idgham_mutajanisayn' ||
    'idgham_mutaqaribayn' =>
      dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D),
    'idgham_wo_ghunnah' =>
      dark ? const Color(0xFFA3E635) : const Color(0xFF4D7C0F),
    _ => dark ? const Color(0xFFF4EFE4) : const Color(0xFF171A17),
  };
}
