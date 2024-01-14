import 'package:flutter/material.dart';
import 'package:peephole/app.dart';
import 'package:peephole/cameras.dart';

Future<void> main() async {
  // inits
  WidgetsFlutterBinding.ensureInitialized();
  await Cameras.init();

  // start app
  runApp(MaterialApp(
    home: App(),
    darkTheme: ThemeData(
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: Colors.white),
      ),
    ),
    themeMode: ThemeMode.dark,
  ));
}
