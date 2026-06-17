import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Saves [content] to the device Documents directory and returns the full path.
Future<String> saveExportFile(String filename, String content) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$filename');
  await file.writeAsString(content);
  return file.path;
}
