import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/ayah.dart';
import '../../data/repositories/quran_repository.dart';
import 'reader_page.dart';

class QuranSearchPage extends StatefulWidget {
  const QuranSearchPage({super.key});

  @override
  State<QuranSearchPage> createState() => _QuranSearchPageState();
}

class _QuranSearchPageState extends State<QuranSearchPage> {
  final controller = TextEditingController();
  Future<List<Ayah>>? results;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = controller.text.trim();
    if (query.isEmpty) return;
    setState(() => results = context.read<QuranRepository>().search(query));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Qur’an')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Arabic text or reference, e.g. 2:255',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _search,
                  icon: const Icon(Icons.arrow_forward),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: results == null
                  ? const Center(
                      child: Text('Search by Arabic text or surah:ayah reference.'),
                    )
                  : FutureBuilder<List<Ayah>>(
                      future: results,
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final values = snapshot.data!;
                        if (values.isEmpty) {
                          return const Center(child: Text('No matching ayahs found.'));
                        }
                        return ListView.separated(
                          itemCount: values.length,
                          separatorBuilder: (_, _) => const Divider(),
                          itemBuilder: (context, index) {
                            final ayah = values[index];
                            return ListTile(
                              title: Text('${ayah.surahId}:${ayah.ayahNumber}'),
                              subtitle: Text(
                                ayah.textUthmani,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textDirection: TextDirection.rtl,
                              ),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReaderPage(startAyahId: ayah.id),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
