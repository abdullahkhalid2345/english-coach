// These classes turn the JSON from the backend's POST /analyze into Dart
// objects, so the screens can write `result.grammarScore` instead of
// `json['grammar_score']`.

/// One grammar mistake that Claude found.
class Correction {
  final String original;
  final String corrected;
  final String explanation;

  Correction({required this.original, required this.corrected, required this.explanation});

  factory Correction.fromJson(Map<String, dynamic> json) {
    return Correction(
      original: json['original'] as String? ?? '',
      corrected: json['corrected'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
    );
  }
}

/// One word, with how well it was pronounced (from Azure).
class WordScore {
  final String word;
  final double accuracyScore;

  /// "None" means no problem. Others: "Mispronunciation", "Omission"
  /// (skipped), "Insertion" (extra word), "UnexpectedBreak", "MissingBreak",
  /// "Monotone".
  final String errorType;

  WordScore({required this.word, required this.accuracyScore, required this.errorType});

  bool get wasSkipped => errorType == 'Omission';

  factory WordScore.fromJson(Map<String, dynamic> json) {
    return WordScore(
      word: json['word'] as String? ?? '',
      accuracyScore: _toDouble(json['accuracy_score']),
      errorType: json['error_type'] as String? ?? 'None',
    );
  }
}

/// The pronunciation scores (from Azure).
class PronunciationResult {
  final double accuracyScore;
  final double fluencyScore;
  final double completenessScore;
  final double? prosodyScore; // can be missing
  final double overallScore;
  final List<WordScore> words;
  final List<WordScore> difficultWords;

  PronunciationResult({
    required this.accuracyScore,
    required this.fluencyScore,
    required this.completenessScore,
    required this.prosodyScore,
    required this.overallScore,
    required this.words,
    required this.difficultWords,
  });

  factory PronunciationResult.fromJson(Map<String, dynamic> json) {
    return PronunciationResult(
      accuracyScore: _toDouble(json['accuracy_score']),
      fluencyScore: _toDouble(json['fluency_score']),
      completenessScore: _toDouble(json['completeness_score']),
      prosodyScore: json['prosody_score'] == null ? null : _toDouble(json['prosody_score']),
      overallScore: _toDouble(json['overall_score']),
      words: _list(json['words']).map(WordScore.fromJson).toList(),
      difficultWords: _list(json['difficult_words']).map(WordScore.fromJson).toList(),
    );
  }
}

/// Everything the backend sends back for one recording.
class AnalysisResult {
  final String transcript;
  final double? durationSeconds;
  final List<Correction> corrections;
  final String betterVersion;
  final int fillerWords;
  final int grammarScore;
  final List<String> tips;

  /// null if pronunciation scoring didn't work. Then [pronunciationError] says why.
  final PronunciationResult? pronunciation;
  final String? pronunciationError;

  AnalysisResult({
    required this.transcript,
    required this.durationSeconds,
    required this.corrections,
    required this.betterVersion,
    required this.fillerWords,
    required this.grammarScore,
    required this.tips,
    required this.pronunciation,
    required this.pronunciationError,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    final pronunciationJson = json['pronunciation'];
    return AnalysisResult(
      transcript: json['transcript'] as String? ?? '',
      durationSeconds: json['duration_seconds'] == null ? null : _toDouble(json['duration_seconds']),
      corrections: _list(json['corrections']).map(Correction.fromJson).toList(),
      betterVersion: json['better_version'] as String? ?? '',
      fillerWords: _toDouble(json['filler_words']).round(),
      grammarScore: _toDouble(json['grammar_score']).round(),
      tips: (json['tips'] as List<dynamic>? ?? []).map((tip) => tip.toString()).toList(),
      pronunciation: pronunciationJson is Map<String, dynamic>
          ? PronunciationResult.fromJson(pronunciationJson)
          : null,
      pronunciationError: json['pronunciation_error'] as String?,
    );
  }
}

// Small helpers so a missing or oddly typed value doesn't crash the app.
double _toDouble(Object? value) => value is num ? value.toDouble() : 0;

List<Map<String, dynamic>> _list(Object? value) =>
    (value as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
