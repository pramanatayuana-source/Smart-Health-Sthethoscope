import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:smart_health_monitor/components/noise_reduction.dart';
import 'package:smart_health_monitor/l10n/app_localizations.dart';
import 'package:camera/camera.dart';

class DiagnoseHeart extends StatefulWidget {
  const DiagnoseHeart({super.key});

  @override
  State<StatefulWidget> createState() {
    return _DiagnoseHeart();
  }
}

class _DiagnoseHeart extends State<DiagnoseHeart> {
  late AppLocalizations localizations;
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late List<CameraDescription> cameras;

  var avgRed = 0;
  var debounce = 0;
  var outBpm = 60.0;

  final NoiseReduction _noiseReducer = NoiseReduction(
    windowSize: DiagnosticSettings.defaultNoiseWindow,
  );

  Future<void> setup() async {
    if (!await Permission.camera.isGranted) {
      await Permission.camera.request();
    }
    _noiseReducer.enabled = DiagnosticSettings.noiseReductionEnabled;
    _noiseReducer.reset();
    cameras = await availableCameras();
    _controller = CameraController(cameras.first, ResolutionPreset.high);

    var lastAvg = 0.0;
    var lastBeep = DateTime.now().millisecondsSinceEpoch;
    var averageBPM = 70.0;

    await _controller.initialize();
    _controller.startImageStream((image) {
      if (debounce < 3) {
        debounce++;
        return;
      }
      debounce = 0;
      var yPlane = image.planes[0];
      if (yPlane.bytes.isEmpty) {
        avgRed = 0;
        return;
      }

      var avg = 0.0;
      for (int i = 0; i < yPlane.bytes.length; i++) {
        avg += yPlane.bytes[i];
      }
      avg /= yPlane.bytes.length;

      // Pre-process the luminance signal to suppress camera noise before
      // peak detection. Toggleable via DiagnosticSettings.noiseReductionEnabled.
      avg = _noiseReducer.apply(avg);

      var diff = avg - lastAvg;
      lastAvg = avg;

      print("Avg lume $avg");

      if (diff > -20.0 && diff < -1.5) {
        var beepTime = DateTime.now().millisecondsSinceEpoch;
        var bpm = 60000 / (beepTime - lastBeep).toDouble();
        lastBeep = beepTime;
        if ((averageBPM - bpm).abs() > 25) {
          print("Mismatch $averageBPM $bpm");
          return;
        }

        averageBPM = averageBPM * 3 + bpm;
        averageBPM /= 4;

        setState(() {
          outBpm = averageBPM;
        });

        print("BEEP $averageBPM");
      }
    });
    print("Initialized camera");
  }

  Future<void> disposeCamera() async {
    await _controller.setExposureMode(ExposureMode.auto);
    await _controller.setExposureOffset(0.5);
    await _controller.setFlashMode(FlashMode.off);
    await _controller.setFocusMode(FocusMode.auto);
    await _controller.dispose();
  }

  @override
  void initState() {
    super.initState();

    _initializeControllerFuture = setup();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    disposeCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.diagnose)),
      body: FutureBuilder(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    localizations.heartbeatInstruction,
                    style: TextStyle(fontSize: 25, fontWeight: FontWeight.w400),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(width: 256, child: CameraPreview(_controller)),
                  Text(localizations.yourBpmIs, style: TextStyle(fontSize: 25),),
                  Text("${outBpm.toInt()}", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),)
                ],
              ),
            );
          } else {
            return Expanded(child: Center(child: CircularProgressIndicator()));
          }
        },
      ),
    );
  }
}
