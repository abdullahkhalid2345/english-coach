import 'dart:math';

/// Speaking topics. One is picked at random on the home screen.
/// Add, remove or change topics here as you like.
const List<String> speakingTopics = [
  // Everyday life
  'Introduce yourself',
  'Describe your weekend',
  'Talk about your favourite food',
  'Describe your home town',
  'Talk about a hobby you enjoy',
  'Describe your morning routine',
  'Talk about a film or series you watched recently',
  'Describe a place you would like to visit',
  'Talk about your best friend',
  'Describe your favourite season and why',
  'Talk about a book you enjoyed',
  'Describe a memorable trip',
  'Talk about how you like to relax',
  'Describe a typical meal in your country',
  'Talk about a skill you want to learn',
  // Work
  'Explain your job',
  'Describe a typical day at work',
  'Talk about a project you are proud of',
  'Describe your ideal workplace',
  'Explain a problem you solved at work',
  'Introduce yourself in a job interview',
  'Describe your team and your role in it',
  'Talk about your career goals',
  'Explain how you manage your time',
  'Describe a challenge you faced at work',
  'Give a short update on what you worked on this week',
  'Explain something you know well to a new colleague',
  'Talk about a person who inspired you at work',
  'Describe how you prepare for an important meeting',
  'Talk about the pros and cons of working from home',
];

/// Returns one random topic from the list.
String randomTopic() {
  return speakingTopics[Random().nextInt(speakingTopics.length)];
}
