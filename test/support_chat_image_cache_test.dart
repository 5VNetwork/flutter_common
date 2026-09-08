import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_common/support/support_chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late Map<String, File> files;
  var signedUrlCalls = 0;
  var downloadCalls = 0;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('support_image_cache_test_');
    files = {};
    signedUrlCalls = 0;
    downloadCalls = 0;
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  Future<File?> getFromCache(String key) async {
    final file = files[key];
    if (file == null || !file.existsSync()) return null;
    return file;
  }

  Future<File> downloadToCache(String url, {required String key}) async {
    downloadCalls += 1;
    final file = File(p.join(tempDir.path, key.replaceAll('/', '_')));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(Uint8List.fromList([1, 2, 3]));
    files[key] = file;
    return file;
  }

  Future<String> createSignedUrl(String path) async {
    signedUrlCalls += 1;
    return 'https://example.test/$path?token=1';
  }

  test('downloads and caches on first resolve', () async {
    const path = 'user/conv/img_100x100.jpg';

    final file = await resolveSupportChatLocalImage(
      path: path,
      getFromCache: getFromCache,
      downloadToCache: downloadToCache,
      createSignedUrl: createSignedUrl,
    );

    expect(file.existsSync(), isTrue);
    expect(signedUrlCalls, 1);
    expect(downloadCalls, 1);
  });

  test('cache hit skips signed URL and download', () async {
    const path = 'user/conv/img_100x100.jpg';
    final cached = File(p.join(tempDir.path, 'seed.jpg'))
      ..writeAsBytesSync(Uint8List.fromList([9, 9, 9]));
    files[path] = cached;

    final file = await resolveSupportChatLocalImage(
      path: path,
      getFromCache: getFromCache,
      downloadToCache: downloadToCache,
      createSignedUrl: createSignedUrl,
    );

    expect(file.path, cached.path);
    expect(signedUrlCalls, 0);
    expect(downloadCalls, 0);
  });

  test('second resolve after download does not hit the network again', () async {
    const path = 'user/conv/img_100x100.jpg';

    await resolveSupportChatLocalImage(
      path: path,
      getFromCache: getFromCache,
      downloadToCache: downloadToCache,
      createSignedUrl: createSignedUrl,
    );
    await resolveSupportChatLocalImage(
      path: path,
      getFromCache: getFromCache,
      downloadToCache: downloadToCache,
      createSignedUrl: createSignedUrl,
    );

    expect(signedUrlCalls, 1);
    expect(downloadCalls, 1);
  });
}
