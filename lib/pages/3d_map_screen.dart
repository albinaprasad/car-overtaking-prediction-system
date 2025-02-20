import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// Audio player for the beep/ding
import 'package:audioplayers/audioplayers.dart';

/// This widget represents the 3D Map Screen with real-time location,
/// destination search & navigation, refined pothole detection,
/// alternative routes and near-pothole alerts.
class ThreeDMapScreen extends StatefulWidget {
  const ThreeDMapScreen({Key? key}) : super(key: key);

  @override
  State<ThreeDMapScreen> createState() => _ThreeDMapScreenState();
}

class _ThreeDMapScreenState extends State<ThreeDMapScreen> {
  // GlobalKey to access the FlutterMap state.
  final GlobalKey _mapKey = GlobalKey();
  final MapController _mapController = MapController();

  // Default center (Kerala center) and zoom.
  LatLng _center = LatLng(10.8505, 76.2711);
  double _zoom = 15.0;
  LatLng? _destination;

  // Storage for alternative routes and the currently selected route.
  List<List<LatLng>> _alternativeRoutes = [];
  List<LatLng>? _selectedRoute;

  // Toggles.
  bool isSupersafe = false;
  bool isIncidentMode = false;

  // Sensor subscriptions and timers.
  StreamSubscription? _accelerometerSubscription;
  StreamSubscription<Position>? _positionSubscription;
  final double potholeThreshold = 15.0;
  final double jerkThreshold = 20.0;
  Timer? _potholeCooldownTimer;

  // For sliding window analysis (a simple buffer of recent accelerometer values).
  final List<double> _accelBuffer = [];
  final int _bufferSize = 5;

  // Variables to support jerk calculation.
  double? _prevAcceleration;
  DateTime? _prevTime;

  // Firebase Database reference for incident reports.
  final DatabaseReference _incidentRef =
      FirebaseDatabase.instance.ref('incident_reports');

  // Controller for search TextField.
  final TextEditingController _searchController = TextEditingController();

  // Cache for pothole incidents used for risk calculation.
  final List<Map<String, dynamic>> _potholeIncidents = [];
  final Set<String> _alertedPotholes = {};

