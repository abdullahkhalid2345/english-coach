import 'package:material_ui/material_ui.dart';

import '../models/analysis_result.dart';
import 'score_colors.dart';

/// Shows what the student said, with every word coloured by its
/// pronunciation score (green / orange / red). Skipped words are shown
/// crossed out in grey.
///
/// If there are no pronunciation scores, it shows the plain transcript.
class ColoredTranscript extends StatelessWidget {
  final String transcript;
  final List<WordScore> words;

  const ColoredTranscript({super.key, required this.transcript, required this.words});

  @override
  Widget build(BuildContext context) {
    final baseStyle = Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6);

    if (words.isEmpty) {
      return Text(transcript, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          for (final word in words)
            TextSpan(
              text: '${word.word} ',
              style: word.wasSkipped
                  ? const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)
                  : TextStyle(color: scoreColor(word.accuracyScore), fontWeight: FontWeight.w600),
            ),
        ],
      ),
    );
  }
}
