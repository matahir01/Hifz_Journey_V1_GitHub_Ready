import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/audio/audio_library_service.dart';
import '../../core/audio/audio_reciter.dart';
import '../../data/models/surah.dart';
import '../../data/repositories/quran_repository.dart';
import '../shell/app_controller.dart';

class AudioLibraryPage extends StatefulWidget {
  const AudioLibraryPage({super.key});

  @override
  State<AudioLibraryPage> createState() => _AudioLibraryPageState();
}

class _AudioLibraryPageState extends State<AudioLibraryPage> {
  late Future<List<Surah>> surahs;
  int selectedSurah = 1;
  int completed = 0;
  int total = 0;
  bool downloading = false;
  bool importing = false;

  @override
  void initState() {
    super.initState();
    surahs = context.read<QuranRepository>().surahs();
  }

  Future<void> _downloadSurah() async {
    final controller = context.read<AppController>();
    final quran = context.read<QuranRepository>();
    final library = context.read<AudioLibraryService>();
    final ayahs = await quran.ayahsForSurah(selectedSurah);
    if (!mounted) return;
    setState(() {
      downloading = true;
      completed = 0;
      total = ayahs.length;
    });
    try {
      final result = await library.downloadAyahs(
        ayahs,
        reciter: controller.reciter,
        onProgress: (done, all) {
          if (mounted) setState(() { completed = done; total = all; });
        },
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Downloaded ${result.downloaded}. Already offline ${result.alreadyAvailable}. Failed ${result.failed}.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => downloading = false);
    }
  }

  Future<void> _import() async {
    setState(() => importing = true);
    try {
      final result = await context
          .read<AudioLibraryService>()
          .importAudioPack(reciter: 'Imported local reciter');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Imported ${result.imported} audio files. ${result.skipped} skipped.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final reciter = controller.reciter;
    return Scaffold(
      appBar: AppBar(title: const Text('Reciter & audio')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Al Quran Cloud audio',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Stream verse-by-verse from Islamic Network CDN, or download a Surah for offline use. Downloaded ayahs are automatically preferred.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: reciter.id,
                    decoration: const InputDecoration(
                      labelText: 'Reciter',
                      border: OutlineInputBorder(),
                    ),
                    items: AudioReciters.all
                        .map(
                          (r) => DropdownMenuItem(
                            value: r.id,
                            child: Text('${r.name} • ${r.bitrateKbps} kbps'),
                          ),
                        )
                        .toList(),
                    onChanged: downloading
                        ? null
                        : (value) {
                            if (value != null) controller.setReciter(value);
                          },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Download a Surah',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                  ),
                  const SizedBox(height: 10),
                  FutureBuilder<List<Surah>>(
                    future: surahs,
                    builder: (context, snapshot) {
                      final values = snapshot.data ?? const <Surah>[];
                      if (values.isEmpty) return const LinearProgressIndicator();
                      return DropdownButtonFormField<int>(
                        initialValue: selectedSurah,
                        decoration: const InputDecoration(
                          labelText: 'Surah',
                          border: OutlineInputBorder(),
                        ),
                        items: values
                            .map(
                              (s) => DropdownMenuItem(
                                value: s.id,
                                child: Text('${s.id}. ${s.nameEn}'),
                              ),
                            )
                            .toList(),
                        onChanged: downloading
                            ? null
                            : (value) => setState(() => selectedSurah = value ?? 1),
                      );
                    },
                  ),
                  if (downloading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: total == 0 ? null : completed / total,
                    ),
                    const SizedBox(height: 6),
                    Text('$completed of $total ayahs'),
                  ],
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: downloading ? null : _downloadSurah,
                    icon: const Icon(Icons.download_for_offline_outlined),
                    label: Text(
                      downloading ? 'Downloading…' : 'Download for offline use',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          FutureBuilder<int>(
            future: context.read<AudioLibraryService>().count(reciterId: reciter.id),
            builder: (context, snapshot) => Card(
              child: ListTile(
                leading: const Icon(Icons.offline_pin_outlined),
                title: Text('${snapshot.data ?? 0} ayahs saved for ${reciter.name}'),
                subtitle: const Text('Saved inside Hifz Journey private app storage.'),
              ),
            ),
          ),
          const SizedBox(height: 14),
          ExpansionTile(
            title: const Text('Import your own audio pack'),
            subtitle: const Text('Optional fallback for files you already have permission to use.'),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Supported names: 001001.mp3 or 1_1.mp3.'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: importing ? null : _import,
                icon: const Icon(Icons.library_music_outlined),
                label: Text(importing ? 'Importing…' : 'Import audio pack'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('Remove ${reciter.name} downloads'),
              subtitle: const Text('Streaming, Qur’an text and Hifz progress are not affected.'),
              onTap: downloading
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Remove downloaded audio?'),
                          content: Text('Delete downloaded audio for ${reciter.name}?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Remove'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true && context.mounted) {
                        await context
                            .read<AudioLibraryService>()
                            .clear(reciterId: reciter.id);
                        if (mounted) setState(() {});
                      }
                    },
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Online recitation uses Al Quran Cloud / Islamic Network CDN. No account or API secret is required. Before public distribution, verify the provider’s current usage and redistribution terms for offline downloads.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