  // Audio player for beep/ding alerts
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    debugPrint("Initializing ThreeDMapScreen");
    _startPotholeDetection();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _accelerometerSubscription?.cancel();
    _potholeCooldownTimer?.cancel();
    _positionSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // =========================================
  // MATERIAL BANNER + AUDIO ALERT (HELPER)
  // =========================================
  /// Shows a brief MaterialBanner at the top, plays a short sound, and auto-dismisses.
  Future<void> _showBannerWithAudioAlert(String message) async {
    // Play a short alert sound
    try {
      await _audioPlayer.play(AssetSource('audio/alert.mp3'));
    } catch (e) {
      debugPrint('Error playing audio: $e');
    }

    // Use a local reference to the ScaffoldMessenger
    final messenger = ScaffoldMessenger.of(context);

    // Clear any old banners
    messenger.clearMaterialBanners();

    // Show the new banner
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: Colors.orangeAccent,
        actions: [
          TextButton(
            onPressed: messenger.clearMaterialBanners,
            child: const Text('DISMISS'),
          ),
        ],
      ),
    );

    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        messenger.clearMaterialBanners();
      }
    });
  }

  /// Toggles Supersafe mode.
  void _toggleSupersafe() {
    setState(() {
      isSupersafe = !isSupersafe;
      debugPrint("Supersafe mode toggled: $isSupersafe");
    });
    if (_destination != null) {
      _handleSearch();
    }
  }

  /// Listens to accelerometer events with a sliding window and basic jerk calculation.
  void _startPotholeDetection() {
    _accelerometerSubscription = accelerometerEvents.listen((event) {
      double currentAcceleration =
          sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _accelBuffer.add(currentAcceleration);
      if (_accelBuffer.length > _bufferSize) {
        _accelBuffer.removeAt(0);
      }

      final currentTime = DateTime.now();
      if (_prevAcceleration != null && _prevTime != null) {
        double deltaAccel = currentAcceleration - _prevAcceleration!;
        double deltaTime =
            currentTime.difference(_prevTime!).inMilliseconds / 1000.0;
        double jerk = deltaTime > 0 ? deltaAccel / deltaTime : 0;

        if (currentAcceleration > potholeThreshold &&
            jerk > jerkThreshold &&
            _potholeCooldownTimer == null) {
          debugPrint(
              "Pothole detected! Acc: $currentAcceleration, Jerk: $jerk");
          _reportPothole(currentAcceleration);
          _potholeCooldownTimer = Timer(const Duration(seconds: 10), () {
            _potholeCooldownTimer = null;
          });
        }
      }
      _prevAcceleration = currentAcceleration;
      _prevTime = currentTime;
    });
  }

  /// Reports a pothole event to Firebase.
  Future<void> _reportPothole(double severityValue) async {
    final report = {
      'type': 'pothole',
      'location': {'lat': _center.latitude, 'lng': _center.longitude},
      'severity': severityValue,
      'timestamp': DateTime.now().toIso8601String(),
      'autoDetected': true,
    };

    try {
      await _incidentRef.push().set(report);
      debugPrint('Pothole reported: $report');
    } catch (e) {
      debugPrint('Error reporting pothole: $e');
    }
  }

  /// Requests location permissions and starts real-time location tracking.
  Future<bool> _requestLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showBannerWithAudioAlert(
          'Location services are disabled. Please enable GPS.');
      return false;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showBannerWithAudioAlert('Location permission denied.');
        return false;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showBannerWithAudioAlert('Location permissions are permanently denied.');
      return false;
    }
    return true;
  }

  /// Gets current location, updates the map, and checks pothole proximity.
  void _getCurrentLocation() async {
    if (!await _requestLocationPermission()) return;
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _center = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_center, _zoom);
      debugPrint("Current location: $_center");
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((Position position) {
        setState(() {
          _center = LatLng(position.latitude, position.longitude);
        });
        _mapController.move(_center, _zoom);
        debugPrint("Updated location: $_center");
        _checkPotholeProximity(_center);
      });
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  /// Checks if the current location is near any known potholes.
  void _checkPotholeProximity(LatLng currentLocation) {
    final Distance distance = Distance();
    const double alertThreshold = 50; // meters
    for (var pothole in _potholeIncidents) {
      String potholeID = pothole['timestamp'] ?? pothole.hashCode.toString();
      LatLng potholeLocation = LatLng(pothole['lat'], pothole['lng']);
      double d =
          distance.as(LengthUnit.Meter, currentLocation, potholeLocation);
      if (d < alertThreshold && !_alertedPotholes.contains(potholeID)) {
        _alertedPotholes.add(potholeID);
        debugPrint("Alert: Pothole at $potholeLocation is $d meters away");
        // Show banner + beep
        _showBannerWithAudioAlert(
          'Caution: Pothole ahead (${d.toStringAsFixed(1)}m away)!',
        );
      }
    }
  }

  /// Calculates a risk score for a route based on pothole proximity.
  double _calculateRouteRisk(List<LatLng> route) {
    double risk = 0.0;
    final Distance distance = Distance();
    for (LatLng point in route) {
      for (var pothole in _potholeIncidents) {
        LatLng potholeLocation = LatLng(pothole['lat'], pothole['lng']);
        if (distance.as(LengthUnit.Meter, point, potholeLocation) < 50) {
          risk += (pothole['severity'] ?? 1.0);
        }
      }
    }
    return risk;
  }

  /// Fetches alternative routes from OSRM API.
  Future<List<List<LatLng>>> _fetchRoutes(
      LatLng origin, LatLng destination) async {
    final url =
        "http://router.project-osrm.org/route/v1/driving/${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}?overview=full&geometries=polyline&alternatives=true";
    debugPrint("Fetching routes from URL: $url");
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      List routes = data['routes'];
      debugPrint("Fetched ${routes.length} routes");
      if (routes.isEmpty) throw Exception("No route found");
      List<List<LatLng>> routesList = [];
      for (var route in routes) {
        final polylineString = route['geometry'];
        final polylinePoints = PolylinePoints().decodePolyline(polylineString);
        List<LatLng> routePoints = polylinePoints
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();
        routesList.add(routePoints);
      }
      return routesList;
    } else {
      throw Exception("Failed to fetch route");
    }
  }

  /// Handles search submission: parses destination, fetches routes, and calculates risk.
  void _handleSearch() async {
    String text = _searchController.text.trim();
    if (text.isEmpty) return;
    List<String> parts = text.split(',');
    if (parts.length != 2) {
      _showBannerWithAudioAlert('Enter coordinates as lat,lon');
      return;
    }
    try {
      double lat = double.parse(parts[0]);
      double lon = double.parse(parts[1]);
      final dest = LatLng(lat, lon);
      setState(() {
        _destination = dest;
      });
      debugPrint("Destination set to: $_destination");
      List<List<LatLng>> routes = await _fetchRoutes(_center, dest);
      setState(() {
        _alternativeRoutes = routes;
      });
      debugPrint("Alternative routes stored: ${_alternativeRoutes.length}");
      // Recalculate risk if in Supersafe mode.
      if (isSupersafe && _potholeIncidents.isNotEmpty) {
        double bestRisk = double.infinity;
        List<LatLng>? bestRoute;
        for (var route in routes) {
          double risk = _calculateRouteRisk(route);
          debugPrint("Route risk: $risk");
          if (risk < bestRisk) {
            bestRisk = risk;
            bestRoute = route;
          }
        }
        setState(() {
          _selectedRoute = bestRoute;
        });
        debugPrint(
            "Supersafe mode active. Selected safest route with risk: $bestRisk");
      } else {
        setState(() {
          _selectedRoute = null;
        });
        debugPrint("Supersafe mode off. Displaying all routes.");
      }
      _mapController.move(_center, _zoom);
    } catch (e) {
      _showBannerWithAudioAlert('Invalid format or error fetching route');
      debugPrint("Error in _handleSearch: $e");
    }
  }

  /// Opens the incident reporting sheet for a tapped coordinate.
  void _openReportIncidentSheetWithCoordinate(LatLng tappedCoord) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ReportIncidentSheet(currentLocation: tappedCoord),
    );
  }

  /// Builds incident markers from Firebase data and caches pothole incidents.
  List<Marker> _buildIncidentMarkers(DatabaseEvent event) {
    _potholeIncidents.clear();
    final data = event.snapshot.value;
    if (data == null) return [];
    final Map<dynamic, dynamic> incidents = data as Map<dynamic, dynamic>;
    final List<Marker> markers = [];
    incidents.forEach((key, value) {
      final incident = Map<String, dynamic>.from(value);
      final LatLng point =
          LatLng(incident['location']['lat'], incident['location']['lng']);
      IconData icon;
      Color color;
      if (incident['type'] == 'pothole') {
        icon = Icons.warning_amber_rounded;
        color = (incident['severity'] > potholeThreshold)
            ? Colors.red
            : Colors.orange;
        _potholeIncidents.add({
          'lat': incident['location']['lat'],
          'lng': incident['location']['lng'],
          'severity': incident['severity'],
          'timestamp': incident['timestamp'] // used for alert deduplication
        });
      } else {
        icon = Icons.report;
        color = Colors.blue;
      }
      markers.add(Marker(
        width: 40,
        height: 40,
        point: point,
        child: Icon(icon, color: color, size: 30),
      ));
    });
    return markers;
  }

  /// Opens a bottom sheet for the user to select one of the alternative routes.
  void _showRouteSelectionSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: _alternativeRoutes.length,
          itemBuilder: (context, index) {
            double risk = _calculateRouteRisk(_alternativeRoutes[index]);
            return ListTile(
              title: Text("Route ${index + 1}"),
              subtitle: Text("Risk Score: ${risk.toStringAsFixed(1)}"),
              onTap: () {
                setState(() {
                  _selectedRoute = _alternativeRoutes[index];
                });
                debugPrint("User selected route ${index + 1} with risk $risk");
                Navigator.pop(context);
              },
            );
          },
        );
      },
    );
  }

  /// Returns a list of polylines for display on the map.
  List<Polyline> _buildPolylines() {
    List<Polyline> polylines = [];
    if (isSupersafe && _selectedRoute != null) {
      polylines.add(Polyline(
        points: _selectedRoute!,
        strokeWidth: 5.0,
        color: Colors.green,
      ));
      debugPrint("Drawing only the safest route in Supersafe mode.");
    } else {
      List<Color> colors = [
        Colors.blue,
        Colors.orange,
        Colors.purple,
        Colors.teal
      ];
      for (int i = 0; i < _alternativeRoutes.length; i++) {
        polylines.add(Polyline(
          points: _alternativeRoutes[i],
          strokeWidth: _selectedRoute == null
              ? 5.0
              : (_selectedRoute == _alternativeRoutes[i] ? 7.0 : 4.0),
          color: colors[i % colors.length],
        ));
      }
      debugPrint(
          "Drawing all ${_alternativeRoutes.length} alternative routes.");
    }
    return polylines;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supersafe Navigation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alert),
            tooltip: 'Toggle Incident Mode',
            onPressed: () {
              setState(() {
                isIncidentMode = !isIncidentMode;
                debugPrint("Incident mode toggled: $isIncidentMode");
              });
            },
          ),
          IconButton(
            icon: Icon(isSupersafe ? Icons.security : Icons.security_outlined),
            tooltip: isSupersafe ? 'Supersafe Mode On' : 'Supersafe Mode Off',
            onPressed: _toggleSupersafe,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Destination (lat,lon)',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _handleSearch,
                  child: const Text('Search'),
                ),
              ],
            ),
          ),
          // Button for route selection (if multiple routes exist and not in Supersafe mode).
          if (!isSupersafe && _alternativeRoutes.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: ElevatedButton(
                onPressed: _showRouteSelectionSheet,
                child: const Text('Select Route'),
              ),
            ),
          // Expanded map area.
          Expanded(
            child: StreamBuilder<DatabaseEvent>(
              stream: _incidentRef.onValue,
              builder: (context, snapshot) {
                List<Marker> markers = [];
                if (snapshot.hasData && snapshot.data!.snapshot.value != null) {
                  markers = _buildIncidentMarkers(snapshot.data!);
                }
                // User location marker.
                markers.add(
                  Marker(
                    width: 40,
                    height: 40,
                    point: _center,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_on,
                          color: Colors.white, size: 30),
                    ),
                  ),
                );
                // Destination marker.
                if (_destination != null) {
                  markers.add(
                    Marker(
                      width: 40,
                      height: 40,
                      point: _destination!,
                      child: const Icon(Icons.flag,
                          color: Colors.purple, size: 30),
                    ),
                  );
                }
                return Stack(
                  children: [
                    FlutterMap(
                      key: _mapKey,
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _center,
                        initialZoom: _zoom,
                        onTap: (tapPosition, tappedCoord) async {
                          if (isIncidentMode) {
                            bool confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Report Incident'),
                                    content: Text(
                                        'Do you want to report an incident at '
                                        '(${tappedCoord.latitude.toStringAsFixed(4)}, '
                                        '${tappedCoord.longitude.toStringAsFixed(4)})?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(true),
                                        child: const Text('Confirm'),
                                      ),
                                    ],
                                  ),
                                ) ??
                                false;
                            if (confirm) {
                              _openReportIncidentSheetWithCoordinate(
                                  tappedCoord);
                            }
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                          subdomains: const ['a', 'b', 'c'],
                          userAgentPackageName: 'com.my-app.app',
                        ),
                        // Draw route polylines.
                        PolylineLayer(polylines: _buildPolylines()),
                        MarkerLayer(markers: markers),
                      ],
                    ),
                    // Attribution overlay (optional).
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '© OpenStreetMap contributors',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ),
                    ),
                    // Incident mode banner.
                    if (isIncidentMode)
                      Positioned(
                        top: 60,
                        left: 0,
                        right: 0,
                        child: Container(
                          color: Colors.red.withOpacity(0.7),
                          padding: const EdgeInsets.all(8),
                          child: const Center(
                            child: Text(
                              'Incident Mode Active - Tap on map to report',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ),
                    // Live tracking indicator.
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.gps_fixed,
                              color: _positionSubscription != null
                                  ? Colors.green
                                  : Colors.grey,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _positionSubscription != null
                                  ? 'Live tracking on'
                                  : 'GPS inactive',
                              style: TextStyle(
                                fontSize: 12,
                                color: _positionSubscription != null
                                    ? Colors.green
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        tooltip: 'Center on current location',
        onPressed: () {
          if (_positionSubscription == null) {
            _getCurrentLocation();
          } else {
            _mapController.move(_center, _zoom);
          }
        },
      ),
    );
  }
}

