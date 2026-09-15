import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

/// A picked file reduced to what the API needs: bytes + a display name.
class PickedFile {
  final Uint8List bytes;
  final String name;
  PickedFile(this.bytes, this.name);
}

/// Opens the OS file picker (any type). Returns null if cancelled.
Future<PickedFile?> pickAnyFile() async {
  final result = await FilePicker.platform.pickFiles(withData: true);
  if (result == null || result.files.isEmpty) return null;
  final f = result.files.first;
  if (f.bytes == null) return null;
  return PickedFile(f.bytes!, f.name);
}

/// Opens the image picker (gallery). Returns null if cancelled.
Future<PickedFile?> pickImage() async {
  final picker = ImagePicker();
  final img = await picker.pickImage(source: ImageSource.gallery);
  if (img == null) return null;
  final bytes = await img.readAsBytes();
  return PickedFile(bytes, img.name);
}
