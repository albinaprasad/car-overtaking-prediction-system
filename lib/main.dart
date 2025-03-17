import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:camera/camera.dart';
import 'home_screen.dart';
import 'overspeed/overspeed_screen.dart';
import 'pages/map_page.dart';
import 'pages/3d_map_screen.dart';
import 'admin_dashboard.dart';
import 'integrated_auth_screen.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0E74E7),
          primary: const Color(0xFF0E74E7),
        ),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: '/auth',
      routes: {
        '/auth': (context) => const IntegratedAuthScreen(),
        '/home': (context) => HomeScreen(cameras: cameras),
        // For overspeed, we pass the arguments using onGenerateRoute.
        '/overtaking': (context) =>
            VehicleTrackingScreen(vehicleId: 'vehicle2'),
        '/map3d': (context) => const ThreeDMapScreen(),
        '/admin': (context) => AdminDashboard(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == '/overspeed') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => OverspeedLauncherScreen(
              cameras: args['cameras'],
              userId: args['userId'],
              vehicleNumber: args['vehicleNumber'],
            ),
          );
        }
        return null;
      },
    );
  }
}
