// lib/screens/image_frame_editor_screen.dart

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

enum ImageFrameEditorMode {
  product,
  avatar,
  companyLogo,
}

class ImageFrameEditorResult {
  const ImageFrameEditorResult({
    required this.bytes,
    required this.file,
  });

  final Uint8List bytes;
  final XFile file;
}

class ImageFrameEditorScreen extends StatefulWidget {
  const ImageFrameEditorScreen({
    super.key,
    required this.sourceBytes,
    required this.mode,
    required this.outputFileName,
  });

  final Uint8List sourceBytes;
  final ImageFrameEditorMode mode;
  final String outputFileName;

  static Future<ImageFrameEditorResult?> open(
      BuildContext context, {
        required XFile source,
        required ImageFrameEditorMode mode,
        required String outputFileName,
      }) async {
    final bytes = await source.readAsBytes();
    if (!context.mounted) return null;

    return Navigator.of(context).push<ImageFrameEditorResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ImageFrameEditorScreen(
          sourceBytes: bytes,
          mode: mode,
          outputFileName: outputFileName,
        ),
      ),
    );
  }

  @override
  State<ImageFrameEditorScreen> createState() =>
      _ImageFrameEditorScreenState();
}

class _ImageFrameEditorScreenState extends State<ImageFrameEditorScreen> {
  static const Color _accent = Color(0xFFD1BC00);

  final GlobalKey _frameKey = GlobalKey();

  ui.Image? _decodedImage;
  bool _loading = true;
  bool _saving = false;

  double _zoom = 1;
  Offset _offset = Offset.zero;
  int _quarterTurns = 0;

  double _gestureStartZoom = 1;
  Offset _gestureStartOffset = Offset.zero;
  Offset _gestureStartFocal = Offset.zero;

  Size _frameSize = Size.zero;

  bool get _isProduct => widget.mode == ImageFrameEditorMode.product;
  bool get _isCircle => !_isProduct;

  double get _aspectRatio => _isProduct ? 3 / 2 : 1;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      // Camera JPEGs may keep their physical pixels in sensor orientation
      // and store the visible rotation only in EXIF metadata.
      // Bake that orientation into the pixels before the editor renders it.
      final source = img.decodeImage(widget.sourceBytes);
      if (source == null) {
        throw StateError('image_decode_failed');
      }

      final oriented = img.bakeOrientation(source);
      final normalizedBytes = Uint8List.fromList(
        img.encodePng(oriented),
      );

      final codec = await ui.instantiateImageCodec(normalizedBytes);
      final frame = await codec.getNextFrame();

