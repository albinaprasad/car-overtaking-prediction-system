import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Firebase imports
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

class OverspeedLauncherScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  final String userId; // User ID from authentication
  final String vehicleNumber; // Vehicle registration number

  const OverspeedLauncherScreen({
    Key? key,
    required this.cameras,
    required this.userId,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  State<OverspeedLauncherScreen> createState() =>
      _OverspeedLauncherScreenState();
}

class _OverspeedLauncherScreenState extends State<OverspeedLauncherScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  Timer? _detectionTimer;
  List<Map<String, dynamic>> _detections = [];
  bool _isProcessing = false;

  // Vehicle speed from geolocation.
  double? _currentSpeedKmh;
  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;

  // Detected speed limit from the sign (e.g., 50 km/h).
  double? _activeSpeedLimit;

  // Location where the last sign was detected.
  Position? _lastSignPosition;

  // Audio player to play the warning sound.
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _hasPlayedWarning = false;

  // Holds the status of audio playback for display in the UI.
  String _audioStatus = '';

  // Alert voice selection.
  final List<String> _alertVoices = [
    'voice1.mp3',
    'voice2.mp3',
    'voice3.mp3',
  ];
  String _selectedVoice = 'voice1.mp3'; // default voice

  // Firebase database reference.
  late DatabaseReference _overspeedRef;

  // Overspeed tracking variables.
  bool _isCurrentlyOverspeeding = false;
  DateTime? _overspeedStartTime;
  double _maxSpeedReached = 0.0;
  String? _currentOverspeedId;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeLocationListener();
    _loadSelectedVoice();
    _initializeFirebase();
  }

  // Initialize Firebase and create a database reference using the userId.
  void _initializeFirebase() {
    _overspeedRef = FirebaseDatabase.instance
        .ref()
        .child('overspeed_events')
        .child(widget.userId);
  }

  Future<void> _initializeCamera() async {
    _controller = CameraController(
      widget.cameras.first,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
    await _initializeControllerFuture;
    if (mounted) {
      setState(() {});
      _startDetectionTimer();
    }
  }

  // Capture an image periodically to send to the detection server.
  void _startDetectionTimer() {
    _detectionTimer = Timer.periodic(const Duration(seconds: 4), (timer) async {
      if (!_isProcessing) {
        await _processFrame();
      }
    });
  }

  // Listen for location updates to obtain vehicle speed and check distance.
  void _initializeLocationListener() {
    _positionStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((Position position) {
      _currentPosition = position;
      // Convert speed from m/s to km/h.
      double speedKmh = position.speed * 3.6;
      setState(() {
        // For testing, you can set a fixed speed if needed:
        _currentSpeedKmh =
            70; //************************************************************************** */
        // Uncomment the following line to use real speed:
        // _currentSpeedKmh = speedKmh;
      });

      // Check if overspeeding and track the event.
      _checkAndTrackOverspeeding();

      // If we have a stored sign location, calculate the distance.
      if (_activeSpeedLimit != null && _lastSignPosition != null) {
        double distance = Geolocator.distanceBetween(
          _lastSignPosition!.latitude,
          _lastSignPosition!.longitude,
          position.latitude,
          position.longitude,
        );
        // If more than 1 km has been traveled, clear the stored speed limit.
        if (distance >= 1000) {
          setState(() {
            _activeSpeedLimit = null;
            _lastSignPosition = null;
          });
        }
      }
    });
  }

  // Check if user is overspeeding and track the event.
  void _checkAndTrackOverspeeding() {
    if (_currentSpeedKmh != null &&
        _activeSpeedLimit != null &&
        _currentPosition != null) {
      bool isOverspeed = _currentSpeedKmh! > _activeSpeedLimit!;

      if (isOverspeed && !_isCurrentlyOverspeeding) {
        _startOverspeedTracking();
      } else if (isOverspeed && _isCurrentlyOverspeeding) {
        _updateOverspeedTracking();
      } else if (!isOverspeed && _isCurrentlyOverspeeding) {
        _endOverspeedTracking();
      }
    }
  }

  // Start tracking a new overspeed event.
  void _startOverspeedTracking() {
    _isCurrentlyOverspeeding = true;
    _overspeedStartTime = DateTime.now();
    _maxSpeedReached = _currentSpeedKmh!;

    // Create a new entry in Firebase with initial data.
    _currentOverspeedId = _overspeedRef.push().key;

    if (_currentOverspeedId != null) {
      _overspeedRef.child(_currentOverspeedId!).set({
        'startTimestamp': _overspeedStartTime!.millisecondsSinceEpoch,
        'vehicleNumber': widget.vehicleNumber,
        'startSpeed': _currentSpeedKmh,
        'speedLimit': _activeSpeedLimit,
        'startLatitude': _currentPosition!.latitude,
        'startLongitude': _currentPosition!.longitude,
        'maxSpeed': _currentSpeedKmh,
        'status': 'ongoing'
      });
    }
  }

  // Update the ongoing overspeed event.
  void _updateOverspeedTracking() {
    if (_currentSpeedKmh! > _maxSpeedReached) {
      _maxSpeedReached = _currentSpeedKmh!;
      if (_currentOverspeedId != null) {
        _overspeedRef
            .child(_currentOverspeedId!)
            .update({'maxSpeed': _maxSpeedReached});
      }
    }
  }

  // End the overspeed tracking and update final details.
  void _endOverspeedTracking() {
    if (_overspeedStartTime != null && _currentOverspeedId != null) {
      DateTime endTime = DateTime.now();
      Duration duration = endTime.difference(_overspeedStartTime!);

      _overspeedRef.child(_currentOverspeedId!).update({
        'endTimestamp': endTime.millisecondsSinceEpoch,
        'durationSeconds': duration.inSeconds,
        'endLatitude': _currentPosition!.latitude,
        'endLongitude': _currentPosition!.longitude,
        'maxSpeed': _maxSpeedReached,
        'status': 'completed'
      });

      // Reset tracking variables.
      _isCurrentlyOverspeeding = false;
      _overspeedStartTime = null;
      _currentOverspeedId = null;
      _maxSpeedReached = 0.0;
    }
  }

  // Capture a frame, send it to the detection server, and process the response.
  Future<void> _processFrame() async {
    if (!_controller.value.isInitialized) return;
    try {
      setState(() => _isProcessing = true);
      final image = await _controller.takePicture();

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(
            'http://192.168.237.58:5000/detect'), // Update with your server URL.
      );
      request.files.add(await http.MultipartFile.fromPath('image', image.path));
      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        setState(() {
          _detections = List<Map<String, dynamic>>.from(
            (json.decode(responseData)['detections'] as List)
                .map((x) => Map<String, dynamic>.from(x)),
          );
        });
        _processDetections();
      }
      await File(image.path).delete();
    } catch (e) {
      // Optionally handle error.
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  // Process detections to update active speed limit if a valid speed sign is detected.
  void _processDetections() {
    for (var detection in _detections) {
      String detectionClass = detection['class'].toString();
      String lowerCaseClass = detectionClass.toLowerCase();
      if (lowerCaseClass.contains('speed limit')) {
        RegExp regExp = RegExp(r'\d+');
        Match? match = regExp.firstMatch(detectionClass);
        if (match != null) {
          double? detectedSpeed = double.tryParse(match.group(0)!);
          if (detectedSpeed != null) {
            setState(() {
              _activeSpeedLimit = detectedSpeed;
              if (_currentPosition != null) {
                _lastSignPosition = _currentPosition;
              }
            });
            break;
          }
        }
      }
    }
  }

  // Play the warning audio using the selected voice.
  Future<void> _playWarningAudio() async {
    try {
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('audio/$_selectedVoice'));
      setState(() {
        _audioStatus =
            "Playing alert: ${_selectedVoice.replaceAll('.mp3', '')}";
      });
    } catch (e) {
      setState(() {
        _audioStatus = "Error playing audio: $e";
      });
    }
  }

  // Load the selected voice from SharedPreferences.
  Future<void> _loadSelectedVoice() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedVoice = prefs.getString('selected_voice') ?? 'voice1.mp3';
    });
  }

  // Save the selected voice to SharedPreferences.
  Future<void> _saveSelectedVoice(String newVoice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_voice', newVoice);
    setState(() {
      _selectedVoice = newVoice;
    });
  }

  // Build the dropdown for selecting alert voices.
  Widget _buildVoiceSelector() {
    return DropdownButton<String>(
      value: _selectedVoice,
      items: _alertVoices.map((String voice) {
        return DropdownMenuItem<String>(
          value: voice,
          child: Text(voice.replaceAll('.mp3', '').toUpperCase()),
        );
      }).toList(),
      onChanged: (String? newValue) {
        if (newValue != null) {
          _saveSelectedVoice(newValue);
        }
      },
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _controller.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    bool isOverspeed = _currentSpeedKmh != null &&
        _activeSpeedLimit != null &&
        _currentSpeedKmh! > _activeSpeedLimit!;

    // Use a post-frame callback to trigger the warning audio if overspeeding.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (isOverspeed && !_hasPlayedWarning) {
        _playWarningAudio();
        _hasPlayedWarning = true;
      } else if (!isOverspeed) {
        _hasPlayedWarning = false;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Overspeed Detection')),
      body: Stack(
        children: [
          CameraPreview(_controller),
          // Overlay for speed data, warnings, and voice selection.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: const Color.fromARGB(137, 87, 35, 35),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Vehicle Speed: ${_currentSpeedKmh?.toStringAsFixed(1) ?? '--'} km/h',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeSpeedLimit != null
                        ? 'Detected Speed Limit: ${_activeSpeedLimit!.toStringAsFixed(0)} km/h'
                        : 'No Speed Limit Detected',
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 8),
                  if (isOverspeed)
                    Container(
                      padding: const EdgeInsets.all(8),
                      color: Colors.red,
                      child: const Text(
                        'WARNING: Overspeeding!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // Voice selection dropdown.
                  _buildVoiceSelector(),
                  const SizedBox(height: 8),
                  // Display audio playback status.
                  Text(
                    _audioStatus,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  // Display vehicle number.
                  const SizedBox(height: 8),
                  Text(
                    'Vehicle: ${widget.vehicleNumber}',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
          if (_isProcessing)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
