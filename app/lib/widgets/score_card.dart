import 'package:material_ui/material_ui.dart';

import 'score_colors.dart';

/// A card showing one score, e.g. "Grammar 85", coloured by how good it is.
/// If [score] is null (not available), it shows a dash.
class ScoreCard extends StatelessWidget {
  final String title;
  final num? score;
  final IconData icon;

  const ScoreCard({super.key, required this.title, required this.score, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = score == null ? theme.colorScheme.outline : scoreColor(score!);

    return Card(
      elevation: 0,
      color: color.withValues(alpha: 0.10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(
              score == null ? '–' : score!.round().toString(),
              style: theme.textTheme.headlineMedium?.copyWith(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(title, style: theme.textTheme.labelLarge, textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(
              score == null ? 'Not available' : scoreLabel(score!),
              style: theme.textTheme.labelSmall?.copyWith(color: color),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
