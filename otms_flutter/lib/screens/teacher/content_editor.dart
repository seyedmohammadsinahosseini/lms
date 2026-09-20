import 'package:flutter/material.dart';

import '../../services/api.dart';
import '../shared/file_helper.dart';
import '../shared/widgets.dart';

/// Authors one piece of lesson content. Video takes a URL (or file); notes
/// and booklets take Markdown body text. Notes are meant for short posts,
/// booklets for long-form material — same editor, different intent.
class ContentEditor extends StatefulWidget {
  final int lessonId;
  const ContentEditor({super.key, required this.lessonId});
  @override
  State<ContentEditor> createState() => _ContentEditorState();
}

class _ContentEditorState extends State<ContentEditor> {
  String _type = 'note';
  final _title = TextEditingController();
  final _url = TextEditingController();
  final _body = TextEditingController();
  PickedFile? _file;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _url.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _isVideo => _type == 'video';

  Future<void> _pickFile() async {
    final f = await pickAnyFile();
    if (f != null) setState(() => _file = f);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      showError(context, 'Add a title.');
      return;
    }
    if (_isVideo && _url.text.trim().isEmpty && _file == null) {
      showError(context, 'Add a video URL or attach a file.');
      return;
    }
    if (!_isVideo && _body.text.trim().isEmpty) {
      showError(context, 'Write some content.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Api.instance.createContent(
        lessonId: widget.lessonId,
        type: _type,
        title: _title.text.trim(),
        body: _isVideo ? null : _body.text.trim(),
        url: _isVideo && _url.text.trim().isNotEmpty ? _url.text.trim() : null,
        fileBytes: _file?.bytes,
        fileName: _file?.name,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add content')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'note',
                  label: Text('Note'),
                  icon: Icon(Icons.description_outlined)),
              ButtonSegment(
                  value: 'booklet',
                  label: Text('Booklet'),
                  icon: Icon(Icons.book_outlined)),
              ButtonSegment(
                  value: 'video',
                  label: Text('Video'),
                  icon: Icon(Icons.play_circle_outline)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_isVideo) ...[
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Video URL (YouTube, Vimeo, direct link)',
                prefixIcon: Icon(Icons.link),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            const Text('— or —', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _busy ? null : _pickFile,
              icon: const Icon(Icons.upload_file),
              label: Text(_file == null ? 'Attach video file' : _file!.name),
            ),
          ] else
            TextField(
              controller: _body,
              maxLines: _type == 'booklet' ? 16 : 6,
              decoration: InputDecoration(
                labelText: _type == 'booklet'
                    ? 'Booklet body (Markdown supported)'
                    : 'Note body (Markdown supported)',
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Save content'),
            ),
          ),
        ],
      ),
    );
  }
}
