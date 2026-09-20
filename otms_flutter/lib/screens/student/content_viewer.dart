import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/models.dart';
import '../../services/api.dart';
import '../shared/widgets.dart';

/// Renders one content item. Videos open externally (or the attached file);
/// notes and booklets render their Markdown body in a clean reader.
class ContentViewer extends StatelessWidget {
  final Content content;
  const ContentViewer({super.key, required this.content});

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) showError(context, 'Could not open the link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(content.title)),
      body: switch (content.type) {
        'video' => _videoBody(context),
        _ => _readerBody(context),
      },
    );
  }

  Widget _videoBody(BuildContext context) {
    final link = content.url ??
        (content.filePath != null
            ? Api.instance.fileUrl(content.filePath!)
            : null);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.play_circle_fill, size: 80),
            const SizedBox(height: 16),
            Text(content.title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            if (link != null)
              Text(link,
                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                  textAlign: TextAlign.center),
            const SizedBox(height: 24),
            if (link != null)
              FilledButton.icon(
                onPressed: () => _open(context, link),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open video'),
              )
            else
              const Text('No video link available.'),
          ],
        ),
      ),
    );
  }

  Widget _readerBody(BuildContext context) {
    final body = content.body ?? '';
    return Markdown(
      data: body.isEmpty ? '_No content._' : body,
      padding: const EdgeInsets.all(20),
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        h1: Theme.of(context).textTheme.headlineSmall,
        p: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
      ),
    );
  }
}
