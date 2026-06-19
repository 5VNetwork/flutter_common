import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart'
    show
        Builders,
        ChatTheme,
        ChatTypography,
        DateFormat,
        ImageMessage,
        Message,
        MessageGroupStatus,
        MessageStatus,
        TextMessage,
        UserID,
        getIconForStatus;
import 'package:flutter_chat_ui/flutter_chat_ui.dart'
    show
        ChatAnimatedListReversed,
        ComposerHeightNotifier,
        OnAttachmentTapCallback,
        OnMessageSendCallback;
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const supportChatStorageBucket = 'support-chat';
const supportChatSignedUrlExpirySeconds = 3600;

/// Prefix for image storage paths stored in chat message content.
const supportImageContentPrefix = 'umi-img:';

const _publicObjectMarker = '/storage/v1/object/public/support-chat/';
const _supportChatMaxImageBubbleWidth = 320.0;
const _supportChatMaxViewerSize = 720.0;
const _pastedImageFileName = 'pasted-image.png';

const supportChatLocalImageBytesMetadataKey = 'supportChatLocalImageBytes';
const supportChatImageUploadingMetadataKey = 'supportChatImageUploading';
const supportChatImageUploadErrorMetadataKey = 'supportChatImageUploadError';
const supportChatImagePixelWidthMetadataKey = 'supportChatImagePixelWidth';
const supportChatImagePixelHeightMetadataKey = 'supportChatImagePixelHeight';

final _supportImageDimensionsInFileNamePattern = RegExp(
  r'_(\d+)x(\d+)(?=\.[^.]+$)',
);

final _supportChatUrlPattern = RegExp(
  r'((https?:\/\/|www\.)[^\s]+)',
  caseSensitive: false,
);

bool isSupportImageContent(String content) =>
    content.startsWith(supportImageContentPrefix);

/// Raw value after [supportImageContentPrefix] (path or legacy public URL).
String supportImageReferenceFromContent(String content) =>
    content.substring(supportImageContentPrefix.length);

/// Bucket-relative path used for upload, signed URLs, and RLS folder checks.
String supportImagePathFromContent(String content) {
  final reference = supportImageReferenceFromContent(content);
  if (reference.startsWith('http://') || reference.startsWith('https://')) {
    final marker = reference.indexOf(_publicObjectMarker);
    if (marker >= 0) {
      return Uri.decodeComponent(
        reference.substring(marker + _publicObjectMarker.length),
      );
    }
  }
  return reference;
}

String supportImageContentFromPath(String path) =>
    '$supportImageContentPrefix$path';

/// Pixel dimensions encoded in the storage object file name (`…_800x600.jpg`).
class SupportImageDimensions {
  const SupportImageDimensions({required this.width, required this.height});

  final int width;
  final int height;
}

/// Reads `_WxH` from the last path segment before the extension.
SupportImageDimensions? supportImageDimensionsFromReference(String reference) {
  final path = reference.startsWith(supportImageContentPrefix)
      ? supportImagePathFromContent(reference)
      : reference;
  final fileName = path.split('/').last;
  final match = _supportImageDimensionsInFileNamePattern.firstMatch(fileName);
  if (match == null) return null;

  final width = int.tryParse(match.group(1)!);
  final height = int.tryParse(match.group(2)!);
  if (width == null || height == null || width <= 0 || height <= 0) {
    return null;
  }

  return SupportImageDimensions(width: width, height: height);
}

/// Bubble size for [BoxFit.contain] inside [maxWidth], using intrinsic pixels.
Size supportChatImageBubbleDisplaySize({
  required int pixelWidth,
  required int pixelHeight,
  required double maxWidth,
}) {
  if (pixelWidth <= 0 || pixelHeight <= 0) {
    return Size(maxWidth, maxWidth * 0.75);
  }

  final height = maxWidth * pixelHeight / pixelWidth;
  return Size(maxWidth, height);
}

SupportImageDimensions? supportImageDimensionsFromMessage(
  ImageMessage message,
) {
  final metaWidth = message.metadata?[supportChatImagePixelWidthMetadataKey];
  final metaHeight = message.metadata?[supportChatImagePixelHeightMetadataKey];
  if (metaWidth is int &&
      metaHeight is int &&
      metaWidth > 0 &&
      metaHeight > 0) {
    return SupportImageDimensions(width: metaWidth, height: metaHeight);
  }

  return supportImageDimensionsFromReference(message.source);
}

