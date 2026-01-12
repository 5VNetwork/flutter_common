import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:logger/web.dart';
import 'package:flutter_common/common.dart' as flutter_common;

/// Download something and record traffic usage
class Downloader implements flutter_common.Downloader {
  Downloader({this.logger});
  final Logger? logger;

  /// download from multiple urls, return the first successful one
  Future<void> downloadMulti(List<String> urls, String dest) async {
    for (var url in urls) {
      try {
        return await download(url, dest);
      } catch (e) {
        logger?.d("download failed: $e");
      }
    }
    throw Exception("all download failed");
  }

  /// try direct download first, if failed, try to use outbound handlers
  Future<void> download(String url, String dest) async {
    try {
      await directDownloadToFile(url, dest);
      return;
    } catch (e) {
      logger?.d("plain download failed: $e", stackTrace: StackTrace.current);
    }
  }

  Future<Uint8List> downloadMemory(String url) async {
    try {
      return await directDownloadMemory(url);
    } catch (e) {
      logger?.e("plain download failed: $e");
      rethrow;
    }
  }
}

/// download content from url, save them to [dest] file
Future<void> directDownloadToFile(
  String url,
  String dest, [
  http.Client? client,
]) async {
  final httpClient = client ?? http.Client();
  // Create temporary file path
  final tempPath = '$dest.tmp.${DateTime.now().millisecondsSinceEpoch}';
  final tempFile = File(tempPath);
  tempFile.createSync(recursive: true);
  try {
    final request = await httpClient.send(http.Request('GET', Uri.parse(url)));
    if (request.statusCode != 200) {
      throw Exception("download failed: ${request.statusCode}");
    }
    // Open the file in write mode
    final fileStream = tempFile.openWrite();
    // Pipe the response stream to the file
    await request.stream.pipe(fileStream);
    // Close the file
    await fileStream.flush();
    await fileStream.close();

    await tempFile.rename(dest);
  } catch (e) {
    // Clean up temp file if anything goes wrong
    if (tempFile.existsSync()) {
      tempFile.deleteSync();
    }
    rethrow;
  } finally {
    httpClient.close();
  }
}

/// download from url, return the content
Future<Uint8List> directDownloadMemory(
  String url, [
  http.Client? client,
]) async {
  final httpClient = client ?? http.Client();
  final res = await httpClient.get(Uri.parse(url));
  return res.bodyBytes;
}
