import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// ---------------------------
/// Custom Wave Clipper (from your signup page)
/// ---------------------------
class WaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    // Start from top-left, go to 80% of the height.
    path.lineTo(0, size.height * 0.8);
    // Create first smooth curve.
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height,
      size.width * 0.5,
      size.height * 0.8,
    );
    // Create second smooth curve.
    path.quadraticBezierTo(
      size.width * 0.75,
      size.height * 0.6,
      size.width,
      size.height * 0.8,
    );
    // Line to top-right.
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(WaveClipper oldClipper) => false;
}

/// ---------------------------
/// User Profile Screen
/// ---------------------------
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref("users");
  String? userId;

  // Controllers for profile fields.
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController contactController = TextEditingController();
  final TextEditingController vehicleRegController = TextEditingController();

  // For profile picture path (stored locally).
  String? profilePicUrl;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  /// Load the user ID from SharedPreferences.
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getString("userId");
    });
    if (userId != null) {
      _loadUserData();
    }
  }

  /// Fetch user data from the Realtime Database.
  Future<void> _loadUserData() async {
    final snapshot = await _userRef.child(userId!).get();
    if (snapshot.exists) {
      final data = snapshot.value as Map;
      setState(() {
        fullNameController.text = data['fullName'] ?? "";
        emailController.text = data['email'] ?? "";
        contactController.text = data['contactNumber'] ?? "";
        vehicleRegController.text = data['vehicleRegNumber'] ?? "";
        profilePicUrl = data['profilePicUrl'] ?? "";
      });
    }
  }

  /// Update profile data in the Realtime Database.
  Future<void> _updateProfile() async {
    setState(() {
      _isLoading = true;
    });
    final updates = {
      "fullName": fullNameController.text.trim(),
      "email": emailController.text.trim(),
      "contactNumber": contactController.text.trim(),
      "vehicleRegNumber": vehicleRegController.text.trim(),
      "profilePicUrl": profilePicUrl ?? "",
    };

    await _userRef.child(userId!).update(updates);
    setState(() {
      _isLoading = false;
    });
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Profile updated")));
  }

  /// Pick an image from the gallery and store it in the device's local storage.
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final file = File(pickedFile.path);
      // Get the app's documents directory.
      final appDir = await getApplicationDocumentsDirectory();
      // Create a local copy of the image file.
      final localImagePath = '${appDir.path}/profilePic_$userId.jpg';
      final localFile = await file.copy(localImagePath);

      setState(() {
        profilePicUrl = localFile.path;
      });
      // Update the local image path in the Realtime Database.
      await _userRef.child(userId!).update({"profilePicUrl": localFile.path});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar with pink theme.
      appBar: AppBar(
        title: const Text("User Profile"),
        backgroundColor: Colors.pink,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  // Wavy header with profile picture.
                  ClipPath(
                    clipper: WaveClipper(),
                    child: Container(
                      height: 200,
                      color: Colors.pink,
                      child: Center(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundImage: (profilePicUrl != null &&
                                      profilePicUrl!.isNotEmpty)
                                  ? FileImage(File(profilePicUrl!))
                                  : const AssetImage("assets/default_avatar.jpg")
                                      as ImageProvider,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Colors.white,
                                  child: Icon(
                                    Icons.edit,
                                    color: Colors.pink,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // User details form.
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // You can leave the other fields unchanged if needed.
                        TextField(
                          controller: fullNameController,
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: "Email",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: contactController,
                          decoration: InputDecoration(
                            labelText: "Contact Number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Vehicle number is displayed but set as read-only.
                        TextField(
                          controller: vehicleRegController,
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: "Vehicle Registration Number",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            helperText:
                                "This field cannot be changed for security reasons.",
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              backgroundColor: Colors.pink,
                            ),
                            onPressed: _updateProfile,
                            child: const Text(
                              "Save Profile",
                              style: TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
