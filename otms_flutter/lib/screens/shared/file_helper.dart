import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

const int maxPickedFileBytes = 8 * 1024 * 1024;

class PickedFile {
  final Uint8List bytes;
  final String name;
  PickedFile(this.bytes, this.name);
}

Future<PickedFile?> pickAnyFile() async {
  final files = await FilePicker.pickFiles();
  if (files.isEmpty) return null;
  final file = files.first;
  final knownLength = file.lengthSync();
  if (knownLength != null && knownLength > maxPickedFileBytes) {
    throw const FormatException('File is larger than the 8 MB limit.');
  }
  final bytes = await file.readAsBytes();
  if (bytes.length > maxPickedFileBytes) {
    throw const FormatException('File is larger than the 8 MB limit.');
  }
  return PickedFile(bytes, file.name);
}

Future<PickedFile?> pickImage() async {
  final image = await ImagePicker().pickImage(source: ImageSource.gallery);
  if (image == null) return null;
  final size = await image.length();
  if (size > maxPickedFileBytes) {
    throw const FormatException('Image is larger than the 8 MB limit.');
  }
  return PickedFile(await image.readAsBytes(), image.name);
}
