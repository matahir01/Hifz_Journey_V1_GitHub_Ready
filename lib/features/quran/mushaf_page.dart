import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/repositories/quran_repository.dart';

class MushafPage extends StatefulWidget {
  final int initialPage;
  const MushafPage({super.key, this.initialPage = 1});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late int page;
  late Future<List<Ayah>> ayahs;

  @override
  void initState() {
    super.initState();
    page = widget.initialPage.clamp(1, 604).toInt();
    ayahs = _load();
  }

  Future<List<Ayah>> _load() => context.read<QuranRepository>().ayahsForPage(page);

  void _go(int value) {
    setState(() {
      page = value.clamp(1, 604).toInt();
      ayahs = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Mushaf • Page $page'), actions: [IconButton(onPressed: page > 1 ? () => _go(page - 1) : null, icon: const Icon(Icons.chevron_left)), IconButton(onPressed: page < 604 ? () => _go(page + 1) : null, icon: const Icon(Icons.chevron_right))]),
      body: FutureBuilder<List<Ayah>>(
        future: ayahs,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final values = snapshot.data!;
          return SafeArea(
            top: false,
            child: Column(children: [
              Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(22, 20, 22, 14), child: Card(child: Padding(padding: const EdgeInsets.all(22), child: SelectableText(values.map((a) => '${a.textUthmani}  ﴿${a.ayahNumber}﴾').join(' '), textDirection: TextDirection.rtl, textAlign: TextAlign.justify, style: const TextStyle(fontSize: 28, height: 2.15)))))),
              Padding(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: OutlinedButton.icon(onPressed: page > 1 ? () => _go(page - 1) : null, icon: const Icon(Icons.arrow_back), label: const Text('Previous'))), const SizedBox(width: 10), Expanded(child: FilledButton.icon(onPressed: page < 604 ? () => _go(page + 1) : null, icon: const Icon(Icons.arrow_forward), label: const Text('Next')))])),
            ]),
          );
        },
      ),
    );
  }
}
