import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Saves [content] to the Downloads folder (Android) or Documents directory
/// (iOS/other) and returns the full path so the user knows where to find it.
Future<String> saveExportFile(String filename, String content) async {
  Directory? dir;

  if (Platform.isAndroid) {
    // Try the public Downloads directory first — visible in Files app.
    dir = Directory('/storage/emulated/0/Download');
    if (!dir.existsSync()) {
      dir = await getExternalStorageDirectory();
    }
  }

  dir ??= await getApplicationDocumentsDirectory();

  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  return file.path;
}
