import 'dart:io';

import 'package:camera/camera.dart';

class Cameras {

  static Future<CameraController> open(CameraDescription des) async {
    var controller = CameraController(des, ResolutionPreset.max,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888
    );
    await controller.initialize();
    return controller;
  }

  static late final List<CameraDescription> _cameras;

  static Future<void> init() async {
    _cameras = await availableCameras();
  }

  static List<CameraDescription> getBacks() => _cameras
      .where((c) => c.lensDirection == CameraLensDirection.back)
      .toList();
}