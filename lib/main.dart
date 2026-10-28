import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:smart_health_monitor/pages/bmi/bmiCalculator.dart';
import 'package:smart_health_monitor/pages/diagnose/choose.dart';
import 'package:smart_health_monitor/pages/diagnose/heart.dart';
import 'package:smart_health_monitor/pages/diagnose/lung.dart';
import 'package:smart_health_monitor/pages/diagnose/result.dart';
import 'package:smart_health_monitor/pages/home.dart';
import 'package:smart_health_monitor/l10n/app_localizations.dart';
import 'package:smart_health_monitor/pages/lifestyle/choose.dart';
import 'package:smart_health_monitor/pages/lifestyle/meal/choose.dart';
import 'package:smart_health_monitor/pages/lifestyle/meal/display.dart';
import 'package:smart_health_monitor/pages/lifestyle/workout/choose.dart';
import 'package:smart_health_monitor/pages/lifestyle/workout/display.dart';
import 'package:smart_health_monitor/pages/sidebar/About.dart';
import 'package:smart_health_monitor/pages/sidebar/Login.dart';
import 'package:smart_health_monitor/pages/storage/audioPlayer.dart';
import 'package:smart_health_monitor/pages/storage/storage.dart';

void main() {
  runApp(const MyApp());
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final currentLocale = const String.fromEnvironment("LANG");

    return MaterialApp(
      title: 'SORA',

      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: [Locale(currentLocale)],

      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 25)
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ButtonStyle(
            padding: WidgetStateProperty.all(
              EdgeInsets.symmetric(vertical: 10, horizontal: 32),
            ),
            shape: WidgetStateProperty.all(
              RoundedRectangleBorder(
                borderRadius: BorderRadiusGeometry.circular(4.0),
              ),
            ),
          ),
        ), 
      ),
      home: MyHomePage(),
      routes: {
        '/diagnose': (context) => DiagnoseChoose(),
        '/diagnose/lung': (context) => DiagnoseLung(),
        '/diagnose/heart': (context) => DiagnoseHeart(),
        '/diagnose/results': (context) => ResultPage(),
        '/storage': (context) => StorageContainer(),
        '/storage/player': (context) => AudioPlayerPage(),
        '/bmi': (context) => BMICalculator(),
        '/about': (context) => AboutPage(),
        '/lifestyle': (context) => ChooseLifestyle(),
        '/lifestyle/meal': (context) => ChooseMeal(),
        '/lifestyle/meal/display': (context) => MealDisplay(),
        '/lifestyle/workout': (context) => ChooseWorkout(),
        '/lifestyle/workout/display': (context) => WorkoutDisplay(),
        '/login': (context) => Login()
      },
    );
  }
}

