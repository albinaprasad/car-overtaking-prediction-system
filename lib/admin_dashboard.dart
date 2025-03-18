import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class AdminDashboard extends StatefulWidget {
  @override
  _AdminDashboardState createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _refreshIndicatorKeys = [
    GlobalKey<RefreshIndicatorState>(),
    GlobalKey<RefreshIndicatorState>(),
    GlobalKey<RefreshIndicatorState>(), // For Overspeed Events tab.
    GlobalKey<RefreshIndicatorState>(),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Dashboard"),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: "Vehicles", icon: Icon(Icons.directions_car)),
            Tab(text: "Incidents", icon: Icon(Icons.report_problem)),
            Tab(text: "Overspeed Events", icon: Icon(Icons.speed)),
            Tab(text: "Users", icon: Icon(Icons.person)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRefreshableTab(0, VehiclesTab()),
          _buildRefreshableTab(1, IncidentReportsTab()),
          _buildRefreshableTab(2, OverspeedEventsTab()),
          _buildRefreshableTab(3, UsersTab()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showLogoutConfirmation(context),
        child: Icon(Icons.logout),
        tooltip: 'Logout',
      ),
    );
  }

  Widget _buildRefreshableTab(int index, Widget child) {
    return RefreshIndicator(
      key: _refreshIndicatorKeys[index],
      onRefresh: () async => setState(() {}),
      child: child,
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Logout"),
        content: Text("Are you sure you want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/adminLogin');
            },
            child: Text("Logout", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Vehicles Tab
class VehiclesTab extends StatelessWidget {
  final vehiclesRef = FirebaseDatabase.instance.ref("vehicles");

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: vehiclesRef.onValue.handleError((error) {
        _showErrorSnackbar(context, "Vehicles: $error");
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _ErrorWidget(message: "Failed to load vehicles");
        if (snapshot.connectionState == ConnectionState.waiting)
          return _LoadingList(items: 5);

        final vehicles = _parseSnapshotData(snapshot.data?.snapshot);
        return vehicles.isNotEmpty
            ? _VehicleList(vehicles: vehicles)
            : _EmptyState(message: "No vehicles found");
      },
    );
  }
}

// Incident Reports Tab
class IncidentReportsTab extends StatelessWidget {
  final incidentsRef = FirebaseDatabase.instance.ref("incident_reports");

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: incidentsRef.onValue.handleError((error) {
        _showErrorSnackbar(context, "Incidents: $error");
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _ErrorWidget(message: "Failed to load incidents");
        if (snapshot.connectionState == ConnectionState.waiting)
          return _LoadingList(items: 3);

        final incidents = _parseSnapshotData(snapshot.data?.snapshot);
        return incidents.isNotEmpty
            ? _IncidentList(incidents: incidents)
            : _EmptyState(message: "No incidents reported");
      },
    );
  }
}

// Overspeed Events Tab
class OverspeedEventsTab extends StatelessWidget {
  final overspeedRef = FirebaseDatabase.instance.ref("overspeed_events");

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: overspeedRef.onValue.handleError((error) {
        _showErrorSnackbar(context, "Overspeed Events: $error");
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _ErrorWidget(message: "Failed to load overspeed events");
        if (snapshot.connectionState == ConnectionState.waiting)
          return _LoadingList(items: 4);

        final events = _parseSnapshotData(snapshot.data?.snapshot);
        return events.isNotEmpty
            ? _OverspeedEventList(events: events)
            : _EmptyState(message: "No overspeed events found");
      },
    );
  }
}

// Users Tab
class UsersTab extends StatelessWidget {
  final usersRef = FirebaseDatabase.instance.ref("users");

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: usersRef.onValue.handleError((error) {
        _showErrorSnackbar(context, "Users: $error");
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _ErrorWidget(message: "Failed to load users");
        if (snapshot.connectionState == ConnectionState.waiting)
          return _LoadingList(items: 5);

        final users = _parseSnapshotData(snapshot.data?.snapshot);
        return users.isNotEmpty
            ? _UserList(users: users)
            : _EmptyState(message: "No users found");
      },
    );
  }
}

