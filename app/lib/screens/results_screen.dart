import 'package:material_ui/material_ui.dart';

import '../models/analysis_result.dart';
import '../services/coach_api.dart';
import '../widgets/colored_transcript.dart';
import '../widgets/score_card.dart';
import '../widgets/score_colors.dart';
import 'recording_screen.dart';

/// Screen 3: uploads the recording, waits for the coach, and shows the feedback.
class ResultsScreen extends StatefulWidget {
  final String topic;
  final String audioPath;

  /// Normally left empty. Tests can pass a pretend API here.
  final CoachApi? api;

  const ResultsScreen({super.key, required this.topic, required this.audioPath, this.api});

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late final CoachApi _api = widget.api ?? CoachApi();

  // Exactly one of these three situations is shown at a time:
  bool _loading = true; // 1. waiting for the coach
  String? _error; // 2. something went wrong
  AnalysisResult? _result; // 3. we have feedback

  @override
  void initState() {
    super.initState();
    _upload();
  }

  /// Send the recording to the backend. Also used by the "Retry" button.
  Future<void> _upload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _api.analyze(widget.audioPath);
      if (!mounted) return;
      setState(() {
        _result = result;
        _loading = false;
      });
    } on CoachApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      // Anything unexpected: still show a friendly message instead of crashing.
      if (!mounted) return;
      setState(() {
        _error = 'Something unexpected went wrong. Please try again.';
        _loading = false;
      });
    }
  }

  /// Go back to the recording screen with the same topic.
  void _tryAgain() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => RecordingScreen(topic: widget.topic)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_loading) {
      body = const _LoadingView();
    } else if (_error != null) {
      body = _ErrorView(message: _error!, onRetry: _upload, onRecordAgain: _tryAgain);
    } else {
      body = _FeedbackView(result: _result!, topic: widget.topic, onTryAgain: _tryAgain);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your feedback')),
      body: SafeArea(child: body),
    );
  }
}

// -----------------------------------------------------------------------------
// 1. Loading
// -----------------------------------------------------------------------------

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 56, height: 56, child: CircularProgressIndicator(strokeWidth: 5)),
          const SizedBox(height: 24),
          Text('Your coach is listening...', style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            'This usually takes 10–30 seconds.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. Error
// -----------------------------------------------------------------------------

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onRecordAgain;

  const _ErrorView({required this.message, required this.onRetry, required this.onRecordAgain});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text('Oops, something went wrong', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(message, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
            const SizedBox(height: 8),
            TextButton(onPressed: onRecordAgain, child: const Text('Record again')),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. Feedback
// -----------------------------------------------------------------------------

class _FeedbackView extends StatelessWidget {
  final AnalysisResult result;
  final String topic;
  final VoidCallback onTryAgain;

  const _FeedbackView({required this.result, required this.topic, required this.onTryAgain});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pronunciation = result.pronunciation;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(topic, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),

        // --- Score cards -----------------------------------------------------
        Row(
          children: [
            Expanded(child: ScoreCard(title: 'Grammar', score: result.grammarScore, icon: Icons.spellcheck)),
            const SizedBox(width: 8),
            Expanded(
              child: ScoreCard(
                  title: 'Pronunciation', score: pronunciation?.overallScore, icon: Icons.record_voice_over),
            ),
            const SizedBox(width: 8),
            Expanded(child: ScoreCard(title: 'Fluency', score: pronunciation?.fluencyScore, icon: Icons.waves)),
          ],
        ),
        if (pronunciation == null && result.pronunciationError != null) ...[
          const SizedBox(height: 8),
          _InfoBanner(text: 'No pronunciation scores this time: ${result.pronunciationError}'),
        ],

        // --- What you said ---------------------------------------------------
        _Section(
          title: 'What you said',
          icon: Icons.chat_bubble_outline,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ColoredTranscript(transcript: result.transcript, words: pronunciation?.words ?? []),
              if (pronunciation != null) ...[
                const SizedBox(height: 12),
                const _ColorLegend(),
              ],
              if (pronunciation != null && pronunciation.difficultWords.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Words to practise', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final word in pronunciation.difficultWords)
                      Chip(
                        label: Text('${word.word}  ${word.accuracyScore.round()}'),
                        side: BorderSide(color: scoreColor(word.accuracyScore)),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // --- Corrections -----------------------------------------------------
        _Section(
          title: 'Corrections',
          icon: Icons.edit_note,
          child: result.corrections.isEmpty
              ? const Text('No grammar mistakes found. Well done! 🎉')
              : Column(
                  children: [
                    for (final correction in result.corrections) _CorrectionTile(correction: correction),
                  ],
                ),
        ),

        // --- Say it better ---------------------------------------------------
        _Section(
          title: 'Say it better',
          icon: Icons.auto_awesome,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              result.betterVersion,
              style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer, height: 1.5),
            ),
          ),
        ),

        // --- Filler words ----------------------------------------------------
        _Section(
          title: 'Filler words',
          icon: Icons.hearing,
          child: Text(
            result.fillerWords == 0
                ? 'You used no filler words like "um" or "like". Excellent!'
                : 'You used ${result.fillerWords} filler word${result.fillerWords == 1 ? '' : 's'} '
                    '(like "um", "uh" or "you know"). Try pausing silently instead.',
            style: theme.textTheme.bodyLarge,
          ),
        ),

        // --- Tips ------------------------------------------------------------
        _Section(
          title: 'Tips for next time',
          icon: Icons.lightbulb_outline,
          child: Column(
            children: [
              for (final tip in result.tips)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.check_circle_outline, color: theme.colorScheme.primary),
                  title: Text(tip),
                ),
            ],
          ),
        ),

        // --- Buttons ---------------------------------------------------------
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onTryAgain,
          icon: const Icon(Icons.mic),
          label: const Text('Try again'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
          child: const Text('Back to home'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Small building blocks used above
// -----------------------------------------------------------------------------

/// A titled white card used for each part of the feedback.
class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _Section({required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// One grammar correction: what was said (crossed out), the fix, and why.
class _CorrectionTile extends StatelessWidget {
  final Correction correction;

  const _CorrectionTile({required this.correction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            correction.original,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: scoreColor(0),
              decoration: TextDecoration.lineThrough,
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.arrow_forward, size: 18, color: scoreColor(100)),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  correction.corrected,
                  style: theme.textTheme.bodyLarge?.copyWith(color: scoreColor(100), fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            correction.explanation,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Explains the word colours.
class _ColorLegend extends StatelessWidget {
  const _ColorLegend();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall;
    Widget dot(Color color, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 10, color: color),
            const SizedBox(width: 4),
            Text(label, style: style),
          ],
        );
    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: [
        dot(scoreColor(100), 'Clear (80+)'),
        dot(scoreColor(70), 'Okay (60–79)'),
        dot(scoreColor(0), 'Needs practice'),
        dot(Colors.grey, 'Skipped'),
      ],
    );
  }
}

/// A small grey note, e.g. why there are no pronunciation scores.
class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
