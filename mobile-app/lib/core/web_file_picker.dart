// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:async';
import 'dart:typed_data';

Future<(Uint8List, String)?> pickImageFromWeb() async {
  final completer = Completer<(Uint8List, String)?>();
  final input = html.FileUploadInputElement()..accept = 'image/*';
  input.click();
  input.onChange.listen((event) async {
    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    await reader.onLoad.first;
    final bytes = reader.result as List<int>;
    completer.complete((Uint8List.fromList(bytes), file.name));
  });
  return completer.future;
}
