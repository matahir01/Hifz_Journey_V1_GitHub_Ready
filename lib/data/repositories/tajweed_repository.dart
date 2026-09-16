import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ayah.dart';

/// Repairs QUL Tajweed text that was accidentally stored after a UTF-8 →
/// Windows-1252 decoding pass. Valid Arabic text is returned unchanged.
String repairQulTajweedEncoding(String input) {
  if (RegExp(r'[\u0600-\u06FF]').hasMatch(input)) return input;

  const cp1252ToByte = <int, int>{
    0x20AC: 0x80,
    0x201A: 0x82,
    0x0192: 0x83,
    0x201E: 0x84,
    0x2026: 0x85,
    0x2020: 0x86,
    0x2021: 0x87,
    0x02C6: 0x88,
    0x2030: 0x89,
    0x0160: 0x8A,
    0x2039: 0x8B,
    0x0152: 0x8C,
    0x017D: 0x8E,
    0x2018: 0x91,
    0x2019: 0x92,
    0x201C: 0x93,
    0x201D: 0x94,
    0x2022: 0x95,
    0x2013: 0x96,
    0x2014: 0x97,
    0x02DC: 0x98,
    0x2122: 0x99,
    0x0161: 0x9A,
    0x203A: 0x9B,
    0x0153: 0x9C,
    0x017E: 0x9E,
    0x0178: 0x9F,
  };

  final bytes = <int>[];
  for (final rune in input.runes) {
    if (rune <= 0xFF) {
      bytes.add(rune);
      continue;
    }
    final mapped = cp1252ToByte[rune];
    if (mapped == null) return input;
    bytes.add(mapped);
  }

  try {
    final repaired = utf8.decode(bytes);
    return RegExp(r'[\u0600-\u06FF]').hasMatch(repaired) ? repaired : input;
  } on FormatException {
    return input;
  }
}

/// Loads the bundled QUL QPC Hafs Tajweed text for offline use.
class TajweedRepository {
  static Future<Map<String, String>>? _cache;

  Future<Map<int, String>> forAyahs(Iterable<Ayah> ayahs) async {
    final verses = await (_cache ??= _load());
    return {
      for (final ayah in ayahs)
        if (verses['${ayah.surahId}:${ayah.ayahNumber}'] case final text?)
          ayah.id: text,
    };
  }

  static Future<Map<String, String>> _load() async {
    final source = await rootBundle.loadString(
      'assets/quran/qpc-hafs-tajweed.json',
    );
    final decoded = jsonDecode(source) as Map<String, dynamic>;
    return decoded.map((key, value) {
      final raw = (value as Map<String, dynamic>)['text'] as String;
      final repaired = repairQulTajweedEncoding(raw);
      return MapEntry(
        key,
        repaired.replaceFirst(RegExp(r'\s+[٠-٩۰-۹]+$'), ''),
      );
    });
  }
}
