// Automatic checks for the app. Run them with:  flutter test

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:english_coach/main.dart';
import 'package:english_coach/models/analysis_result.dart';
import 'package:english_coach/screens/results_screen.dart';
import 'package:english_coach/services/coach_api.dart';
import 'package:english_coach/topics.dart';
import 'package:english_coach/widgets/score_colors.dart';

/// An example answer, shaped exactly like the backend's POST /analyze reply.
final Map<String, dynamic> sampleJson = {
  'transcript': 'Um, yesterday I go to the market.',
  'duration_seconds': 3.8,
  'corrections': [
    {'original': 'I go', 'corrected': 'I went', 'explanation': 'Use the past tense for yesterday.'},
  ],
  'better_version': 'Yesterday I went to the market.',
  'filler_words': 1,
  'grammar_score': 72,
  'tips': ['Check your verb tenses.', 'Pause instead of saying um.'],
  'pronunciation': {
    'accuracy_score': 84.2,
    'fluency_score': 58.0,
    'completeness_score': 100.0,
    'prosody_score': 71.5,
    'overall_score': 81.0,
    'words': [
      {'word': 'Um', 'accuracy_score': 90, 'error_type': 'None'},
      {'word': 'market', 'accuracy_score': 55, 'error_type': 'Mispronunciation'},
    ],
    'difficult_words': [
      {'word': 'market', 'accuracy_score': 55, 'error_type': 'Mispronunciation'},
    ],
  },
  'pronunciation_error': null,
};

/// A pretend backend, so tests don't need a real server.
class FakeCoachApi extends CoachApi {
  final List<Object> answers; // an AnalysisResult or a CoachApiException, in order
  int calls = 0;

  FakeCoachApi(this.answers);

  @override
  Future<AnalysisResult> analyze(String audioFilePath) async {
    final answer = answers[calls++];
    if (answer is CoachApiException) throw answer;
    return answer as AnalysisResult;
  }
}

Widget wrap(Widget screen) => MaterialApp(home: screen);

void main() {
  testWidgets('Home screen shows a greeting, a topic and the start button', (tester) async {
    await tester.pumpWidget(const EnglishCoachApp());

    expect(find.textContaining('Good'), findsOneWidget);
    expect(find.text("TODAY'S TOPIC"), findsOneWidget);
    expect(find.text('Start speaking'), findsOneWidget);
    expect(speakingTopics.where((topic) => find.text(topic).evaluate().isNotEmpty), hasLength(1));
  });

  test('There are 30 different topics', () {
    expect(speakingTopics.toSet(), hasLength(30));
  });

  test('Score colours: green 80+, orange 60-79, red below 60', () {
    expect(scoreColor(80), scoreColor(100));
    expect(scoreColor(79), scoreColor(60));
    expect(scoreColor(59), scoreColor(0));
    expect(scoreColor(80), isNot(scoreColor(79)));
    expect(scoreColor(60), isNot(scoreColor(59)));
  });

  test('Backend JSON is read correctly, including missing pronunciation', () {
    final result = AnalysisResult.fromJson(sampleJson);
    expect(result.grammarScore, 72);
    expect(result.corrections.single.corrected, 'I went');
    expect(result.pronunciation!.overallScore, 81.0);
    expect(result.pronunciation!.difficultWords.single.word, 'market');

    final withoutAzure = AnalysisResult.fromJson({
      ...sampleJson,
      'pronunciation': null,
      'pronunciation_error': 'Pronunciation scoring is turned off.',
    });
    expect(withoutAzure.pronunciation, isNull);
    expect(withoutAzure.pronunciationError, contains('turned off'));
  });

  testWidgets('Results screen shows the loading message, then the feedback', (tester) async {
    // Use a tall pretend screen so the whole feedback page fits without scrolling.
    tester.view.physicalSize = const Size(1080, 6000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);

    final api = FakeCoachApi([AnalysisResult.fromJson(sampleJson)]);
    await tester.pumpWidget(wrap(ResultsScreen(topic: 'Describe your weekend', audioPath: 'x.m4a', api: api)));

    expect(find.text('Your coach is listening...'), findsOneWidget);
    await tester.pumpAndSettle();

    expect(find.text('Grammar'), findsOneWidget);
    expect(find.text('72'), findsOneWidget);
    expect(find.text('Pronunciation'), findsOneWidget);
    expect(find.text('81'), findsOneWidget);
    expect(find.text('Fluency'), findsOneWidget);
    expect(find.text('What you said'), findsOneWidget);
    expect(find.text('I go'), findsOneWidget);
    expect(find.text('I went'), findsOneWidget);
    expect(find.text('Yesterday I went to the market.'), findsOneWidget);

    expect(find.textContaining('1 filler word '), findsOneWidget);
    expect(find.text('Check your verb tenses.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('Results screen shows a friendly error with Retry, and Retry works', (tester) async {
    final api = FakeCoachApi([
      CoachApiException("Can't reach your coach."),
      AnalysisResult.fromJson(sampleJson),
    ]);
    await tester.pumpWidget(wrap(ResultsScreen(topic: 'Explain your job', audioPath: 'x.m4a', api: api)));
    await tester.pumpAndSettle();

    expect(find.text("Can't reach your coach."), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(api.calls, 2);
    expect(find.text('What you said'), findsOneWidget);
  });

  testWidgets('Without pronunciation scores, the reason is shown', (tester) async {
    final api = FakeCoachApi([
      AnalysisResult.fromJson({...sampleJson, 'pronunciation': null, 'pronunciation_error': 'Azure is not set up.'}),
    ]);
    await tester.pumpWidget(wrap(ResultsScreen(topic: 'Explain your job', audioPath: 'x.m4a', api: api)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Azure is not set up.'), findsOneWidget);
    expect(find.text('Not available'), findsNWidgets(2));
  });
}
