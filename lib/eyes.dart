import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class Eyes {
  late FaceDetector _detector;

  Eyes({
    bool recognise = false,
    bool analyse = false,
    double minFaceSize = 0,
    FaceDetectorMode priority = FaceDetectorMode.fast,
  }) {
    _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: analyse,
          enableTracking: recognise,
          minFaceSize: minFaceSize,
          performanceMode: priority,
        ),
    );
  }

  Future<List<Face>> see(InputImage view) {
    return _detector.processImage(view);
  }
}