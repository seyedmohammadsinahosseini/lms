import 'dart:io';
import 'dart:typed_data';

Future<Uint8List?> readPathBytes(String? path) async {
  if (path == null) return null;
  return File(path).readAsBytes();
}
