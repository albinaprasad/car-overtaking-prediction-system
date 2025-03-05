import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class VehicleTrackingScreen extends StatefulWidget {
  final String vehicleId; // For example, "vehicle3" for the current user

  const VehicleTrackingScreen({
    Key? key,
    required this.vehicleId,
  }) : super(key: key);

  @override
  _VehicleTrackingScreenState createState() => _VehicleTrackingScreenState();
}

class _VehicleTrackingScreenState extends State<VehicleTrackingScreen> {
  final DatabaseReference _vehiclesRef =
      FirebaseDatabase.instance.ref().child("vehicles");

  Map<String, VehicleData> _allVehicles = {};
  LatLng _currentPosition = LatLng(9.6058813, 76.4819121);
  double _currentSpeed = 0.0;
  double _currentHeading = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _overtakingUnsafe = false;

  // For release version, test mode is off.
  // Set _testMode to true to enable the override button.
  final bool _testMode = true;

  // Flag to block geolocator updates for your vehicle during a speed override period.
  bool _overrideActive = false;

  // User-configurable thresholds (defaults)
  double _speedDiffThreshold = 10.0; // km/h difference required
  double _distanceThreshold = 50.0; // in meters, for slow-vehicle-ahead check
  double _angleThreshold = 180.0; // in degrees (set to 180 for testing)
  double _minimumSpeedForCheck =
      5.0; // km/h, below which overtaking logic is skipped

  // Additional threshold for oncoming vehicles (you can adjust as needed)
  double _distanceThresholdOncoming = 100.0; // in meters

  StreamSubscription<DatabaseEvent>? _firebaseSub;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _staleDataTimer;
  Timer? _firebaseUpdateTimer; // Timer for updating Firebase every few seconds

  static const int STALE_DATA_THRESHOLD = 300000; // 5 minutes

  @override
  void initState() {
    super.initState();
    // In both production and test mode, we initialize tracking.
    _initializeTracking();
  }

