import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Saves [content] to the Downloads directory on Android, or the Documents
/// directory on iOS (which is accessible via the Files app).
/// Returns the full absolute path of the saved file.
Future<String> saveExportFile(String filename, String content) async {
  Directory? dir;
  if (Platform.isAndroid) {
    // Try the well-known public Downloads folder first — visible in Files app.
    dir = Directory('/storage/emulated/0/Download');
    if (!dir.existsSync()) {
      // Fall back to getDownloadsDirectory(), then external storage.
      dir = await getDownloadsDirectory();
      dir ??= await getExternalStorageDirectory();
    }
  } else {
    // On iOS, Documents is the user-accessible folder
    // (Files app → On My iPhone → AgriLens).
    dir = await getApplicationDocumentsDirectory();
  }
  // Final fallback for any other platform.
  dir ??= await getApplicationDocumentsDirectory();

  // Ensure the directory exists.
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final file = File('${dir.path}/$filename');
  await file.writeAsString(content, flush: true);
  return file.path;
}