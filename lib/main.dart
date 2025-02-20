import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'home_screen.dart';
import 'overspeed/overspeed_screen.dart';
import 'pages/map_page.dart'; // This file contains VehicleTrackingScreen
import 'pages/3d_map_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Load available cameras for overspeed detection.
  final cameras = await availableCameras();

  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // A bright blue primary color. Adjust as needed.
    const primaryBlue = Color(0xFF0E74E7);

    return MaterialApp(
      title: 'Vehicle Tracker',
      theme: ThemeData(
        // Use a single primary color or build a MaterialColor swatch
        primaryColor: primaryBlue,
        // App-wide color scheme (Material 3 style).
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryBlue,
          primary: primaryBlue,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white, // Icon and text color
          centerTitle: true,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => HomeScreen(cameras: cameras),
        '/overspeed': (context) => OverspeedLauncherScreen(cameras: cameras),
        '/overtaking': (context) =>
            VehicleTrackingScreen(vehicleId: 'vehicle2'),
        '/map3d': (context) => const ThreeDMapScreen()
      },
    );
  }
}
