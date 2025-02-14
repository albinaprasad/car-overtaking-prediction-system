import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'overspeed/overspeed_screen.dart';

class HomeScreen extends StatelessWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Extend the background behind the AppBar.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: const Color(0xFFE2725B), // Terracotta red
        elevation: 0,
        title: const Text(
          "Safety App",
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE2725B), // Terracotta red
              Color(0xFFF5F5DC), // Light beige
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          // Animate opacity and slide effect on load.
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  // Slide in effect: move 30px upward as it fades in.
                  offset: Offset(0, (1 - value) * 30),
                  child: child,
                ),
              );
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                AnimatedMenuButton(
                  text: "Overspeed Detection",
                  route: '/overspeed',
                ),
                SizedBox(height: 20),
                AnimatedMenuButton(
                  text: "Overtaking",
                  route: '/overtaking',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedMenuButton extends StatefulWidget {
  final String text;
  final String route;

  const AnimatedMenuButton({
    Key? key,
    required this.text,
    required this.route,
  }) : super(key: key);

  @override
  _AnimatedMenuButtonState createState() => _AnimatedMenuButtonState();
}

class _AnimatedMenuButtonState extends State<AnimatedMenuButton> {
  double _scale = 1.0;
  double _rotation = 0.0; // Rotation in turns (1 turn = 360°)

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.95;
      _rotation = -0.01; // Approximately -3.6° rotation.
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _rotation = 0.0;
    });
    // Delay navigation to let the animation complete.
    Future.delayed(const Duration(milliseconds: 150), () {
      Navigator.pushNamed(context, widget.route);
    });
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
      _rotation = 0.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedRotation(
        turns: _rotation,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Card(
            color: const Color(0xFF5F9EA0), // Muted teal
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: SizedBox(
              width: 250,
              height: 80,
              child: Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
