import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:peephole/cameras.dart';
import 'package:peephole/eyes.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<StatefulWidget> createState() => _AppState();
}

class _AppState extends State<App> {
  
  // UI

  bool isShowingView = true;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // decrease power drain
      body: Stack(
        children: [

          // actual view
          if (isShowingView) Positioned(top: 0, bottom: 0, child: view()),

          // fps
          Positioned(
            left: 30, right: 30,
            bottom: 30,
            
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(100),
              ),
              
              child: Stack(
                alignment: Alignment.center,
                children: [

                  // fps counter
                  Positioned(
                    left: 0,
                    child: Text("$fps fps",
                      style: justUpdated ? const TextStyle(color: Colors.green) : null,
                    ),
                  ),

                  // name of camera
                  Text(current.description.name.split(".").last),

                  // zoom
                  Positioned(
                    right: 0,
                    child: Text("${midZoom.toStringAsFixed(1)}x"),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Colors.black,
    );
  }

  // camera view
  Widget view() => FutureBuilder(
    future: currentFuture,

    builder: (context, snapshot) {
      if (!snapshot.hasData) return const SizedBox(); // TODO alternative?
      return Center(
        child: GestureDetector(
          onScaleUpdate: onZoomChange,
          onScaleEnd: onZoomEnd,
          onTapDown: onFocus,
          onLongPress: toggleNext,

          child: CameraPreview(snapshot.data!),
        ),
      );
    },
  );

  // zoom

  double zoom = 1.0;
  double midZoom = 1.0;
  late double minZoom;
  late double maxZoom;

  // intermediate zoom
  Future<void> onZoomChange(ScaleUpdateDetails d) async {
    midZoom = (zoom * d.scale).clamp(minZoom, maxZoom);
    setState(() {});
    await current.setZoomLevel(midZoom);
  }

  // reset new start zoom point
  void onZoomEnd(ScaleEndDetails d) => zoom = midZoom;

  // focus

  Future<void> onFocus(TapDownDetails d) async {
    // rescale for screen TODO right scale factor
    var screen = MediaQuery.of(context).size;
    await current.setFocusPoint(d.localPosition.scale(1/screen.width, 1/screen.height));
  }
  
  // LOGIC

  final eyes = Eyes(
    recognise: true,
    analyse: true,
    minFaceSize: 0.1,
    priority: FaceDetectorMode.accurate,
  );

  // frames

  int parallelFrames = 0;
  final int maxParallelFrames = 1 /*Platform.numberOfProcessors - 1*/;

  DateTime lastFpsUpdate = DateTime.now();
  int fpsCount = 0;
  int fps = 0;
  bool justUpdated = false;

  Future<void> onFrame(CameraImage frame) async {
    // drop frames to avoid build up
    if (parallelFrames < maxParallelFrames) {
      parallelFrames++;
      await processFrame(frame);
      parallelFrames--;
    }

    // fps monitor
    var now = DateTime.now();
    var since = now.difference(lastFpsUpdate);
    // update flash
    if (since.inMilliseconds >= 100 && justUpdated) {
      justUpdated = false;
      setState(() {});
    }
    // reset counter
    if (since.inSeconds >= 1) {
      fps = fpsCount;
      fpsCount = 0;
      lastFpsUpdate = now;
      justUpdated = true;
      setState(() {});
    }
  }

  Future<void> processFrame(CameraImage frame) async {
    fpsCount += 1; // update count

    final faces = await eyes.see(convFrame(frame));
    // if (faces.isNotEmpty) print("Faces:");
    // for (var face in faces) {
    //   print(" - ${face.trackingId}\n   Eyes: (${face.leftEyeOpenProbability}, ${face.rightEyeOpenProbability})\n   Smile: ${face.smilingProbability}");
    // }
  }

  // CAMERA MANAGEMENT

  late Future<CameraController> currentFuture;
  late CameraController current;
  int currentNth = -1;
  List<CameraDescription> cameras = Cameras.getBacks();

  // switch camera
  void toggleNext() {
    // if only one
    if (cameras.length == 1) return;

    currentNth = (currentNth + 1) % cameras.length;
    currentFuture = Cameras.open(cameras[currentNth])
      .then((c) async {
        // get zoom thresholds
        zoom = midZoom = minZoom = await c.getMinZoomLevel();
        await c.setZoomLevel(minZoom);
        maxZoom = await c.getMaxZoomLevel();
        // start frame capture
        await c.startImageStream(onFrame);

        current = c;
        return c;
      });
    setState(() {});
  }
  
  @override
  void initState() {
    super.initState();
    toggleNext();
  }

  // util

  InputImage convFrame(CameraImage image) {
    final _orientations = {
      DeviceOrientation.portraitUp: 0,
      DeviceOrientation.landscapeLeft: 90,
      DeviceOrientation.portraitDown: 180,
      DeviceOrientation.landscapeRight: 270,
    };

    // adjust for image rotation
    final camera = cameras[currentNth];
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = _orientations[current.value.deviceOrientation];
      if (rotationCompensation == null) throw Exception("invalid image");
      if (camera.lensDirection == CameraLensDirection.front) {
        // front-facing
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        // back-facing
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) throw Exception("invalid image");

    // get image format
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    // validate format depending on platform
    // only supported formats:
    // * nv21 for Android
    // * bgra8888 for iOS
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) throw Exception("invalid image");

    // since format is constraint to nv21 or bgra8888, both only have one plane
    if (image.planes.length != 1) throw Exception("invalid image");
    final plane = image.planes.first;

    // compose InputImage using bytes
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation, // used only in Android
        format: format, // used only in iOS
        bytesPerRow: plane.bytesPerRow, // used only in iOS
      ),
    );
  }
}