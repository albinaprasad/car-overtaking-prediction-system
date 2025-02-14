import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'home_screen.dart';
import 'overspeed/overspeed_screen.dart';
import 'pages/map_page.dart'; // This file contains VehicleTrackingScreen

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
    return MaterialApp(
      title: 'Vehicle Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        // Home route: displays navigation buttons.
        '/': (context) => HomeScreen(cameras: cameras),
        // Overspeed route: the sign detection screen.
        '/overspeed': (context) => OverspeedLauncherScreen(cameras: cameras),
        // Overtaking route: your actual overtaking screen implemented in map_page.dart.
        '/overtaking': (context) =>
            VehicleTrackingScreen(vehicleId: 'vehicle3'),
      },
    );
  }
}
