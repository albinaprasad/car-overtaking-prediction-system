import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'home_screen.dart';
import 'overspeed/overspeed_screen.dart';
import 'pages/map_page.dart';
import 'pages/3d_map_screen.dart';
import 'admin_dashboard.dart';
import 'admin_login.dart'; // Add this line
// Import Admin Dashboard

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

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
        primaryColor: Color(0xFF0E74E7),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF0E74E7),
          primary: Color(0xFF0E74E7),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => AdminLoginScreen(),
        '/home': (context) => HomeScreen(cameras: cameras),
        '/overspeed': (context) => OverspeedLauncherScreen(cameras: cameras),
        '/overtaking': (context) =>
            VehicleTrackingScreen(vehicleId: 'vehicle2'),
        '/map3d': (context) => const ThreeDMapScreen(),
        '/admin': (context) => AdminDashboard(), // Removed `const`
      },
    );
  }
}
