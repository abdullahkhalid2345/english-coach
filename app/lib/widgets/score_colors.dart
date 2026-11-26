import 'package:material_ui/material_ui.dart';

/// The colour for a score: green for 80 and above, orange for 60–79, red below 60.
Color scoreColor(num score) {
  if (score >= 80) return const Color(0xFF2E7D32); // green
  if (score >= 60) return const Color(0xFFEF6C00); // orange
  return const Color(0xFFC62828); // red
}

/// A short word to go with the score, e.g. "Great".
String scoreLabel(num score) {
  if (score >= 80) return 'Great';
  if (score >= 60) return 'Good';
  return 'Keep practising';
}