Future<SupportImageDimensions> decodeSupportImageDimensions(
  Uint8List bytes,
) async {
  final codec = await ui.instantiateImageCodec(bytes);
  try {
    final frame = await codec.getNextFrame();
    try {
      return SupportImageDimensions(
        width: frame.image.width,
        height: frame.image.height,
      );
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class SupportChatStorage {
  SupportChatStorage({SupabaseClient? client, this.fileNamePrefix = ''})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  final String fileNamePrefix;

  Future<String> uploadImage({
    required String userId,
    required String conversationId,
    required String fileName,
    required Uint8List bytes,
    String? contentType,
    int? pixelWidth,
    int? pixelHeight,
  }) async {
    final extension = _extensionFromFileName(fileName);
    final dimensions =
        pixelWidth != null &&
            pixelHeight != null &&
            pixelWidth > 0 &&
            pixelHeight > 0
        ? SupportImageDimensions(width: pixelWidth, height: pixelHeight)
        : await decodeSupportImageDimensions(bytes);
    final path =
        '$userId/$conversationId/$fileNamePrefix${DateTime.now().millisecondsSinceEpoch}_${dimensions.width}x${dimensions.height}$extension';

    await _client.storage
        .from(supportChatStorageBucket)
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: contentType ?? _guessContentType(extension),
            upsert: false,
          ),
        );

    return path;
  }

  Future<String> createSignedUrl(
    String path, {
    int expiresInSeconds = supportChatSignedUrlExpirySeconds,
  }) {
    return _client.storage
        .from(supportChatStorageBucket)
        .createSignedUrl(path, expiresInSeconds);
  }

  String _extensionFromFileName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    if (dot <= 0 || dot == fileName.length - 1) {
      return '.jpg';
    }
    return fileName.substring(dot).toLowerCase();
  }

  String _guessContentType(String extension) {
    return switch (extension) {
      '.png' => 'image/png',
      '.webp' => 'image/webp',
      '.gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}

/// Loads a private support-chat object via a short-lived signed URL.
class SupportChatImage extends StatefulWidget {
  const SupportChatImage({
    super.key,
    required this.imageReference,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.storage,
  });

  /// Path or legacy public URL from message content (after `umi-img:`).
  final String imageReference;
  final BoxFit fit;
  final double? width;
  final double? height;
  final SupportChatStorage? storage;

  @override
  State<SupportChatImage> createState() => _SupportChatImageState();
}

class _SupportChatImageState extends State<SupportChatImage> {
  late Future<String> _signedUrlFuture;
  late String _cacheKey;

  @override
  void initState() {
    super.initState();
    _cacheKey = _imageCacheKey();
    _signedUrlFuture = _loadSignedUrl();
  }

  @override
  void didUpdateWidget(covariant SupportChatImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageReference != widget.imageReference ||
        oldWidget.storage != widget.storage) {
      _cacheKey = _imageCacheKey();
      _signedUrlFuture = _loadSignedUrl();
    }
  }

  String _imageCacheKey() {
    return supportImagePathFromContent(
      '$supportImageContentPrefix${widget.imageReference}',
    );
  }

  Future<String> _loadSignedUrl() {
    final path = _imageCacheKey();
    return (widget.storage ?? SupportChatStorage()).createSignedUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _signedUrlFuture,
      builder: (context, snapshot) {
        final width = widget.width;
        final height = widget.height;
        if (width == null || height == null) {
          return const SizedBox.shrink();
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return SizedBox(
            width: width,
            height: height,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          );
        }

        return CachedNetworkImage(
          imageUrl: snapshot.data!,
          cacheKey: _cacheKey,
          fit: widget.fit,
          width: width,
          height: height,
          progressIndicatorBuilder: (context, url, progress) {
            return SizedBox(
              width: width,
              height: height,
              child: Center(
                child: CircularProgressIndicator(value: progress.progress),
              ),
            );
          },
          errorWidget: (context, url, error) => SizedBox(
            width: width,
            height: height,
            child: const Center(child: Icon(Icons.broken_image_outlined)),
          ),
        );
      },
    );
  }
}

/// Chat theme merged from app [ThemeData] and flutter_chat defaults.
ChatTheme supportChatTheme(BuildContext context, {required bool isLight}) {
  final material = Theme.of(context);
  final base = isLight ? ChatTheme.light() : ChatTheme.dark();
  return base.copyWith(
    typography: ChatTypography.fromThemeData(material).merge(base.typography),
  );
}

/// Message text with tappable http(s) links. Uses [Text] inside [SelectionArea]
/// (not [SelectableText]) so bubbles shrink-wrap inside flutter_chat_ui's
/// [Flexible] row layout while remaining copyable.
class SupportChatLinkText extends StatelessWidget {
  const SupportChatLinkText({
    super.key,
    required this.text,
    required this.style,
    required this.linkStyle,
  });

  final String text;
  final TextStyle style;
  final TextStyle linkStyle;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    var start = 0;

    for (final match in _supportChatUrlPattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      final link = match.group(0)!;
      spans.add(
        TextSpan(
          text: link,
          style: linkStyle,
          recognizer: TapGestureRecognizer()..onTap = () => _openUrl(link),
        ),
      );
      start = match.end;
    }

    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    final Widget messageText = spans.isEmpty
        ? Text(text, style: style)
        : Text.rich(TextSpan(children: spans));

    return SelectionArea(child: messageText);
  }
}

