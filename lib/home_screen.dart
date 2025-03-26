import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import overspeed_screen if you need references here
import 'overspeed/overspeed_screen.dart';

class HomeScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const HomeScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userId;
  String? vehicleNumber;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  // Retrieve stored user data (userId and vehicleNumber) from SharedPreferences.
  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString("userId");
      vehicleNumber = prefs.getString("vehicleNumber");
    });
  }

  @override
  Widget build(BuildContext context) {
    // While loading, show a loading indicator.
    if (userId == null || vehicleNumber == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      // We'll add a Drawer to mimic the blue menu.
      drawer: const _CustomDrawer(),
      appBar: AppBar(
        title: const Text("--AEGIS--"),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top header area: You can display an image or hero text.
            _HeaderSection(),
            // Grid of features (Overspeed, Overtaking, and 3D Map).
            _FeatureGrid(
              cameras: widget.cameras,
              userId: userId!,
              vehicleNumber: vehicleNumber!,
            ),
            // "Popular Services" section.
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Services",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            _PopularServicesList(),
          ],
        ),
      ),
    );
  }
}

/// A header with an optional image, title, and subtitle.
class _HeaderSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      // Adjust height as needed.
      height: 200,
      width: double.infinity,
      decoration: const BoxDecoration(
        // Could be a gradient or an image.
        gradient: LinearGradient(
          colors: [
            Color.fromARGB(255, 14, 126, 231),
            Color(0xFF2196F3),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Text(
                "Navigate your journey with confidence",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                "Your one-stop safety solution.",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A grid with feature cards for main functionalities.
class _FeatureGrid extends StatelessWidget {
  final List<CameraDescription> cameras;
  final String userId;
  final String vehicleNumber;
  const _FeatureGrid({
    Key? key,
    required this.cameras,
    required this.userId,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureItem(
        icon: Icons.speed,
        label: "Overspeed Detection",
        routeName: "/overspeed",
      ),
      _FeatureItem(
        icon: Icons.drive_eta,
        label: "Overtaking",
        routeName: "/overtaking",
      ),
      _FeatureItem(
        icon: Icons.threed_rotation, // Icon representing 3D functionality.
        label: "Map",
        routeName: "/map3d",
      ),
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        // Use shrinkWrap and disable scrolling for GridView.
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: features.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // Display 3 features per row.
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemBuilder: (context, index) {
          final item = features[index];
          return _FeatureCard(
            item: item,
            cameras: cameras,
            userId: userId,
            vehicleNumber: vehicleNumber,
          );
        },
      ),
    );
  }
}

/// Model for each feature.
class _FeatureItem {
  final IconData icon;
  final String label;
  final String routeName;

  _FeatureItem({
    required this.icon,
    required this.label,
    required this.routeName,
  });
}

/// Card widget for a single feature in the grid.
class _FeatureCard extends StatelessWidget {
  final _FeatureItem item;
  final List<CameraDescription> cameras;
  final String userId;
  final String vehicleNumber;
  const _FeatureCard({
    Key? key,
    required this.item,
    required this.cameras,
    required this.userId,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // If the feature is Overspeed Detection, pass the required arguments.
        if (item.routeName == '/overspeed') {
          Navigator.pushNamed(context, item.routeName, arguments: {
            'cameras': cameras,
            'userId': userId,
            'vehicleNumber': vehicleNumber,
          });
        } else {
          Navigator.pushNamed(context, item.routeName);
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon inside a circular container.
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              item.icon,
              size: 30,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

/// A horizontal list of “Popular Services” cards at the bottom.
class _PopularServicesList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final services = [
      "Service A",
      "Service B",
      "Service C",
      "Service D",
    ];

    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final service = services[index];
          return _ServiceCard(title: service);
        },
      ),
    );
  }
}

/// Card widget for each popular service.
class _ServiceCard extends StatelessWidget {
  final String title;
  const _ServiceCard({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.blue.shade50,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: SizedBox(
        width: 120,
        child: Center(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Custom Drawer to mimic the blue menu with icons.
class _CustomDrawer extends StatelessWidget {
  const _CustomDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: const Color(0xFF0E74E7), // Blue background.
        child: SafeArea(
          child: Column(
            children: [
              // Drawer Header.
              Container(
                height: 150,
                width: double.infinity,
                color: const Color(0xFF0E74E7),
                padding: const EdgeInsets.all(16.0),
                alignment: Alignment.centerLeft,
                child: const Text(
                  "Menu",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Drawer Items.
              _DrawerItem(
                icon: Icons.home,
                label: "Home",
                onTap: () {
                  Navigator.pop(context); // Close drawer.
                  Navigator.pushNamed(context, '/');
                },
              ),
              _DrawerItem(
                icon: Icons.info,
                label: "About",
                onTap: () {
                  // Implement About route or logic.
                },
              ),
              _DrawerItem(
                icon: Icons.settings,
                label: "Settings",
                onTap: () {
                  // Implement Settings route or logic.
                },
              ),
              _DrawerItem(
                icon: Icons.monetization_on,
                label: "Earnings",
                onTap: () {
                  // Implement Earnings route or logic.
                },
              ),
              _DrawerItem(
                icon: Icons.account_circle,
                label: "Profile",
                onTap: () {
                  Navigator.pushNamed(
                      context, '/profile'); // Implement Profile logic.
                },
              ),
              _DrawerItem(
                icon: Icons.contact_mail,
                label: "Contact",
                onTap: () {
                  // Implement Contact route or logic.
                },
              ),
              const Spacer(),
              // Logout at the bottom.
              _DrawerItem(
                icon: Icons.logout,
                label: "Logout",
                onTap: () {
                  // Implement logout logic.
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single row in the Drawer.
class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerItem({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(
        label,
        style: const TextStyle(color: Colors.white),
      ),
      onTap: onTap,
    );
  }
}