      if (!mounted) return;
      setState(() {
        _decodedImage = frame.image;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                ru: 'Не удалось открыть изображение.',
                en: 'Could not open the image.',
                hy: 'Չհաջողվեց բացել պատկերը։',
              ),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      });
    }
  }

  String _t({
    required String ru,
    required String en,
    required String hy,
  }) {
    return switch (Localizations.localeOf(context).languageCode) {
      'ru' => ru,
      'hy' => hy,
      _ => en,
    };
  }

  String get _title {
    return switch (widget.mode) {
      ImageFrameEditorMode.product => _t(
        ru: 'Настройте фото товара',
        en: 'Adjust product photo',
        hy: 'Կարգավորեք ապրանքի լուսանկարը',
      ),
      ImageFrameEditorMode.avatar => _t(
        ru: 'Настройте фото профиля',
        en: 'Adjust profile photo',
        hy: 'Կարգավորեք պրոֆիլի լուսանկարը',
      ),
      ImageFrameEditorMode.companyLogo => _t(
        ru: 'Настройте логотип',
        en: 'Adjust logo',
        hy: 'Կարգավորեք լոգոն',
      ),
    };
  }

  String get _hint {
    if (_isProduct) {
      return _t(
        ru: 'Двигайте и масштабируйте фото как хотите. Можно оставить пустые края — изображение не будет растягиваться.',
        en: 'Move and zoom the photo freely. Empty edges are allowed — the image will not be stretched.',
        hy: 'Տեղափոխեք և մեծացրեք լուսանկարը ինչպես ցանկանում եք։ Դատարկ եզրերը թույլատրելի են՝ պատկերը չի ձգվի։',
      );
    }

    return _t(
      ru: 'Круг показывает, как будет выглядеть изображение. Фото можно свободно двигать и масштабировать.',
      en: 'The circle shows the final visible area. Move and zoom the image freely.',
      hy: 'Շրջանը ցույց է տալիս վերջնական տեսանելի հատվածը։ Պատկերը կարող եք ազատ տեղափոխել և մեծացնել։',
    );
  }

  void _reset() {
    setState(() {
      _zoom = 1;
      _offset = Offset.zero;
    });
  }

  void _rotateLeft() {
    setState(() {
      _quarterTurns = (_quarterTurns + 3) % 4;
      _zoom = 1;
      _offset = Offset.zero;
    });
  }

  void _rotateRight() {
    setState(() {
      _quarterTurns = (_quarterTurns + 1) % 4;
      _zoom = 1;
      _offset = Offset.zero;
    });
  }

  Size _effectiveImageSize(ui.Image image) {
    final rotatedSideways = _quarterTurns.isOdd;
    return rotatedSideways
        ? Size(image.height.toDouble(), image.width.toDouble())
        : Size(image.width.toDouble(), image.height.toDouble());
  }

  void _fillFrame() {
    final image = _decodedImage;
    final size = _frameSize;
    if (image == null || size.isEmpty) return;

    final imageSize = _effectiveImageSize(image);

    final containScale = math.min(
      size.width / imageSize.width,
      size.height / imageSize.height,
    );

    final drawnWidth = imageSize.width * containScale;
    final drawnHeight = imageSize.height * containScale;

    final fillZoom = math.max(
      size.width / drawnWidth,
      size.height / drawnHeight,
    );

    setState(() {
      _zoom = fillZoom.clamp(0.15, 8.0).toDouble();
      _offset = Offset.zero;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _gestureStartZoom = _zoom;
    _gestureStartOffset = _offset;
    _gestureStartFocal = details.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final nextZoom =
    (_gestureStartZoom * details.scale).clamp(0.15, 8.0).toDouble();

    // Intentionally do not clamp the translation.
    // The seller may move the image outside the frame and leave empty space.
    final pan = details.localFocalPoint - _gestureStartFocal;

    setState(() {
      _zoom = nextZoom;
      _offset = _gestureStartOffset + pan;
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final renderObject = _frameKey.currentContext?.findRenderObject();
    if (renderObject is! RenderRepaintBoundary) return;

    setState(() => _saving = true);

    try {
      await WidgetsBinding.instance.endOfFrame;

      final targetWidth = _isProduct ? 1800.0 : 1200.0;
      final logicalWidth = renderObject.size.width;

      final pixelRatio = logicalWidth <= 0
          ? 3.0
          : (targetWidth / logicalWidth).clamp(1.0, 6.0).toDouble();

      final rendered = await renderObject.toImage(
        pixelRatio: pixelRatio,
      );
      final byteData = await rendered.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw StateError('image_encode_failed');
      }

      // Keep the exact PNG produced by Flutter's rendering engine.
      // This avoids a second JPEG encoding layer on Android/iOS.
      // Use the ByteData's exact view rather than the whole backing buffer.
      final renderedPngBytes = Uint8List.fromList(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      // PNG signature: 89 50 4E 47 0D 0A 1A 0A
      if (renderedPngBytes.length < 8 ||
          renderedPngBytes[0] != 0x89 ||
          renderedPngBytes[1] != 0x50 ||
          renderedPngBytes[2] != 0x4E ||
          renderedPngBytes[3] != 0x47) {
        throw StateError('png_encode_failed');
      }

      final rawName = widget.outputFileName.trim();
      final baseName = rawName.isEmpty
          ? 'image'
          : rawName.replaceFirst(
        RegExp(r'\.[^.]+$', caseSensitive: false),
        '',
      );
      final pngFileName = '$baseName.png';

      final file = XFile.fromData(
        renderedPngBytes,
        mimeType: 'image/png',
        name: pngFileName,
      );

      if (!mounted) return;

      Navigator.of(context).pop(
        ImageFrameEditorResult(
          bytes: renderedPngBytes,
          file: file,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              ru: 'Не удалось сохранить изображение. Попробуйте ещё раз.',
              en: 'Could not save the image. Please try again.',
              hy: 'Չհաջողվեց պահպանել պատկերը։ Փորձեք կրկին։',
            ),
          ),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Widget _buildFrame(Size available) {
    final image = _decodedImage!;

    final maxWidth = math.max(120.0, available.width - 24);
    final maxHeight = math.max(120.0, available.height * 0.60);

    double width = math.min(maxWidth, 760);
    double height = width / _aspectRatio;

    if (height > maxHeight) {
      height = maxHeight;
      width = height * _aspectRatio;
    }

    if (_isCircle) {
      final side = math.min(width, height);
      width = side;
      height = side;
    }

    final size = Size(width, height);
    _frameSize = size;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _hint,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          onDoubleTap: _reset,
          child: SizedBox(
            width: width,
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                RepaintBoundary(
                  key: _frameKey,
                  child: CustomPaint(
                    painter: _EditableImagePainter(
                      image: image,
                      zoom: _zoom,
                      offset: _offset,
                      quarterTurns: _quarterTurns,
                      background: Colors.white,
                    ),
                  ),
                ),
                IgnorePointer(
                  child: CustomPaint(
                    painter: _FrameGuidePainter(
                      circle: _isCircle,
                      color: _accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _t(
            ru: 'Перетаскивайте одним пальцем • масштабируйте двумя • при необходимости поверните',
            en: 'Drag with one finger • zoom with two • rotate if needed',
            hy: 'Տեղափոխեք մեկ մատով • մեծացրեք երկու մատով • անհրաժեշտության դեպքում պտտեք',
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: _accent),
      )
          : _decodedImage == null
          ? Center(
        child: Text(
          _t(
            ru: 'Изображение недоступно',
            en: 'Image unavailable',
            hy: 'Պատկերը հասանելի չէ',
          ),
          style: const TextStyle(color: Colors.white70),
        ),
      )
          : SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              children: [
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding:
                      const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: _buildFrame(
                        Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  color: const Color(0xFF181818),
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _rotateLeft,
                                icon: const Icon(
                                  Icons.rotate_left_rounded,
                                ),
                                label: Text(
                                  _t(
                                    ru: 'Влево',
                                    en: 'Rotate left',
                                    hy: 'Ձախ',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Colors.white30,
                                  ),
                                  minimumSize:
                                  const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _rotateRight,
                                icon: const Icon(
                                  Icons.rotate_right_rounded,
                                ),
                                label: Text(
                                  _t(
                                    ru: 'Вправо',
                                    en: 'Rotate right',
                                    hy: 'Աջ',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Colors.white30,
                                  ),
                                  minimumSize:
                                  const Size.fromHeight(44),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.zoom_out_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                            Expanded(
                              child: Slider(
                                value: _zoom.clamp(0.15, 8.0),
                                min: 0.15,
                                max: 8.0,
                                activeColor: _accent,
                                inactiveColor: Colors.white24,
                                onChanged: (value) {
                                  setState(() => _zoom = value);
                                },
                              ),
                            ),
                            const Icon(
                              Icons.zoom_in_rounded,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _reset,
                                icon: const Icon(
                                  Icons.fit_screen_rounded,
                                ),
                                label: Text(
                                  _t(
                                    ru: 'Вместить',
                                    en: 'Fit',
                                    hy: 'Տեղավորել',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: Colors.white30,
                                  ),
                                  minimumSize:
                                  const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _fillFrame,
                                icon: const Icon(
                                  Icons.crop_free_rounded,
                                ),
                                label: Text(
                                  _t(
                                    ru: 'Заполнить',
                                    en: 'Fill',
                                    hy: 'Լցնել',
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                    color: _accent,
                                  ),
                                  minimumSize:
                                  const Size.fromHeight(46),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: _saving
                                ? const SizedBox(
                              width: 20,
                              height: 20,
                              child:
                              CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                                : const Icon(Icons.check_rounded),
                            label: Text(
                              _t(
                                ru: 'Готово',
                                en: 'Done',
                                hy: 'Պատրաստ',
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _accent,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(15),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _EditableImagePainter extends CustomPainter {
  const _EditableImagePainter({
    required this.image,
    required this.zoom,
    required this.offset,
    required this.quarterTurns,
    required this.background,
  });

  final ui.Image image;
  final double zoom;
  final Offset offset;
  final int quarterTurns;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = background,
    );

    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    if (imageWidth <= 0 || imageHeight <= 0) return;

    final normalizedTurns = quarterTurns % 4;
    final rotatedSideways = normalizedTurns.isOdd;

    final effectiveWidth =
    rotatedSideways ? imageHeight : imageWidth;
    final effectiveHeight =
    rotatedSideways ? imageWidth : imageHeight;

    // Fit the ROTATED image proportionally into the frame first.
    final containScale = math.min(
      size.width / effectiveWidth,
      size.height / effectiveHeight,
    );

    final scale = containScale * zoom;
    final center = size.center(Offset.zero) + offset;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(normalizedTurns * math.pi / 2);

    final destination = Rect.fromCenter(
      center: Offset.zero,
      width: imageWidth * scale,
      height: imageHeight * scale,
    );

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, imageWidth, imageHeight),
      destination,
      Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _EditableImagePainter oldDelegate) {
    return oldDelegate.image != image ||
        oldDelegate.zoom != zoom ||
        oldDelegate.offset != offset ||
        oldDelegate.quarterTurns != quarterTurns ||
        oldDelegate.background != background;
  }
}

class _FrameGuidePainter extends CustomPainter {
  const _FrameGuidePainter({
    required this.circle,
    required this.color,
  });

  final bool circle;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    if (circle) {
      final circleRect = Rect.fromCircle(
        center: rect.center,
        radius: math.min(size.width, size.height) / 2 - 4,
      );

      final outside = Path()..addRect(rect);
      final hole = Path()..addOval(circleRect);
      final dim = Path.combine(
        PathOperation.difference,
        outside,
        hole,
      );

      canvas.drawPath(
        dim,
        Paint()..color = Colors.black.withValues(alpha: 0.48),
      );

      canvas.drawOval(
        circleRect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = color,
      );
      return;
    }

    final rounded = RRect.fromRectAndRadius(
      rect.deflate(2),
      const Radius.circular(18),
    );

    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _FrameGuidePainter oldDelegate) {
    return oldDelegate.circle != circle || oldDelegate.color != color;
  }
}
