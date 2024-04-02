// export "cljd-out/acme/main.dart" show main;

import 'dart:math';
import 'dart:async';

import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:flutter/material.dart';
import 'package:audio_streamer/audio_streamer.dart';
// import 'package:mic_stream/mic_stream.dart';
import 'package:permission_handler/permission_handler.dart';

void main() => runApp(AudioStreamingApp());

class AudioStreamingApp extends StatefulWidget {
  @override
  AudioStreamingAppState createState() => AudioStreamingAppState();
}

class AudioStreamingAppState extends State<AudioStreamingApp> {
  int? sampleRate;
  bool isRecording = false;
  List<double> audio = [];
  List<double>? latestBuffer;
  double? recordingTime;
  StreamSubscription<List<double>>? audioSubscription;

  /// Check if microphone permission is granted.
  Future<bool> checkPermission() async => await Permission.microphone.isGranted;

  /// Request the microphone permission.
  Future<void> requestPermission() async =>
      await Permission.microphone.request();

  /// Call-back on audio sample.
  void onAudio(List<double> buffer) async {
    audio.addAll(buffer);

    // Get the actual sampling rate, if not already known.
    sampleRate ??= await AudioStreamer().actualSampleRate;
    recordingTime = audio.length / sampleRate!;

    setState(() => latestBuffer = buffer);
  }

  /// Call-back on error.
  void handleError(Object error) {
    setState(() => isRecording = false);
    print(error);
  }

  /// Start audio sampling.
  void start() async {
    // Check permission to use the microphone.
    //
    // Remember to update the AndroidManifest file (Android) and the
    // Info.plist and pod files (iOS).
    if (!(await checkPermission())) {
      await requestPermission();
    }

    // Set the sampling rate - works only on Android.
    AudioStreamer().sampleRate = 22100;

    // Start listening to the audio stream.
    // audioSubscription =
    //     AudioStreamer().audioStream.listen(onAudio, onError: handleError);
    Stream<List<double>> micStream = AudioStreamer().audioStream;
    audioSubscription = micStream.listen(onAudio, onError: handleError);

    // Submit micStream to DeepGram
    // -------------------- From a stream  --------------------
    // Stream<String> jsonStream = deepgram.transcribeFromLiveAudioStream(micStream);

    // or to have more control over the stream

    Deepgram deepgram = Deepgram(apiKey, baseQueryParams: params);
    DeepgramLiveTranscriber transcriber =
        deepgram.createLiveTranscriber(micStream);

    transcriber.start();
    transcriber.jsonStream.listen((val) {
      print(val);
    }, onError: (err) {
      print("ERROR ");
      print(err);
    }, cancelOnError: true);
    // transcriber.close();

    setState(() => isRecording = true);
  }

  /// Stop audio sampling.
  void stop() async {
    audioSubscription?.cancel();
    setState(() => isRecording = false);
  }

  Map<String, dynamic> params = {
    'model': 'nova-2-general',
    'language': 'en',
    'filler_words': false,
    'punctuation': true,
  };
  String apiKey = <DEEPGRAM_API_KEY HERE>;

  @override
  Widget build(BuildContext context) => MaterialApp(
        home: Scaffold(
          body: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                Container(
                    margin: const EdgeInsets.all(25),
                    child: Column(children: [
                      Container(
                        margin: const EdgeInsets.only(top: 20),
                        child: Text(isRecording ? "Mic: ON" : "Mic: OFF",
                            style: const TextStyle(
                                fontSize: 25, color: Colors.blue)),
                      ),
                      const Text(''),
                      Text('Max amp: ${latestBuffer?.reduce(max)}'),
                      Text('Min amp: ${latestBuffer?.reduce(min)}'),
                      Text(
                          '${recordingTime?.toStringAsFixed(2)} seconds recorded.'),
                    ])),
              ])),
          floatingActionButton: FloatingActionButton(
            backgroundColor: isRecording ? Colors.red : Colors.green,
            onPressed: isRecording ? stop : start,
            child: isRecording ? const Icon(Icons.stop) : const Icon(Icons.mic),
          ),
        ),
      );
}
