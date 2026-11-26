import 'package:material_ui/material_ui.dart';

import 'screens/home_screen.dart';

// This is where the app starts.
void main() {
  runApp(const EnglishCoachApp());
}

class EnglishCoachApp extends StatelessWidget {
  const EnglishCoachApp({super.key});

  // A calm teal colour. Material 3 builds the whole colour palette from it.
  // Change this one colour to restyle the whole app.
  static const Color seedColor = Color(0xFF3D7A78);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'English Coach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seedColor, brightness: Brightness.dark),
      ),
      home: const HomeScreen(),
    );
  }
}
