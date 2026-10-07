// lib/screens/product_camera_screen.dart

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart' show XFile;

/// Camera screen shared by HOT and Deals.
///
/// Important:
/// - the yellow 3:2 frame is only a composition guide;
/// - the captured file is NOT cropped;
/// - after capture we only PREVIEW how the center 3:2 area will look in a card;
/// - "Use photo" returns the original full XFile.
class ProductCameraScreen extends StatefulWidget {
  const ProductCameraScreen({super.key});

  @override
  State<ProductCameraScreen> createState() => _ProductCameraScreenState();
}

class _ProductCameraScreenState extends State<ProductCameraScreen>
    with WidgetsBindingObserver {
  static const Color _accentColor = Color(0xFFD1BC00);

  CameraController? _controller;
  CameraDescription? _camera;

  bool _initializing = true;
  bool _takingPicture = false;
  String? _errorCode;

  XFile? _capturedFile;
  Uint8List? _capturedBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _prepareCameraScreen();
  }

  Future<void> _prepareCameraScreen() async {
    // Let the seller shoot naturally in portrait or landscape.
    if (!kIsWeb) {
      await SystemChrome.setPreferredOrientations(
        const [
          DeviceOrientation.portraitUp,
          DeviceOrientation.portraitDown,
          DeviceOrientation.landscapeLeft,
          DeviceOrientation.landscapeRight,
        ],
      );

      await Future<void>.delayed(const Duration(milliseconds: 160));
    }

    if (!mounted) return;
    await _initializeFirstCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;

    if (_capturedFile != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      _controller = null;
      controller.dispose();
    } else if (state == AppLifecycleState.resumed && _camera != null) {
      _initializeCamera(_camera!);
    }
  }

  Future<void> _initializeFirstCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _errorCode = null;
      });
    }

    try {
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _errorCode = 'no_camera';
        });
        return;
      }

      CameraDescription selected = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selected = camera;
          break;
        }
      }

      _camera = selected;
      await _initializeCamera(selected);
    } on CameraException catch (error) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorCode = error.code;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _errorCode = 'camera_error';
      });
    }
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    final previous = _controller;
    _controller = null;

    if (previous != null) {
      try {
        await previous.dispose();
      } catch (_) {}
    }

    if (!mounted) return;

    setState(() {
      _initializing = true;
      _errorCode = null;
    });

    final controller = CameraController(
      camera,
      ResolutionPreset.veryHigh,
      enableAudio: false,
    );

    try {
      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      setState(() => _initializing = false);
    } on CameraException catch (error) {
      await controller.dispose();

      if (!mounted) return;
      setState(() {
        _controller = null;
        _initializing = false;
        _errorCode = error.code;
      });
    } catch (_) {
      await controller.dispose();

      if (!mounted) return;
      setState(() {
        _controller = null;
        _initializing = false;
        _errorCode = 'camera_error';
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

  String _cameraErrorText() {
    return switch (_errorCode) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' =>
          _t(
            ru: 'Разрешите Appsosa доступ к камере в настройках устройства.',
            en: 'Allow Appsosa to access the camera in your device settings.',
            hy: 'Թույլատրեք Appsosa-ին օգտագործել տեսախցիկը սարքի կարգավորումներում։',
          ),
      'CameraAccessRestricted' => _t(
        ru: 'Доступ к камере ограничен настройками устройства.',
        en: 'Camera access is restricted by device settings.',
        hy: 'Տեսախցիկի հասանելիությունը սահմանափակված է սարքի կարգավորումներով։',
      ),
      'no_camera' => _t(
        ru: 'Камера на устройстве не найдена.',
        en: 'No camera was found on this device.',
        hy: 'Սարքում տեսախցիկ չի գտնվել։',
      ),
      _ => _t(
        ru: 'Не удалось открыть камеру. Попробуйте ещё раз.',
        en: 'Could not open the camera. Please try again.',
        hy: 'Չհաջողվեց բացել տեսախցիկը։ Փորձեք կրկին։',
      ),
    };
  }

  Future<XFile> _normalizeCapturedOrientation(
      XFile file,
      DeviceOrientation capturedOrientation,
      ) async {
    try {
      final rawBytes = await file.readAsBytes();
      var decoded = img.decodeImage(rawBytes);

      if (decoded == null) return file;

      decoded = img.bakeOrientation(decoded);

      final wantsLandscape =
          capturedOrientation == DeviceOrientation.landscapeLeft ||
              capturedOrientation == DeviceOrientation.landscapeRight;
      final wantsPortrait =
          capturedOrientation == DeviceOrientation.portraitUp ||
              capturedOrientation == DeviceOrientation.portraitDown;

      final pixelsArePortrait = decoded.height > decoded.width;
      final pixelsAreLandscape = decoded.width > decoded.height;

      if (wantsLandscape && pixelsArePortrait) {
        decoded = img.copyRotate(
          decoded,
          angle: capturedOrientation == DeviceOrientation.landscapeLeft
              ? 90
              : -90,
        );
      } else if (wantsPortrait && pixelsAreLandscape) {
        if (capturedOrientation == DeviceOrientation.portraitDown) {
          decoded = img.copyRotate(decoded, angle: 180);
        } else {
          decoded = img.copyRotate(decoded, angle: 90);
        }
      }

      final normalizedBytes = img.encodeJpg(decoded, quality: 94);

      return XFile.fromData(
        normalizedBytes,
        mimeType: 'image/jpeg',
        name: 'product_camera_normalized.jpg',
      );
    } catch (_) {
      return file;
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _takingPicture) {
      return;
    }

    setState(() => _takingPicture = true);

    final capturedOrientation = controller.value.deviceOrientation;

    try {
      final file = await controller.takePicture();
      final normalized = await _normalizeCapturedOrientation(
        file,
        capturedOrientation,
      );

      if (!mounted) return;

      setState(() => _takingPicture = false);

      Navigator.of(context).pop<XFile>(normalized);
    } on CameraException {
      if (!mounted) return;
      setState(() => _takingPicture = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              ru: 'Не удалось сделать фото. Попробуйте ещё раз.',
              en: 'Could not take the photo. Please try again.',
              hy: 'Չհաջողվեց լուսանկարել։ Փորձեք կրկին։',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _takingPicture = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              ru: 'Не удалось сделать фото. Попробуйте ещё раз.',
              en: 'Could not take the photo. Please try again.',
              hy: 'Չհաջողվեց լուսանկարել։ Փորձեք կրկին։',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _retake() {
    setState(() {
      _capturedFile = null;
      _capturedBytes = null;
    });
  }

  void _usePhoto() {
    final file = _capturedFile;
    if (file == null) return;

    // Return the ORIGINAL full photo. The 3:2 preview is visual only.
    Navigator.of(context).pop<XFile>(file);
  }

  void _close() {
    if (_capturedFile != null) {
      _retake();
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    final controller = _controller;
    _controller = null;
    controller?.dispose();

    // The rest of Appsosa is portrait-oriented.
    if (!kIsWeb) {
      unawaited(
        SystemChrome.setPreferredOrientations(
          const [DeviceOrientation.portraitUp],
        ),
      );
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedFile != null && _capturedBytes != null) {
      return _buildPhotoReview();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _initializing
            ? const Center(
          child: CircularProgressIndicator(color: _accentColor),
        )
            : _errorCode != null
            ? _buildError()
            : _buildCamera(),
      ),
    );
  }

  Widget _buildError() {
    return Stack(
      children: [
        Positioned(
          left: 8,
          top: 4,
          child: IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.no_photography_outlined,
                  size: 58,
                  color: Colors.white70,
                ),
                const SizedBox(height: 18),
                Text(
                  _cameraErrorText(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _initializeFirstCamera,
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                  ),
                  child: Text(
                    _t(
                      ru: 'Повторить',
                      en: 'Try again',
                      hy: 'Կրկնել',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCamera() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            _CameraPreviewCover(controller: controller),
            Positioned(
              left: 8,
              top: 4,
              child: IconButton(
                onPressed: _takingPicture ? null : _close,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.34),
                ),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: 16,
              child: IgnorePointer(
                child: Column(
                  children: [
                    Text(
                      _t(
                        ru: 'Снимайте как удобно — вертикально или горизонтально',
                        en: 'Shoot however you like — portrait or landscape',
                        hy: 'Լուսանկարեք ինչպես հարմար է՝ ուղղահայաց կամ հորիզոնական',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _t(
                        ru: 'После снимка вы сможете настроить положение фото в рамке',
                        en: 'After the shot, you can position the photo freely in the frame',
                        hy: 'Լուսանկարելուց հետո կարող եք ազատ կարգավորել պատկերի դիրքը շրջանակում',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            blurRadius: 8,
                            color: Colors.black87,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 22,
              child: Center(
                child: GestureDetector(
                  onTap: _takingPicture ? null : _takePicture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(
                        color: _takingPicture
                            ? Colors.white54
                            : _accentColor,
                        width: 5,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: _takingPicture
                        ? const Padding(
                      padding: EdgeInsets.all(22),
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: _accentColor,
                      ),
                    )
                        : const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.black87,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Rect _guideRect(Size size) {
    final maxWidth = size.width * 0.90;
    final maxHeight = size.height * 0.50;

    final width = math.min(maxWidth, maxHeight * 1.5);
    final height = width / 1.5;

    final centerY = size.height * 0.47;

    return Rect.fromCenter(
      center: Offset(size.width / 2, centerY),
      width: width,
      height: height,
    );
  }

  Widget _buildPhotoReview() {
    final bytes = _capturedBytes!;

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111111),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: _retake,
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          _t(
            ru: 'Фото товара',
            en: 'Product photo',
            hy: 'Ապրանքի լուսանկար',
          ),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                children: [
                  Text(
                    _t(
                      ru: 'Так фотография будет выглядеть в карточке',
                      en: 'This is how the photo will look in the product card',
                      hy: 'Այսպես լուսանկարը կերևա ապրանքի քարտում',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _t(
                      ru: 'Сам снимок сохраняется полностью — здесь только предпросмотр 3:2.',
                      en: 'The full photo is kept — this is only a 3:2 preview.',
                      hy: 'Լուսանկարը պահպանվում է ամբողջությամբ․ այստեղ միայն 3:2 նախադիտումն է։',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AspectRatio(
                    aspectRatio: 3 / 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.memory(
                        bytes,
                        fit: BoxFit.cover,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _retake,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(
                              _t(
                                ru: 'Переснять',
                                en: 'Retake',
                                hy: 'Կրկին նկարել',
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _usePhoto,
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              _t(
                                ru: 'Использовать',
                                en: 'Use photo',
                                hy: 'Օգտագործել',
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _accentColor,
                              foregroundColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CameraPreviewCover extends StatelessWidget {
  final CameraController controller;

  const _CameraPreviewCover({
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final previewSize = controller.value.previewSize;

    if (previewSize == null ||
        previewSize.width <= 0 ||
        previewSize.height <= 0) {
      return Center(
        child: CameraPreview(controller),
      );
    }

    // CameraPreview changes its own aspect ratio depending on the current
    // physical device orientation. We calculate the SAME effective ratio
    // here and then scale the whole preview uniformly with BoxFit.cover.
    //
    // This avoids giving CameraPreview a wrong tight width/height, which can
    // visibly squash/stretch the image in landscape.
    final orientation = controller.value.deviceOrientation;
    final isLandscape =
        orientation == DeviceOrientation.landscapeLeft ||
            orientation == DeviceOrientation.landscapeRight;

    final sensorAspect = previewSize.width / previewSize.height;
    final displayAspect = isLandscape ? sensorAspect : 1 / sensorAspect;

    const logicalHeight = 1000.0;
    final logicalWidth = logicalHeight * displayAspect;

    return ClipRect(
      child: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: logicalWidth,
            height: logicalHeight,
            child: CameraPreview(controller),
          ),
        ),
      ),
    );
  }
}

class _ProductGuidePainter extends CustomPainter {
  final Rect frame;
  final Color color;

  const _ProductGuidePainter({
    required this.frame,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          frame,
          const Radius.circular(18),
        ),
      );

    final overlay = Path.combine(
      PathOperation.difference,
      full,
      hole,
    );

    canvas.drawPath(
      overlay,
      Paint()..color = Colors.black.withValues(alpha: 0.34),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        frame,
        const Radius.circular(18),
      ),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = color,
    );

    const corner = 24.0;
    const cornerWidth = 5.0;

    final cornerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = cornerWidth
      ..strokeCap = StrokeCap.round
      ..color = color;

    // Top-left
    canvas.drawLine(
      Offset(frame.left + 3, frame.top + corner),
      Offset(frame.left + 3, frame.top + 7),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frame.left + 7, frame.top + 3),
      Offset(frame.left + corner, frame.top + 3),
      cornerPaint,
    );

    // Top-right
    canvas.drawLine(
      Offset(frame.right - corner, frame.top + 3),
      Offset(frame.right - 7, frame.top + 3),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frame.right - 3, frame.top + 7),
      Offset(frame.right - 3, frame.top + corner),
      cornerPaint,
    );

    // Bottom-left
    canvas.drawLine(
      Offset(frame.left + 3, frame.bottom - corner),
      Offset(frame.left + 3, frame.bottom - 7),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frame.left + 7, frame.bottom - 3),
      Offset(frame.left + corner, frame.bottom - 3),
      cornerPaint,
    );

    // Bottom-right
    canvas.drawLine(
      Offset(frame.right - corner, frame.bottom - 3),
      Offset(frame.right - 7, frame.bottom - 3),
      cornerPaint,
    );
    canvas.drawLine(
      Offset(frame.right - 3, frame.bottom - corner),
      Offset(frame.right - 3, frame.bottom - 7),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ProductGuidePainter oldDelegate) {
    return oldDelegate.frame != frame || oldDelegate.color != color;
  }
}