  // ----------------------
  // Production Initialization
  // ----------------------
  Future<void> _initializeTracking() async {
    try {
      await _checkAndRequestPermissions();
      await _getInitialLocation();
      _startLocationUpdates();
      _listenToAllVehicles();
      _startStaleDataCheck();
      _startFirebaseUpdateTimer();
      print("Debug: Production initialization complete.");
    } catch (e) {
      print("Debug: Initialization error: $e");
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('Location services are disabled');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        throw Exception('Location permission denied');
      }
    }
    print("Debug: Location permissions granted.");
  }

  void _startStaleDataCheck() {
    _staleDataTimer?.cancel();
    _staleDataTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      final now = DateTime.now().millisecondsSinceEpoch;
      _allVehicles.removeWhere((key, value) {
        final isStale = (now - value.timestamp) > STALE_DATA_THRESHOLD;
        if (isStale) {
          print("Debug: Removing stale data for vehicle: $key");
        }
        return isStale;
      });
      if (mounted) setState(() {});
      _checkOvertakingSafety();
    });
  }

  Future<void> _getInitialLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    if (mounted) {
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _currentSpeed = (position.speed) * 3.6; // Convert m/s to km/h
        _currentHeading = position.heading;
        _isLoading = false;
      });
      print(
          "Debug: Initial location: $_currentPosition, Speed: $_currentSpeed km/h, Heading: $_currentHeading°");
    }
    await _updateVehicleData();
  }

  void _startLocationUpdates() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      ),
    ).listen(
      (Position position) {
        if (mounted) {
          setState(() {
            _currentPosition = LatLng(position.latitude, position.longitude);
            // Only update speed if override is not active.
            if (!_overrideActive) {
              _currentSpeed = (position.speed) * 3.6;
            }
            _currentHeading = position.heading;
          });
          print(
              "Debug: New location: $_currentPosition, Speed: $_currentSpeed km/h, Heading: $_currentHeading°");
        }
      },
      onError: (error) {
        _showMessage("Location error: $error");
      },
    );
  }

  void _startFirebaseUpdateTimer() {
    _firebaseUpdateTimer?.cancel();
    // Update Firebase every 20 seconds, for example.
    _firebaseUpdateTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      print("Debug: Timer tick - updating Firebase.");
      _updateVehicleData();
    });
  }

  Future<void> _updateVehicleData() async {
    // During an override period, skip geolocator updates for your vehicle.
    if (_overrideActive) {
      print("Override active; skipping geolocator update for my vehicle.");
      return;
    }
    try {
      final vehicleData = {
        "latitude": _currentPosition.latitude,
        "longitude": _currentPosition.longitude,
        "speed": _currentSpeed,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
        "heading": _currentHeading,
      };
      print("Debug: Updating Firebase with: $vehicleData");
      await _vehiclesRef.child(widget.vehicleId).update(vehicleData);
      print("Debug: Firebase update successful.");
    } catch (e) {
      _showMessage("Failed to update vehicle data: $e");
    }
  }

  void _listenToAllVehicles() {
    _firebaseSub = _vehiclesRef.onValue.listen(
      (DatabaseEvent event) {
        if (event.snapshot.value == null) return;
        try {
          final values = event.snapshot.value as Map<dynamic, dynamic>;
          print("Debug: Raw Firebase data: $values");
          final Map<String, VehicleData> updatedVehicles = {};
          final now = DateTime.now().millisecondsSinceEpoch;

          values.forEach((key, value) {
            final vehicleKey = key.toString();
            try {
              final timestamp = value['timestamp'] as int? ?? now;
              if ((now - timestamp) <= STALE_DATA_THRESHOLD) {
                final lat = double.parse(value['latitude'].toString());
                final lng = double.parse(value['longitude'].toString());
                final speed = double.parse(value['speed'].toString());
                final heading =
                    double.tryParse(value['heading']?.toString() ?? '0.0') ??
                        0.0;

                updatedVehicles[vehicleKey] = VehicleData(
                  position: LatLng(lat, lng),
                  speed: speed,
                  timestamp: timestamp,
                  heading: heading,
                );
              }
            } catch (e) {
              print("Debug: Error parsing data for $vehicleKey: $e");
            }
          });

          if (mounted) {
            setState(() {
              _allVehicles = updatedVehicles;
            });
          }
          print("Debug: Total active vehicles: ${updatedVehicles.length}");
          _checkOvertakingSafety();
        } catch (e) {
          _showMessage("Error processing data: $e");
        }
      },
      onError: (error) {
        _showMessage("Firebase error: $error");
      },
    );
  }

  /// Extended Overtaking Safety Logic:
  /// 1. Slow Vehicle Ahead:
  ///    - Angle difference < _angleThreshold (set to 180° for testing)
  ///    - Your speed is greater than the other vehicle's speed by at least _speedDiffThreshold
  ///    - The other vehicle is within _distanceThreshold meters
  ///
  /// 2. Oncoming vehicle check (not used in current testing)
  void _checkOvertakingSafety() {
    // Skip if current speed is below minimum.
    if (_currentSpeed < _minimumSpeedForCheck) {
      print(
          "Debug: Current speed ($_currentSpeed km/h) is below minimum threshold ($_minimumSpeedForCheck km/h).");
      if (mounted) setState(() => _overtakingUnsafe = false);
      return;
    }

    bool overtakingCandidate = false; // slow vehicle ahead
    bool oncomingDetected = false; // oncoming vehicle in opposite lane

    final distanceCalculator = Distance();

    _allVehicles.forEach((vehicleId, vehicleData) {
      // Skip your own vehicle.
      if (vehicleId == widget.vehicleId) return;

      double distance = distanceCalculator.as(
        LengthUnit.Meter,
        _currentPosition,
        vehicleData.position,
      );

      double bearingToOther = distanceCalculator.bearing(
        _currentPosition,
        vehicleData.position,
      );

      double angleDifference = (_currentHeading - bearingToOther).abs();
      if (angleDifference > 180) {
        angleDifference = 360 - angleDifference;
      }

      // Slow vehicle ahead check.
      if (angleDifference < _angleThreshold) {
        if (_currentSpeed > (vehicleData.speed + _speedDiffThreshold) &&
            distance < _distanceThreshold) {
          overtakingCandidate = true;
          print(
            "Debug: Slow vehicle ahead => ID=$vehicleId | distance=${distance.toStringAsFixed(2)} m, angleDiff=${angleDifference.toStringAsFixed(2)}°",
          );
        }
      }

      // Oncoming vehicle check (not active for current testing).
      double expectedOncomingHeading = (_currentHeading + 180) % 360;
      double headingDifference =
          (vehicleData.heading - expectedOncomingHeading).abs();
      if (headingDifference > 180) {
        headingDifference = 360 - headingDifference;
      }
      if (headingDifference < _angleThreshold &&
          distance < _distanceThresholdOncoming) {
        oncomingDetected = true;
        print(
          "Debug: Oncoming vehicle detected => ID=$vehicleId | distance=${distance.toStringAsFixed(2)} m",
        );
      }
    });

    bool finalUnsafe = overtakingCandidate || oncomingDetected;
    if (mounted) {
      setState(() {
        _overtakingUnsafe = finalUnsafe;
      });
    }
    print("Debug: Overtaking unsafe flag is set to: $_overtakingUnsafe");
  }

  void _showMessage(String message) {
    print("Debug: $message");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ----------------------
  // Settings Dialog to adjust thresholds
  // ----------------------
  Future<void> _showSettingsDialog() async {
    final TextEditingController speedDiffController =
        TextEditingController(text: _speedDiffThreshold.toString());
    final TextEditingController distanceController =
        TextEditingController(text: _distanceThreshold.toString());
    final TextEditingController angleController =
        TextEditingController(text: _angleThreshold.toString());
    final TextEditingController minSpeedController =
        TextEditingController(text: _minimumSpeedForCheck.toString());
    final TextEditingController oncomingDistanceController =
        TextEditingController(text: _distanceThresholdOncoming.toString());

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Overtaking Threshold Settings"),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  controller: speedDiffController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Speed Difference Threshold (km/h)",
                  ),
                ),
                TextField(
                  controller: distanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Distance Threshold (m)",
                  ),
                ),
                TextField(
                  controller: angleController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Angle Threshold (°)",
                  ),
                ),
                TextField(
                  controller: minSpeedController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Minimum Speed for Check (km/h)",
                  ),
                ),
                TextField(
                  controller: oncomingDistanceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Oncoming Vehicle Distance (m)",
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _speedDiffThreshold =
                      double.tryParse(speedDiffController.text) ??
                          _speedDiffThreshold;
                  _distanceThreshold =
                      double.tryParse(distanceController.text) ??
                          _distanceThreshold;
                  _angleThreshold =
                      double.tryParse(angleController.text) ?? _angleThreshold;
                  _minimumSpeedForCheck =
                      double.tryParse(minSpeedController.text) ??
                          _minimumSpeedForCheck;
                  _distanceThresholdOncoming =
                      double.tryParse(oncomingDistanceController.text) ??
                          _distanceThresholdOncoming;
                });
                print(
                    "Debug: New settings => SpeedDiff: $_speedDiffThreshold km/h, "
                    "Distance: $_distanceThreshold m, Angle: $_angleThreshold°, "
                    "MinSpeed: $_minimumSpeedForCheck km/h, OncomingDist: $_distanceThresholdOncoming m");
                Navigator.of(context).pop();
                _checkOvertakingSafety();
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // ----------------------
  // Speed Override Logic for Test Mode (My Vehicle Only)
  // ----------------------
  Future<void> _showSpeedOverrideDialog() async {
    final TextEditingController speedController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Override My Vehicle's Speed for 1 Minute"),
          content: TextField(
            controller: speedController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Enter new speed (km/h)",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                final newSpeed = double.tryParse(speedController.text);
                if (newSpeed != null) {
                  Navigator.of(context).pop();
                  _overrideSpeedForMyVehicle(newSpeed);
                } else {
                  _showMessage("Please enter a valid number.");
                }
              },
              child: const Text("Apply"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _overrideSpeedForMyVehicle(double newSpeed) async {
    // Activate override and update local state.
    _overrideActive = true;
    final int now = DateTime.now().millisecondsSinceEpoch;
    // Save the current speed for later restoration.
    final double originalSpeed =
        _allVehicles[widget.vehicleId]?.speed ?? _currentSpeed;

    // Update your vehicle's speed in local state and Firebase.
    setState(() {
      _currentSpeed = newSpeed;
    });
    _allVehicles[widget.vehicleId] = VehicleData(
      position: _currentPosition,
      speed: newSpeed,
      timestamp: now,
      heading: _currentHeading,
    );
    await _vehiclesRef.child(widget.vehicleId).update({
      "speed": newSpeed,
      "timestamp": now,
    });
    _checkOvertakingSafety();

    // After 1 minute, revert the speed to the original value.
    Timer(const Duration(minutes: 1), () async {
      final int revertTime = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        _currentSpeed = originalSpeed;
      });
      _allVehicles[widget.vehicleId] = VehicleData(
        position: _currentPosition,
        speed: originalSpeed,
        timestamp: revertTime,
        heading: _currentHeading,
      );
      await _vehiclesRef.child(widget.vehicleId).update({
        "speed": originalSpeed,
        "timestamp": revertTime,
      });
      _checkOvertakingSafety();
      _overrideActive = false;
    });
  }

  @override
  void dispose() {
    _firebaseSub?.cancel();
    _locationSubscription?.cancel();
    _staleDataTimer?.cancel();
    _firebaseUpdateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Vehicle Tracking"),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showSettingsDialog,
          ),
          // Add speed override button in test mode.
          if (_testMode)
            IconButton(
              icon: const Icon(Icons.speed),
              onPressed: _showSpeedOverrideDialog,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                _allVehicles.clear();
              });
              _listenToAllVehicles();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_overtakingUnsafe)
                  Container(
                    width: double.infinity,
                    color: Colors.redAccent,
                    padding: const EdgeInsets.all(8.0),
                    child: const Text(
                      "Warning: Unsafe overtaking conditions detected!",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: _currentPosition,
                      initialZoom: 15.0,
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        subdomains: const ['a', 'b', 'c'],
                        userAgentPackageName: 'com.example.vehicle_tracking',
                      ),
                      MarkerLayer(markers: _buildMarkers()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  List<Marker> _buildMarkers() {
    final vehicleKeys = _allVehicles.keys.toList();
    final markers = <Marker>[
      // Build marker for your own vehicle.
      _buildVehicleMarker(
        widget.vehicleId,
        _currentPosition,
        _currentSpeed,
        _currentHeading,
        true,
        0,
      ),
      // Build markers for other vehicles.
      ...vehicleKeys.where((key) => key != widget.vehicleId).map((key) {
        final vehicleData = _allVehicles[key]!;
        return _buildVehicleMarker(
          key,
          vehicleData.position,
          vehicleData.speed,
          vehicleData.heading,
          false,
          1,
        );
      }).toList(),
    ];
    return markers;
  }

  Marker _buildVehicleMarker(
    String vehicleId,
    LatLng position,
    double speed,
    double heading,
    bool isCurrent,
    int index,
  ) {
    final double offset = index * 0.0001;
    final offsetPosition = LatLng(
      position.latitude + offset,
      position.longitude - offset,
    );
    return Marker(
      point: offsetPosition,
      width: 80,
      height: 80,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Transform.rotate(
            angle: heading * math.pi / 180,
            child: Icon(
              Icons.navigation,
              color: isCurrent ? Colors.red : Colors.blue,
              size: 36,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: isCurrent ? Colors.red : Colors.blue,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Text(
                  vehicleId,
                  style: TextStyle(
                    color: isCurrent ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
                Text(
                  "${speed.toStringAsFixed(1)} km/h",
                  style: TextStyle(
                    color: isCurrent ? Colors.red : Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VehicleData {
  final LatLng position;
  final double speed;
  final int timestamp;
  final double heading;

  VehicleData({
    required this.position,
    required this.speed,
    required this.timestamp,
    required this.heading,
  });
}
