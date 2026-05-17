import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/design_system/app_colors.dart';
import '../../core/design_system/app_theme.dart';
import '../../core/design_system/press_scale.dart';
import '../../services/offline_reel_queue.dart';

enum _ReelPhase { idle, recording, done }

class RecordReelScreen extends StatefulWidget {
  const RecordReelScreen({super.key, required this.onBack, required this.onDone});
  final VoidCallback onBack;
  final void Function(String? path) onDone;

  @override
  State<RecordReelScreen> createState() => _RecordReelScreenState();
}

class _RecordReelScreenState extends State<RecordReelScreen> {
  CameraController? _camera;
  _ReelPhase _phase = _ReelPhase.idle;
  int _seconds = 0;
  Timer? _timer;
  String? _videoPath;
  static const _maxSeconds = 30;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final cams = await availableCameras();
    final front = cams.firstWhere((c) => c.lensDirection == CameraLensDirection.front, orElse: () => cams.first);
    final ctrl = CameraController(front, ResolutionPreset.high, enableAudio: true);
    await ctrl.initialize();
    if (mounted) setState(() => _camera = ctrl);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _camera?.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_camera == null || !_camera!.value.isInitialized) return;
    await _camera!.startVideoRecording();
    setState(() {
      _phase = _ReelPhase.recording;
      _seconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_seconds >= _maxSeconds) {
        _stopRecording();
        return;
      }
      setState(() => _seconds++);
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    if (_camera == null || !_camera!.value.isRecordingVideo) return;
    final file = await _camera!.stopVideoRecording();
    setState(() {
      _phase = _ReelPhase.done;
      _videoPath = file.path;
    });
  }

  Future<void> _submit() async {
    if (_videoPath != null) {
      await OfflineReelQueue.instance.enqueueRawRecording(_videoPath!);
    }
    widget.onDone(_videoPath);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<GrayManTheme>();
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_camera != null && _camera!.value.isInitialized)
            CameraPreview(_camera!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconButton(onPressed: widget.onBack, icon: const Icon(Icons.close, color: Colors.white)),
                      const Spacer(),
                      if (_phase == _ReelPhase.recording)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: AppColors.errorRed, borderRadius: BorderRadius.circular(20)),
                          child: Text('REC ${_seconds}s / $_maxSeconds', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                        ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_phase == _ReelPhase.idle)
                  Text(theme.t('30-second intro reel', '30 सेकंड का परिचय रील'), style: const TextStyle(color: Colors.white70, fontSize: 16))
                else if (_phase == _ReelPhase.done)
                  Text(theme.t('Looking good!', 'बढ़िया लग रहा है!'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_phase == _ReelPhase.idle)
                        PressScaleButton(
                          onPressed: _startRecording,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 4), color: AppColors.errorRed),
                          ),
                        )
                      else if (_phase == _ReelPhase.recording)
                        PressScaleButton(
                          onPressed: _stopRecording,
                          child: Container(width: 72, height: 72, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                        )
                      else
                        PressScaleButton(
                          onPressed: _submit,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(16)),
                            child: Text(theme.t('Submit & Continue', 'जमा करें'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
