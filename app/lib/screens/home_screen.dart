import 'package:material_ui/material_ui.dart';

import '../topics.dart';
import 'recording_screen.dart';

/// Screen 1: a greeting, today's topic and a big "Start speaking" button.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // The topic shown on screen. Picked at random when the app opens.
  String _topic = randomTopic();

  /// "Good morning", "Good afternoon" or "Good evening", depending on the time.
  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 18) return 'Good afternoon!';
    return 'Good evening!';
  }

  /// Pick a different random topic.
  void _newTopic() {
    setState(() {
      String next = randomTopic();
      while (next == _topic) {
        next = randomTopic();
      }
      _topic = next;
    });
  }

  void _startSpeaking() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecordingScreen(topic: _topic)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              Text(_greeting(), style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                "Ready to practise your English? Speak for a minute or two and your coach "
                "will help you sound more natural.",
                style: theme.textTheme.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
              ),
              const Spacer(),

              // Today's topic
              Card(
                elevation: 0,
                color: colors.primaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Text("TODAY'S TOPIC",
                          style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onPrimaryContainer, letterSpacing: 1.2)),
                      const SizedBox(height: 12),
                      Text(
                        _topic,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(color: colors.onPrimaryContainer),
                      ),
                      const SizedBox(height: 12),
                      TextButton.icon(
                        onPressed: _newTopic,
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Different topic'),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),

              // The big button
              FilledButton.icon(
                onPressed: _startSpeaking,
                icon: const Icon(Icons.mic, size: 28),
                label: const Text('Start speaking'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  textStyle: theme.textTheme.titleLarge,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
