import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/ayah.dart';

/// Loads the official QUL QPC Hafs Tajweed text bundled with the app.
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
    return decoded.map(
      (key, value) => MapEntry(
        key,
        ((value as Map<String, dynamic>)['text'] as String).replaceFirst(
          RegExp(r'\s+[٠-٩۰-۹]+$'),
          '',
        ),
      ),
    );
  }
}
