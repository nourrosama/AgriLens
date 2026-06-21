import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Saves [content] to the Downloads directory on Android, or the Documents
/// directory on iOS (which is accessible via the Files app).
/// Returns the full absolute path of the saved file.
Future<String> saveExportFile(String filename, String content) async {
  Directory dir;

  if (Platform.isAndroid) {
    // On Android, getDownloadsDirectory() returns the public Downloads folder
    // visible in the Files app and accessible to users without a file manager.
    final downloads = await getDownloadsDirectory();
    dir = downloads ?? await getApplicationDocumentsDirectory();
  } else {
    // On iOS, Documents is the user-accessible folder (via Files app → On My iPhone → AgriLens).
    dir = await getApplicationDocumentsDirectory();
  }

  // Ensure the directory exists
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }

  final file = File('\${dir.path}/\$filename');
  await file.writeAsString(content, flush: true);
  return file.path;
}
