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
    GlobalKey<RefreshIndicatorState>(),
    GlobalKey<RefreshIndicatorState>(), // Added for Users tab.
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Updated length.
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
            Tab(text: "Special Node", icon: Icon(Icons.data_object)),
            Tab(text: "Users", icon: Icon(Icons.person)), // New Users tab.
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRefreshableTab(0, VehiclesTab()),
          _buildRefreshableTab(1, IncidentReportsTab()),
          _buildRefreshableTab(2, SpecialNodeTab()),
          _buildRefreshableTab(3, UsersTab()), // New Users tab content.
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

class SpecialNodeTab extends StatelessWidget {
  final specialNodeRef = FirebaseDatabase.instance.ref("-OLSUx1L6keI5Jiu0M_j");

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DatabaseEvent>(
      stream: specialNodeRef.onValue.handleError((error) {
        _showErrorSnackbar(context, "Special Node: $error");
      }),
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return _ErrorWidget(message: "Failed to load node data");
        if (snapshot.connectionState == ConnectionState.waiting)
          return _LoadingList(items: 4);

        final nodeData = _parseSnapshotData(snapshot.data?.snapshot);
        return nodeData.isNotEmpty
            ? _NodeDataList(nodeData: nodeData)
            : _EmptyState(message: "No data available");
      },
    );
  }
}

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

// List Widgets for Special Node Data
class _NodeDataList extends StatelessWidget {
  final Map<dynamic, dynamic> nodeData;

  const _NodeDataList({required this.nodeData});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: nodeData.length,
      itemBuilder: (context, index) {
        final entry = nodeData.entries.elementAt(index);
        return _NodeDataListItem(
          key: ValueKey(entry.key),
          label: entry.key.toString(),
          value: entry.value,
        );
      },
    );
  }
}

class _NodeDataListItem extends StatelessWidget {
  final String label;
  final dynamic value;

  const _NodeDataListItem({
    required Key key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      color: Colors.blue[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ListTile(
        leading: Icon(Icons.data_object, color: Colors.blue),
        title: Text(label),
        subtitle: _buildValuePreview(value),
        trailing: Icon(Icons.chevron_right),
        onTap: () =>
            showDetailDialog(context, label, {'value': value}, "Node Data"),
      ),
    );
  }

  Widget _buildValuePreview(dynamic value) {
    if (value is Map) {
      return Text("${value.length} items", style: TextStyle(fontSize: 12));
    }
    return Text(value.toString(), style: TextStyle(fontSize: 12));
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
        Text("${key}: ", style: TextStyle(fontWeight: FontWeight.bold)),
        Expanded(child: buildValueDisplay(value)),
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
        Text("  $key: ", style: TextStyle(fontStyle: FontStyle.italic)),
        Expanded(child: Text(value.toString())),
      ],
    ),
  );
}