typedef SupportChatImagePasteCallback =
    Future<void> Function(Uint8List bytes, String fileName);

class _SupportChatComposer extends StatefulWidget {
  const _SupportChatComposer({required this.onImagePaste});

  final SupportChatImagePasteCallback onImagePaste;

  @override
  State<_SupportChatComposer> createState() => _SupportChatComposerState();
}

class _SupportChatComposerState extends State<_SupportChatComposer> {
  final _key = GlobalKey();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _hasTextNotifier = ValueNotifier(false);

  bool _pasting = false;

  @override
  void initState() {
    super.initState();
    _focusNode.onKeyEvent = _handleKeyEvent;
    _controller.addListener(_handleTextChange);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void dispose() {
    _hasTextNotifier.dispose();
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final keyboard = HardwareKeyboard.instance;
    if (event.logicalKey == LogicalKeyboardKey.keyV &&
        (keyboard.isControlPressed || keyboard.isMetaPressed)) {
      unawaited(_handlePaste());
      return KeyEventResult.handled;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter &&
        keyboard.isShiftPressed) {
      _handleSubmitted(_controller.text);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  Future<void> _handlePaste() async {
    if (_pasting) return;
    _pasting = true;

    try {
      final image = await Pasteboard.image;
      if (image != null && image.isNotEmpty) {
        await widget.onImagePaste(image, _pastedImageFileName);
        return;
      }

      final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (text == null || text.isEmpty) return;
      _insertText(text);
    } finally {
      _pasting = false;
    }
  }

  void _insertText(String text) {
    final selection = _controller.selection;
    final value = _controller.value;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final nextText = value.text.replaceRange(start, end, text);
    final cursorOffset = start + text.length;

    _controller.value = value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: cursorOffset),
      composing: TextRange.empty,
    );
  }

  void _handleTextChange() {
    _hasTextNotifier.value = _controller.text.trim().isNotEmpty;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _handleSubmitted(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    context.read<OnMessageSendCallback?>()?.call(trimmed);
    _controller.clear();
  }

  void _measure() {
    if (!mounted) return;

    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    context.read<ComposerHeightNotifier>().setHeight(
      renderBox.size.height - bottomSafeArea,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final onAttachmentTap = context.read<OnAttachmentTapCallback?>();
    final theme = context.select(
      (ChatTheme t) => (
        bodyMedium: t.typography.bodyMedium,
        onSurface: t.colors.onSurface,
        surfaceContainerHigh: t.colors.surfaceContainerHigh,
        surfaceContainerLow: t.colors.surfaceContainerLow,
      ),
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        key: _key,
        color: theme.surfaceContainerLow.withValues(alpha: 0.8),
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomSafeArea),
          child: Row(
            children: [
              if (onAttachmentTap != null)
                IconButton(
                  icon: const Icon(Icons.attachment),
                  color: theme.onSurface.withValues(alpha: 0.5),
                  onPressed: onAttachmentTap,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: 'Type a message',
                    hintStyle: theme.bodyMedium.copyWith(
                      color: theme.onSurface.withValues(alpha: 0.5),
                    ),
                    border: const OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    filled: true,
                    fillColor: theme.surfaceContainerHigh.withValues(
                      alpha: 0.8,
                    ),
                    hoverColor: Colors.transparent,
                  ),
                  style: theme.bodyMedium.copyWith(color: theme.onSurface),
                  onSubmitted: _handleSubmitted,
                  textInputAction: TextInputAction.newline,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<bool>(
                valueListenable: _hasTextNotifier,
                builder: (context, hasText, child) {
                  return IconButton(
                    icon: const Icon(Icons.send),
                    color: theme.onSurface.withValues(alpha: 0.5),
                    onPressed: hasText
                        ? () => _handleSubmitted(_controller.text)
                        : null,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _openUrl(String raw) async {
  final uri = Uri.tryParse(raw.startsWith('www.') ? 'https://$raw' : raw);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Parses Supabase/Postgres `timestamptz` JSON as UTC when no offset is present.
DateTime parseSupportChatTimestamp(String raw) {
  final parsed = DateTime.parse(raw);
  if (parsed.isUtc) return parsed;
  return DateTime.utc(
    parsed.year,
    parsed.month,
    parsed.day,
    parsed.hour,
    parsed.minute,
    parsed.second,
    parsed.millisecond,
    parsed.microsecond,
  );
}

/// Formats [time] in the device local timezone for chat message bubbles.
String formatSupportChatLocalTime(DateTime time) {
  final local = time.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final messageDay = DateTime(local.year, local.month, local.day);
  if (messageDay == today) {
    return DateFormat('HH:mm').format(local);
  }
  if (now.year == local.year) {
    return DateFormat('MMM d, HH:mm').format(local);
  }
  return DateFormat('yyyy-MM-dd HH:mm').format(local);
}

TextStyle supportChatTimeStyle(ChatTheme theme, {required bool isSentByMe}) {
  return theme.typography.labelSmall.copyWith(
    fontSize: 10,
    height: 1.1,
    color: isSentByMe
        ? theme.colors.onPrimary.withValues(alpha: 0.85)
        : theme.colors.onSurface.withValues(alpha: 0.6),
  );
}

Widget buildSupportTextMessage(
  BuildContext context,
  TextMessage message,
  int index, {
  required bool isSentByMe,
  MessageGroupStatus? groupStatus,
}) {
  final theme = context.watch<ChatTheme>();
  final backgroundColor = isSentByMe
      ? theme.colors.primary
      : theme.colors.surfaceContainer;
  final textStyle = isSentByMe
      ? theme.typography.bodyMedium.copyWith(color: theme.colors.onPrimary)
      : theme.typography.bodyMedium.copyWith(color: theme.colors.onSurface);
  final linkStyle = textStyle.copyWith(
    decoration: TextDecoration.underline,
    decorationColor: textStyle.color,
  );
  final timeStyle = supportChatTimeStyle(theme, isSentByMe: isSentByMe);
  final maxWidth = MediaQuery.sizeOf(context).width * 0.75;
  final isFailed = isSentByMe && message.status == MessageStatus.error;
  final errorColor = Theme.of(context).colorScheme.error;
  final bubbleColor = isFailed
      ? Color.alphaBlend(errorColor.withValues(alpha: 0.35), backgroundColor)
      : backgroundColor;

  // Same shape as flutter_chat_ui SimpleTextMessage — no Align; ChatMessage aligns.
  return ClipRRect(
    borderRadius: theme.shape,
    child: Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: isFailed
            ? Border.all(color: errorColor.withValues(alpha: 0.8))
            : null,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SupportChatLinkText(
            text: message.text,
            style: textStyle.copyWith(
              color: isFailed
                  ? textStyle.color?.withValues(alpha: 0.9)
                  : textStyle.color,
            ),
            linkStyle: linkStyle,
          ),
          if (isFailed) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 14, color: errorColor),
                const SizedBox(width: 4),
                Text(
                  'Failed to send · Tap to retry',
                  style: theme.typography.labelSmall.copyWith(
                    color: errorColor,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
          if (message.createdAt != null || isFailed) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.createdAt != null)
                  Text(
                    formatSupportChatLocalTime(message.createdAt!),
                    style: timeStyle,
                  ),
                if (isFailed) ...[
                  if (message.createdAt != null) const SizedBox(width: 6),
                  Icon(
                    getIconForStatus(MessageStatus.error),
                    size: 12,
                    color: errorColor,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    ),
  );
}

Widget buildSupportImageMessage(
  BuildContext context,
  ImageMessage message,
  int index, {
  required bool isSentByMe,
  MessageGroupStatus? groupStatus,
}) {
  final theme = context.watch<ChatTheme>();
  final timeStyle = supportChatTimeStyle(theme, isSentByMe: isSentByMe);
  final backgroundColor = isSentByMe
      ? theme.colors.primary
      : theme.colors.surfaceContainer;
  final maxWidth = math.min(
    MediaQuery.sizeOf(context).width * 0.65,
    _supportChatMaxImageBubbleWidth,
  );
  final localBytes =
      message.metadata?[supportChatLocalImageBytesMetadataKey] as Uint8List?;
  final isUploading =
      message.metadata?[supportChatImageUploadingMetadataKey] == true;
  final hasUploadError =
      message.metadata?[supportChatImageUploadErrorMetadataKey] == true;
  final dimensions = supportImageDimensionsFromMessage(message);
  final displaySize = dimensions == null
      ? Size(maxWidth, maxWidth * 0.75)
      : supportChatImageBubbleDisplaySize(
          pixelWidth: dimensions.width,
          pixelHeight: dimensions.height,
          maxWidth: maxWidth,
        );

  return Align(
    alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: theme.shape,
        child: Material(
          color: backgroundColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: localBytes == null
                    ? () => _showImageViewer(context, message.source)
                    : null,
                child: localBytes == null
                    ? SupportChatImage(
                        imageReference: message.source,
                        fit: BoxFit.contain,
                        width: displaySize.width,
                        height: displaySize.height,
                      )
                    : _LocalSupportChatImage(
                        bytes: localBytes,
                        width: displaySize.width,
                        height: displaySize.height,
                        isUploading: isUploading,
                        hasUploadError: hasUploadError,
                      ),
              ),
              if (message.createdAt != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      formatSupportChatLocalTime(message.createdAt!),
                      style: timeStyle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

void _showImageViewer(BuildContext context, String imageReference) {
  final screenSize = MediaQuery.sizeOf(context);
  final maxViewerWidth = math.min(
    screenSize.width * 0.9,
    _supportChatMaxViewerSize,
  );
  final maxViewerHeight = math.min(
    screenSize.height * 0.85,
    _supportChatMaxViewerSize,
  );
  final dimensions = supportImageDimensionsFromReference(imageReference);
  final viewerSize = dimensions == null
      ? Size(maxViewerWidth, maxViewerHeight)
      : supportChatImageBubbleDisplaySize(
          pixelWidth: dimensions.width,
          pixelHeight: dimensions.height,
          maxWidth: maxViewerWidth,
        );
  final viewerSizeClamped = _clampSupportChatSizeHeight(
    viewerSize,
    maxViewerHeight,
  );

  showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: InteractiveViewer(
        child: SizedBox(
          width: viewerSizeClamped.width,
          height: viewerSizeClamped.height,
          child: SupportChatImage(
            imageReference: imageReference,
            fit: BoxFit.contain,
            width: viewerSizeClamped.width,
            height: viewerSizeClamped.height,
          ),
        ),
      ),
    ),
  );
}

Size _clampSupportChatSizeHeight(Size size, double maxHeight) {
  if (size.height <= maxHeight) return size;
  final scale = maxHeight / size.height;
  return Size(size.width * scale, maxHeight);
}

class _LocalSupportChatImage extends StatelessWidget {
  const _LocalSupportChatImage({
    required this.bytes,
    required this.width,
    required this.height,
    required this.isUploading,
    required this.hasUploadError,
  });

  final Uint8List bytes;
  final double width;
  final double height;
  final bool isUploading;
  final bool hasUploadError;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.memory(
            bytes,
            width: width,
            height: height,
            fit: BoxFit.contain,
          ),
          if (isUploading || hasUploadError)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.28),
                child: Center(
                  child: hasUploadError
                      ? const Icon(Icons.error_outline, color: Colors.white)
                      : const CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Builders supportChatBuilders({SupportChatImagePasteCallback? onImagePaste}) {
  return Builders(
    composerBuilder: onImagePaste == null
        ? null
        : (context) => _SupportChatComposer(onImagePaste: onImagePaste),
    textMessageBuilder: buildSupportTextMessage,
    imageMessageBuilder: buildSupportImageMessage,
    chatAnimatedListBuilder: (context, itemBuilder) =>
        ChatAnimatedListReversed(itemBuilder: itemBuilder),
  );
}
