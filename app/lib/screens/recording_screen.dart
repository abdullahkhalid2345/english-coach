import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../config.dart';
import 'results_screen.dart';

/// Screen 2: record the student speaking about the topic.
class RecordingScreen extends StatefulWidget {
  final String topic;

  const RecordingScreen({super.key, required this.topic});

  @override
  State<RecordingScreen> createState() => _RecordingScreenState();
}

class _RecordingScreenState extends State<RecordingScreen> with SingleTickerProviderStateMixin {
  // The "record" package does the actual recording.
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool _permissionDenied = false;
  int _seconds = 0;
  Timer? _timer;

  // Makes the circle around the button gently "breathe" while recording.
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void dispose() {
    // Clean up when leaving the screen (this also stops any recording).
    _timer?.cancel();
    _pulse.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    // Ask for microphone permission. The phone shows its own pop-up the
    // first time. If the user said no, hasPermission() returns false.
    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      setState(() => _permissionDenied = true);
      return;
    }

    // Save the recording in the phone's temporary folder.
    final folder = await getTemporaryDirectory();
    final path = '${folder.path}/recording_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc, // .m4a
        sampleRate: 16000, // speech doesn't need more, and the file stays small
        numChannels: 1, // mono
        bitRate: 64000,
      ),
      path: path,
    );

    setState(() {
      _permissionDenied = false;
      _isRecording = true;
      _seconds = 0;
    });
    _pulse.repeat(reverse: true);

    // Count the seconds. Stop by ourselves at the maximum length.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() => _seconds++);
      if (_seconds >= maxRecordingSeconds) {
        _stopRecording();
      }
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    _timer?.cancel();
    _pulse.stop();
    final path = await _recorder.stop();
    setState(() => _isRecording = false);

    if (!mounted) return;
    if (path == null) {
      _showMessage('Something went wrong with the recording. Please try again.');
      return;
    }
    if (_seconds < minRecordingSeconds) {
      _showMessage('That was a bit short. Try speaking for a little longer.');
      return;
    }

    // Go to the results screen. "Replacement" means the back button goes
    // to the home screen, not back to this finished recording.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ResultsScreen(topic: widget.topic, audioPath: path)),
    );
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  /// 75 -> "1:15"
  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final buttonColor = _isRecording ? colors.error : colors.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Your turn to speak')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // The topic, as a reminder
              Text('Topic', style: theme.textTheme.labelLarge?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(widget.topic, style: theme.textTheme.headlineSmall),
              const Spacer(),

              // The timer
              Text(
                _formatTime(_seconds),
                textAlign: TextAlign.center,
                style: theme.textTheme.displayMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()], // digits don't jump around
                  color: _isRecording ? colors.error : colors.onSurface,
                ),
              ),
              Text(
                'Up to ${_formatTime(maxRecordingSeconds)}',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 40),

              // The big record / stop button, with a pulsing ring while recording
              Center(
                child: SizedBox(
                  width: 200,
                  height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_isRecording)
                        ScaleTransition(
                          scale: Tween(begin: 0.8, end: 1.0).animate(
                            CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: buttonColor.withValues(alpha: 0.18),
                            ),
                          ),
                        ),
                      SizedBox(
                        width: 140,
                        height: 140,
                        child: FilledButton(
                          onPressed: _isRecording ? _stopRecording : _startRecording,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            backgroundColor: buttonColor,
                          ),
                          child: Icon(
                            _isRecording ? Icons.stop_rounded : Icons.mic,
                            size: 64,
                            semanticLabel: _isRecording ? 'Stop recording' : 'Start recording',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                _isRecording ? 'Listening… tap to stop when you are done' : 'Tap the microphone to start',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),

              // Shown only if the microphone permission was refused
              if (_permissionDenied) _PermissionMessage(onTryAgain: _startRecording),
            ],
          ),
        ),
      ),
    );
  }
}

/// Explains what to do when the microphone permission was refused.
class _PermissionMessage extends StatelessWidget {
  final VoidCallback onTryAgain;

  const _PermissionMessage({required this.onTryAgain});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: colors.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.mic_off, color: colors.onErrorContainer),
                const SizedBox(width: 8),
                Text('Microphone access needed',
                    style: TextStyle(fontWeight: FontWeight.bold, color: colors.onErrorContainer)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Your coach needs the microphone to hear you. Please allow it:\n'
              '• Android: Settings → Apps → English Coach → Permissions → Microphone → Allow\n'
              '• iPhone: Settings → English Coach → Microphone → turn on\n'
              'Then come back and tap "Try again".',
              style: TextStyle(color: colors.onErrorContainer),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: onTryAgain, child: const Text('Try again')),
            ),
          ],
        ),
      ),
    );
  }
}
