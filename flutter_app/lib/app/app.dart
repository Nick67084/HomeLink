part of '../main.dart';

class HomeLinkApp extends StatelessWidget {
  const HomeLinkApp({super.key});
  @override Widget build(BuildContext context) => MaterialApp(
    title: 'HomeLink', debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, scaffoldBackgroundColor: canvas,
      colorScheme: ColorScheme.fromSeed(seedColor: navy, primary: navy, secondary: ocean, surface: Colors.white),
      appBarTheme: const AppBarTheme(backgroundColor: canvas, foregroundColor: navy, centerTitle: false),
      inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: pale)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: pale))),
      cardTheme: CardThemeData(color: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
    home: const EntryScreen());
}