// List Widgets for Vehicles
class _VehicleList extends StatelessWidget {
  final Map<dynamic, dynamic> vehicles;

  const _VehicleList({required this.vehicles});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: vehicles.length,
      itemBuilder: (context, index) {
        final entry = vehicles.entries.elementAt(index);
        final vehicleData = _ensureMap(entry.value);
        return _VehicleListItem(
          key: ValueKey(entry.key),
          vehicleId: entry.key.toString(),
          data: vehicleData,
        );
      },
    );
  }
}

class _VehicleListItem extends StatelessWidget {
  final String vehicleId;
  final Map<dynamic, dynamic> data;

  const _VehicleListItem({
    required Key key,
    required this.vehicleId,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        title: Text("Vehicle $vehicleId",
            style: TextStyle(fontWeight: FontWeight.w500)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Speed: ${_formatSpeed(data['speed'])}"),
            Text("Last update: ${_formatTimestamp(data['timestamp'])}"),
          ],
        ),
        trailing: _LocationChip(
          lat: data['latitude'],
          lon: data['longitude'],
        ),
        onTap: () => showDetailDialog(context, vehicleId, data, "Vehicle"),
      ),
    );
  }
}

// List Widgets for Incidents
class _IncidentList extends StatelessWidget {
  final Map<dynamic, dynamic> incidents;

  const _IncidentList({required this.incidents});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: incidents.length,
      itemBuilder: (context, index) {
        final entry = incidents.entries.elementAt(index);
        final incidentData = _ensureMap(entry.value);
        return _IncidentListItem(
          key: ValueKey(entry.key),
          incidentId: entry.key.toString(),
          data: incidentData,
        );
      },
    );
  }
}

class _IncidentListItem extends StatelessWidget {
  final String incidentId;
  final Map<dynamic, dynamic> data;

  const _IncidentListItem({
    required Key key,
    required this.incidentId,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.amber[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(Icons.warning, color: Colors.orange),
        title: Text("Incident $incidentId"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Type: ${data['type'] ?? 'Unknown'}"),
            Text("Reported: ${_formatTimestamp(data['timestamp'])}"),
          ],
        ),
        trailing: Icon(Icons.chevron_right),
        onTap: () => showDetailDialog(context, incidentId, data, "Incident"),
      ),
    );
  }
}

// List Widgets for Overspeed Events (updated to mimic vehicle display)
class _OverspeedEventList extends StatelessWidget {
  final Map<dynamic, dynamic> events;

  const _OverspeedEventList({required this.events});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: events.length,
      itemBuilder: (context, index) {
        final entry = events.entries.elementAt(index);
        final eventData = _ensureMap(entry.value);
        return _OverspeedEventListItem(
          key: ValueKey(entry.key),
          eventId: entry.key.toString(),
          data: eventData,
        );
      },
    );
  }
}

class _OverspeedEventListItem extends StatelessWidget {
  final String eventId;
  final Map<dynamic, dynamic> data;

  const _OverspeedEventListItem({
    required Key key,
    required this.eventId,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Similar design to the vehicle display
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        title: Text(
          "Vehicle ${data['vehicleNumber'] ?? 'Unknown'}",
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Status: ${data['status'] ?? 'N/A'}"),
            Text("Max Speed: ${_formatSpeed(data['maxSpeed'])}"),
            Text("Speed Limit: ${_formatSpeed(data['speedLimit'])}"),
            Text("Started: ${_formatTimestamp(data['startTimestamp'])}"),
          ],
        ),
        trailing: _LocationChip(
          lat: data['startLatitude'],
          lon: data['startLongitude'],
        ),
        onTap: () =>
            showDetailDialog(context, eventId, data, "Overspeed Event"),
      ),
    );
  }
}

// List Widgets for Users
class _UserList extends StatelessWidget {
  final Map<dynamic, dynamic> users;

