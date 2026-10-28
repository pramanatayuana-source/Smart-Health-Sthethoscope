import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:smart_health_monitor/components/buttons.dart';
import 'package:smart_health_monitor/components/stetho_audio.dart';

class Recorder extends StatefulWidget {
  final String title;
  final ValueChanged<bool> callback;
  final String name;

  const Recorder({super.key, required this.title, required this.callback, required this.name});

  @override
  State<StatefulWidget> createState() {
    // TODO: implement createState
    return _Recorder();
  }
}

class _Recorder extends State<Recorder> {
  Stopwatch _stopwatch = Stopwatch();
  late Timer _timer;
  String timeString = "00:00";

  var isRecording = false;
  var isPaused = false;

  var playButtonAsset = "play";
  var playButtonColor = Colors.lightGreen;

  AudioRecorder? record;

  /// Path of the file being recorded, kept so it can be cleaned on stop.
  String? _recordingPath;

  Future<void> requestPermissions(context) async {
    if (!await Permission.microphone.isGranted) {
      await Permission.microphone.request();
      requestPermissions(context);
      return;
    }
  }

  /// Capture settings for chest-piece recordings: mono 16 kHz WAV so the
  /// stethoscope cleanup pipeline can post-process the raw PCM, with the
  /// device's hardware noise suppressor engaged for convention-floor roar.
  static const RecordConfig _stethoConfig = RecordConfig(
    encoder: AudioEncoder.wav,
    sampleRate: 44100,
    numChannels: 1,
    bitRate: 128000,
    autoGain: true,
    echoCancel: false,
    noiseSuppress: true,
    androidConfig: AndroidRecordConfig(
      useLegacy: false,
      muteAudio: true,
      manageBluetooth: false,
      audioSource: AndroidAudioSource.unprocessed,
    ),
  );

  Future<void> startRecording() async {
    if (isRecording) {
      await stopRecording();
      return;
    }

    var directory = await getDownloadPath();
    if (directory == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please grant permissions.")));
      return;
    }

    record = AudioRecorder();

    if (!await record!.hasPermission()) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Please grant permissions.")));
      await record!.dispose();
      return;
    }

    var dateStamp = DateTime.now().toIso8601String().replaceAll(":", "_").replaceAll(".", "?");
    var fileName = widget.name;
    final path = "$directory/$fileName-$dateStamp.wav";
    _recordingPath = path;
    await record!.start(_stethoConfig, path: path);

    _stopwatch.start();

    setState(() {
      isRecording = true;
      playButtonAsset = "stop";
      playButtonColor = Colors.red;
    });
  }

  Future<void> stopRecording() async {
    if (!isRecording) {
      return;
    }
    final recordedPath = await record!.stop() ?? _recordingPath;
    await record!.dispose();
    record = null;

    // Clean the take before it lands in storage / the analyser.
    final messenger = ScaffoldMessenger.of(context);
    final cleaned = await StethoAudio.cleanFile(recordedPath ?? "");

    if (!mounted) {
      return;
    }
    setState(() {
      isPaused = false;
      isRecording = false;
      _stopwatch.stop();
      _stopwatch.reset();
      playButtonAsset = "play";
      playButtonColor = Colors.lightGreen;
    });
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          cleaned
              ? "Saved ${widget.name} (noise filtered)"
              : "Saved ${widget.name}",
        ),
      ),
    );
  }

  void setupTimer() {
    _timer = Timer.periodic(const Duration(milliseconds: 64), (timer) {
      var seconds = _stopwatch.elapsedMilliseconds / 1000;
      var minutes = seconds / 60;
      seconds = seconds % 60;

      setState(() {
        timeString =
            "${minutes.floor().toString().padLeft(2, '0')}:${seconds.floor().toString().padLeft(2, '0')}";
      });
    });
  }

  Future<String?> getDownloadPath() async {
    var perms = await Permission.storage.status;
    if (perms.isDenied) {
      await Permission.storage.request();
    }
    var downloads = await getApplicationDocumentsDirectory();
    var usageFolder = Directory("${downloads.path}/Recordings");
    if (!await usageFolder.exists()) {
      await usageFolder.create();
    }
    return usageFolder.path;
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    setupTimer();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _timer.cancel();
    record?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.callback(isRecording);
    // TODO: implement build
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  timeString,
                  style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 64),
                AnimatedSwitcher(
                  duration: Duration(seconds: 1),
                  child: PlayerButton(
                    icon: "assets/player-$playButtonAsset.png",
                    onPressed: startRecording,
                    color: playButtonColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