/// Widget for manually reporting an incident.
class ReportIncidentSheet extends StatefulWidget {
  final LatLng currentLocation;
  const ReportIncidentSheet({Key? key, required this.currentLocation})
      : super(key: key);

  @override
  State<ReportIncidentSheet> createState() => _ReportIncidentSheetState();
}

class _ReportIncidentSheetState extends State<ReportIncidentSheet> {
  final DatabaseReference _incidentRef =
      FirebaseDatabase.instance.ref('incident_reports');
  final _formKey = GlobalKey<FormState>();
  String _incidentType = 'accident';
  String _description = '';
  double _severity = 1.0;

  // ====================================
  // BANNER HELPER FOR THIS BOTTOM SHEET
  // ====================================
  Future<void> _showAutoDismissingBanner(String message, Color bgColor) async {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    // Clear any existing banners
    messenger.clearMaterialBanners();

    // Show new banner
    messenger.showMaterialBanner(
      MaterialBanner(
        content: Text(message),
        backgroundColor: bgColor,
        actions: [
          TextButton(
            onPressed: messenger.clearMaterialBanners,
            child: const Text('OK'),
          ),
        ],
      ),
    );

    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        messenger.clearMaterialBanners();
      }
    });
  }

  Future<void> _submitReport() async {
    final report = {
      'type': _incidentType,
      'location': {
        'lat': widget.currentLocation.latitude,
        'lng': widget.currentLocation.longitude,
      },
      'severity': _severity,
      'description': _description,
      'timestamp': DateTime.now().toIso8601String(),
      'autoDetected': false,
    };

    try {
      await _incidentRef.push().set(report);
      if (mounted) {
        Navigator.pop(context);
        // Show success banner
        _showAutoDismissingBanner(
          'Incident reported successfully.',
          Colors.greenAccent,
        );
      }
    } catch (e) {
      debugPrint('Error reporting incident: $e');
      if (mounted) {
        _showAutoDismissingBanner(
          'Error reporting incident: $e',
          Colors.redAccent,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // This ensures the sheet is above the keyboard when it appears
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Report Incident',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Location: ${widget.currentLocation.latitude.toStringAsFixed(6)}, '
                '${widget.currentLocation.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _incidentType,
                items: const [
                  DropdownMenuItem(child: Text('Accident'), value: 'accident'),
                  DropdownMenuItem(
                      child: Text('Roadblock'), value: 'roadblock'),
                  DropdownMenuItem(child: Text('Pothole'), value: 'pothole'),
                  DropdownMenuItem(child: Text('Other'), value: 'other'),
                ],
                onChanged: (value) {
                  setState(() {
                    _incidentType = value!;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Incident Type',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  hintText: 'Provide details about the incident',
                ),
                maxLines: 2,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please provide a description';
                  }
                  return null;
                },
                onChanged: (value) {
                  _description = value;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Severity:'),
                  Expanded(
                    child: Slider(
                      value: _severity,
                      min: 1.0,
                      max: 5.0,
                      divisions: 4,
                      label: _severity.toStringAsFixed(1),
                      onChanged: (value) {
                        setState(() {
                          _severity = value;
                        });
                      },
                    ),
                  ),
                  Text(
                    _severity.toStringAsFixed(1),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState!.validate()) {
                        _submitReport();
                      }
                    },
                    child: const Text('Submit Report'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
