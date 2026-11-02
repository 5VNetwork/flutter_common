import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_common/support/support_chat.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// Longest edge for support-chat uploads. Bubbles display at ~320 CSS px.
const supportChatUploadMaxImageDimension = 1600;

/// JPEG quality for shrunk support-chat uploads.
const supportChatUploadJpegQuality = 85;

class SupportChatPreparedImage {
  const SupportChatPreparedImage({
    required this.bytes,
    required this.dimensions,
    required this.fileName,
    required this.contentType,
  });

  final Uint8List bytes;
  final SupportImageDimensions dimensions;
  final String fileName;
  final String contentType;
}

/// Decodes [bytes], shrinks the longest edge to [maxDimension] when larger,
/// applies EXIF orientation, and re-encodes as JPEG for upload.
Future<SupportChatPreparedImage> prepareSupportChatImageForUpload({
  required Uint8List bytes,
  required String fileName,
  int maxDimension = supportChatUploadMaxImageDimension,
  int jpegQuality = supportChatUploadJpegQuality,
}) {
  return compute(_prepareSupportChatImageForUpload, (
    bytes: bytes,
    fileName: fileName,
    maxDimension: maxDimension,
    jpegQuality: jpegQuality,
  ));
}

SupportChatPreparedImage _prepareSupportChatImageForUpload(
  ({
    Uint8List bytes,
    String fileName,
    int maxDimension,
    int jpegQuality,
  })
  args,
) {
  final decoded = img.decodeImage(args.bytes);
  if (decoded == null) {
    throw StateError('Unsupported or corrupt image');
  }

  final oriented = img.bakeOrientation(decoded);
  final maxSide = math.max(oriented.width, oriented.height);

  img.Image resized = oriented;
  if (maxSide > args.maxDimension) {
    final scale = args.maxDimension / maxSide;
    resized = img.copyResize(
      oriented,
      width: math.max(1, (oriented.width * scale).round()),
      height: math.max(1, (oriented.height * scale).round()),
      interpolation: img.Interpolation.average,
    );
  }

  final encoded = Uint8List.fromList(
    img.encodeJpg(resized, quality: args.jpegQuality),
  );

  return SupportChatPreparedImage(
    bytes: encoded,
    dimensions: SupportImageDimensions(
      width: resized.width,
      height: resized.height,
    ),
    fileName: _jpegFileName(args.fileName),
    contentType: 'image/jpeg',
  );
}

String _jpegFileName(String fileName) {
  final base = p.basenameWithoutExtension(fileName);
  if (base.isEmpty) return 'image.jpg';
  return '$base.jpg';
}
