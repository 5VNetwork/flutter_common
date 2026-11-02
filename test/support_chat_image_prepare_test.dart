import 'dart:typed_data';

import 'package:flutter_common/support/support_chat_image_prepare.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('shrinks oversized images and encodes jpeg', () async {
    final source = img.Image(width: 3200, height: 1800);
    img.fill(source, color: img.ColorRgb8(20, 40, 60));
    final bytes = Uint8List.fromList(img.encodePng(source));

    final prepared = await prepareSupportChatImageForUpload(
      bytes: bytes,
      fileName: 'shot.png',
    );

    expect(prepared.contentType, 'image/jpeg');
    expect(prepared.fileName, 'shot.jpg');
    expect(prepared.dimensions.width, supportChatUploadMaxImageDimension);
    expect(prepared.dimensions.height, 900);

    final decoded = img.decodeJpg(prepared.bytes);
    expect(decoded, isNotNull);
    expect(decoded!.width, supportChatUploadMaxImageDimension);
    expect(decoded.height, 900);
  });

  test('leaves already-small images within max dimension', () async {
    final source = img.Image(width: 800, height: 600);
    img.fill(source, color: img.ColorRgb8(200, 100, 50));
    final bytes = Uint8List.fromList(img.encodePng(source));

    final prepared = await prepareSupportChatImageForUpload(
      bytes: bytes,
      fileName: 'small.png',
    );

    expect(prepared.dimensions.width, 800);
    expect(prepared.dimensions.height, 600);
    expect(prepared.fileName, 'small.jpg');
  });
}
