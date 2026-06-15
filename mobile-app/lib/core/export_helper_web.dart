// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

/// Triggers a browser file download and returns the filename.
Future<String> saveExportFile(String filename, String content) async {
  final bytes = utf8.encode(content);
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.document.createElement('a') as html.AnchorElement
    ..href = url
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
  anchor.remove();
  return filename; // no full path on web
}
