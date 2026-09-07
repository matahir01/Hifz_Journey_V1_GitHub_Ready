import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';

class MushafPage extends StatefulWidget {
  final int initialPage;
  const MushafPage({super.key, this.initialPage = 1});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late int page;
  late Future<_MushafData> data;

  @override
  void initState() {
    super.initState();
    page = widget.initialPage.clamp(1, 604).toInt();
    data = _load();
  }

  Future<_MushafData> _load() async {
    final quran = context.read<QuranRepository>();
    final ayahs = await quran.ayahsForPage(page);
    final ids = ayahs.map((a) => a.surahId).toSet();
    final surahs = <int, Surah>{};
    for (final id in ids) {
      final surah = await quran.surah(id);
      if (surah != null) surahs[id] = surah;
    }
    return _MushafData(ayahs, surahs);
  }

  void _go(int value) {
    setState(() {
      page = value.clamp(1, 604).toInt();
      data = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('Mushaf · Page $page'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: page > 1 ? () => _go(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: page < 604 ? () => _go(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      body: FutureBuilder<_MushafData>(
        future: data,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final value = snapshot.data!;
          if (value.ayahs.isEmpty) {
            return const Center(child: Text('No text found for this page.'));
          }
          return SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: scheme.outlineVariant),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: .06),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: CustomScrollView(
                        slivers: [
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(18, 18, 18, 22),
                            sliver: SliverList.list(
                              children: _buildPageContents(context, value),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: page > 1 ? () => _go(page - 1) : null,
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Previous'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$page', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: page < 604 ? () => _go(page + 1) : null,
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Next'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildPageContents(BuildContext context, _MushafData data) {
    final widgets = <Widget>[];
    int? activeSurah;
    final buffer = <Ayah>[];

    void flush() {
      if (buffer.isEmpty) return;
      widgets.add(_AyahBlock(ayahs: List<Ayah>.from(buffer)));
      buffer.clear();
    }

    for (final ayah in data.ayahs) {
      if (activeSurah != ayah.surahId) {
        flush();
        activeSurah = ayah.surahId;
        final surah = data.surahs[ayah.surahId];
        if (ayah.ayahNumber == 1 && surah != null) {
          widgets.add(_SurahHeader(surah: surah));
          if (surah.id != 1 && surah.id != 9) {
            widgets.add(const _Bismillah());
          }
        }
      }
      buffer.add(ayah);
    }
    flush();
    return widgets;
  }
}

class _MushafData {
  final List<Ayah> ayahs;
  final Map<int, Surah> surahs;
  const _MushafData(this.ayahs, this.surahs);
}

class _SurahHeader extends StatelessWidget {
  final Surah surah;
  const _SurahHeader({required this.surah});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: .42),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              surah.nameEn,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            surah.nameAr,
            textDirection: TextDirection.rtl,
            style: const TextStyle(
              fontFamily: 'Noto Naskh Arabic',
              fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Bismillah extends StatelessWidget {
  const _Bismillah();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(bottom: 14),
      child: Text(
        'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'Noto Naskh Arabic',
          fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
          fontSize: 25,
          height: 1.8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AyahBlock extends StatelessWidget {
  final List<Ayah> ayahs;
  const _AyahBlock({required this.ayahs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SelectableText.rich(
        TextSpan(
          children: [
            for (final ayah in ayahs) ...[
              TextSpan(text: ayah.textUthmani),
              TextSpan(
                text: '  ﴿${_arabicDigits(ayah.ayahNumber)}﴾  ',
                style: TextStyle(
                  fontSize: 20,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.justify,
        style: const TextStyle(
          fontFamily: 'Noto Naskh Arabic',
          fontFamilyFallback: ['Noto Sans Arabic', 'serif'],
          fontSize: 29,
          height: 2.05,
        ),
      ),
    );
  }
}

String _arabicDigits(int value) {
  const western = '0123456789';
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  return value
      .toString()
      .split('')
      .map((c) => eastern[western.indexOf(c)])
      .join();
}