  const _UserList({required this.users});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final entry = users.entries.elementAt(index);
        final userData = _ensureMap(entry.value);
        return _UserListItem(
          key: ValueKey(entry.key),
          userId: entry.key.toString(),
          data: userData,
        );
      },
    );
  }
}

class _UserListItem extends StatelessWidget {
  final String userId;
  final Map<dynamic, dynamic> data;

  const _UserListItem({
    required Key key,
    required this.userId,
    required this.data,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(Icons.person, color: Colors.blue),
        title: Text(data['fullName'] ?? "User $userId"),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email: ${data['email'] ?? 'N/A'}"),
            Text("Contact: ${data['contactNumber'] ?? 'N/A'}"),
            Text("Vehicle: ${data['vehicleRegNumber'] ?? 'N/A'}"),
          ],
        ),
        trailing: Icon(Icons.chevron_right),
        onTap: () => showDetailDialog(context, userId, data, "User"),
      ),
    );
  }
}

// UI Components
class _LoadingList extends StatelessWidget {
  final int items;

  const _LoadingList({required this.items});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: items,
      itemBuilder: (context, index) => Padding(
        padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 48, color: Colors.grey),
          SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _ErrorWidget extends StatelessWidget {
  final String message;

  const _ErrorWidget({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red),
          SizedBox(height: 16),
          Text(message, style: TextStyle(color: Colors.red)),
          SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // Implement a proper retry callback if needed.
            },
            child: Text("Retry"),
          ),
        ],
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  final dynamic lat;
  final dynamic lon;

  const _LocationChip({required this.lat, required this.lon});

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: Colors.blue[50],
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Lat: ${_formatCoordinate(lat)}",
              style: TextStyle(fontSize: 12)),
          Text("Lon: ${_formatCoordinate(lon)}",
              style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

// Helper Functions
Map<dynamic, dynamic> _parseSnapshotData(DataSnapshot? snapshot) {
  final value = snapshot?.value;
  return value is Map ? value.cast<dynamic, dynamic>() : {};
}

Map<dynamic, dynamic> _ensureMap(dynamic value) {
  return value is Map ? value.cast<dynamic, dynamic>() : {};
}

String _formatSpeed(dynamic speed) {
  final numValue = speed is num ? speed.toDouble() : 0.0;
  return "${numValue.toStringAsFixed(1)} km/h";
}

String _formatTimestamp(dynamic timestamp) {
  if (timestamp == null) return "N/A";
  try {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp as int);
    return DateFormat('MMM dd, yyyy - HH:mm').format(date);
  } catch (e) {
    return "Invalid timestamp";
  }
}

String _formatCoordinate(dynamic coord) {
  if (coord is num) return coord.toStringAsFixed(5);
  return coord?.toString() ?? "N/A";
}

void _showErrorSnackbar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: Duration(seconds: 3),
    ),
  );
}

// Detail Dialog Functions
void showDetailDialog(
    BuildContext context, dynamic id, Map<dynamic, dynamic> data, String type) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text("$type Details"),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("ID: $id", style: TextStyle(fontWeight: FontWeight.bold)),
            Divider(),
            ...data.entries.map((e) => _buildDetailRow(e.key, e.value)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Close"),
        ),
      ],
    ),
  );
}

Widget _buildDetailRow(dynamic key, dynamic value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 1,
          child: Text(
            "$key: ",
            style: TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: buildValueDisplay(value),
        ),
      ],
    ),
  );
}

Widget buildValueDisplay(dynamic value) {
  if (value is Map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          value.entries.map((e) => _buildSubItem(e.key, e.value)).toList(),
    );
  } else if (value is List) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: value
          .asMap()
          .entries
          .map((e) => _buildSubItem(e.key, e.value))
          .toList(),
    );
  }
  return Text(value.toString(), softWrap: true);
}

Widget _buildSubItem(dynamic key, dynamic value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          flex: 1,
          child: Text(
            "  $key: ",
            style: TextStyle(fontStyle: FontStyle.italic),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8),
        Flexible(
          flex: 2,
          child: Text(
            value.toString(),
            softWrap: true,
          ),
        ),
      ],
    ),
  );
}
