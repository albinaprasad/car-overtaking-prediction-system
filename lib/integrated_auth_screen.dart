import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ---------------------------
/// Custom Wave Clipper
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
/// Integrated Authentication Screen
/// ---------------------------
class IntegratedAuthScreen extends StatefulWidget {
  const IntegratedAuthScreen({Key? key}) : super(key: key);

  @override
  State<IntegratedAuthScreen> createState() => _IntegratedAuthScreenState();
}

class _IntegratedAuthScreenState extends State<IntegratedAuthScreen> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2, // Two tabs: Admin and Owner
      child: Scaffold(
        appBar: AppBar(
          title: const Text("AEGIS Authentication"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Admin"),
              Tab(text: "Owner"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminAuthWidget(),
            OwnerAuthWidget(),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------
/// Admin Authentication Widget
/// ---------------------------
class AdminAuthWidget extends StatefulWidget {
  const AdminAuthWidget({Key? key}) : super(key: key);

  @override
  State<AdminAuthWidget> createState() => _AdminAuthWidgetState();
}

class _AdminAuthWidgetState extends State<AdminAuthWidget> {
  final TextEditingController adminUsernameController = TextEditingController();
  final TextEditingController adminPasswordController = TextEditingController();

  void _adminLogin() {
    final username = adminUsernameController.text.trim();
    final password = adminPasswordController.text.trim();

    // Hardcoded credentials: "admin" / "1234"
    if (username == "admin" && password == "1234") {
      Navigator.pushReplacementNamed(context, '/admin');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid admin credentials")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blue background.
        Container(color: const Color(0xFF1565C0)),
        // Wavy white clip at the top.
        Align(
          alignment: Alignment.topCenter,
          child: ClipPath(
            clipper: WaveClipper(),
            child: Container(
              color: Colors.white,
              height: MediaQuery.of(context).size.height * 0.5,
            ),
          ),
        ),
        // Form content.
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  const Text(
                    "Admin Login",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Enter admin credentials",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: adminUsernameController,
                    decoration: InputDecoration(
                      labelText: "Username",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: adminPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                      ),
                      onPressed: _adminLogin,
                      child: const Text(
                        "Log In as Admin",
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// ---------------------------
/// Owner Authentication Widget (Realtime Database)
/// ---------------------------
class OwnerAuthWidget extends StatefulWidget {
  const OwnerAuthWidget({Key? key}) : super(key: key);

  @override
  State<OwnerAuthWidget> createState() => _OwnerAuthWidgetState();
}

class _OwnerAuthWidgetState extends State<OwnerAuthWidget> {
  // Toggle to switch between Owner Login and Signup.
  bool isLogin = true;

  // Common controllers.
  final TextEditingController ownerEmailController = TextEditingController();
  final TextEditingController ownerPasswordController = TextEditingController();

  // Additional controllers for signup.
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController contactNumberController = TextEditingController();
  final TextEditingController vehicleRegController = TextEditingController();

  bool _isLoading = false;

  void _toggleOwnerAuthMode() {
    setState(() {
      isLogin = !isLogin;
    });
  }

  /// Owner Login using Firebase Realtime Database.
  Future<void> _ownerLogin() async {
    setState(() => _isLoading = true);
    try {
      final email = ownerEmailController.text.trim();
      final password = ownerPasswordController.text.trim();

      DatabaseReference usersRef = FirebaseDatabase.instance.ref("users");
      // Retrieve all user data.
      final snapshot = await usersRef.get();

      if (snapshot.exists) {
        final Map<dynamic, dynamic> users = snapshot.value as Map;
        String? foundUserId;
        String? foundVehicleReg;
        bool valid = false;
        users.forEach((key, value) {
          if (value['email'] == email && value['password'] == password) {
            valid = true;
            foundUserId = key;
            foundVehicleReg = value['vehicleRegNumber'];
          }
        });
        if (valid && foundUserId != null && foundVehicleReg != null) {
          // Save actual values using SharedPreferences.
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString("userId", foundUserId!);
          await prefs.setString("vehicleNumber", foundVehicleReg!);
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Incorrect email or password.")));
        }
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text("No user found.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Login failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Owner Signup: Create a new user record in Firebase Realtime Database.
  Future<void> _ownerSignup() async {
    setState(() => _isLoading = true);
    try {
      final email = ownerEmailController.text.trim();
      final password = ownerPasswordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();
      final fullName = fullNameController.text.trim();
      final contact = contactNumberController.text.trim();
      final vehicleReg = vehicleRegController.text.trim();

      if (password != confirmPassword) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Passwords do not match")),
        );
        return;
      }

      DatabaseReference usersRef = FirebaseDatabase.instance.ref("users");
      // Retrieve all users to check if the email already exists.
      final snapshot = await usersRef.get();
      if (snapshot.exists) {
        final Map<dynamic, dynamic> users = snapshot.value as Map;
        bool exists = false;
        users.forEach((key, value) {
          if (value['email'] == email) exists = true;
        });
        if (exists) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("That email is already in use.")));
          return;
        }
      }

      // Create a new user record using push() to generate a unique key.
      DatabaseReference newUserRef = usersRef.push();
      await newUserRef.set({
        "email": email,
        "password": password, // In production, store a hashed version!
        "fullName": fullName,
        "contactNumber": contact,
        "vehicleRegNumber": vehicleReg,
      });

      final userId = newUserRef.key;
      if (userId != null) {
        // Save actual values using SharedPreferences.
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString("userId", userId);
        await prefs.setString("vehicleNumber", vehicleReg);
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Signup failed: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Blue background.
        Container(color: const Color(0xFF1565C0)),
        // Wavy white clip at the top.
        Align(
          alignment: Alignment.topCenter,
          child: ClipPath(
            clipper: WaveClipper(),
            child: Container(
              color: Colors.white,
              height: MediaQuery.of(context).size.height * 0.5,
            ),
          ),
        ),
        // Main form content.
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: SizedBox(
              height: MediaQuery.of(context).size.height - 50,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 50),
                  Text(
                    isLogin ? "Owner Login" : "Create Owner Account",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLogin
                        ? "Log in with your email and password"
                        : "Sign up with your details",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 40),
                  if (!isLogin) ...[
                    // Full Name field (only for signup).
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
                  ],
                  // Email field.
                  TextField(
                    controller: ownerEmailController,
                    decoration: InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Password field.
                  TextField(
                    controller: ownerPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: "Password",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!isLogin) ...[
                    // Confirm Password field.
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Contact Number field.
                    TextField(
                      controller: contactNumberController,
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: "Contact Number",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Vehicle Registration Number field.
                    TextField(
                      controller: vehicleRegController,
                      decoration: InputDecoration(
                        labelText: "Vehicle Registration Number",
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: isLogin ? _ownerLogin : _ownerSignup,
                            child: Text(
                              isLogin ? "Log In" : "Sign Up",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                  const Spacer(),
                  // Toggle between Owner Login and Signup.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLogin
                            ? "Don't have an account?"
                            : "Already have an account?",
                      ),
                      TextButton(
                        onPressed: _toggleOwnerAuthMode,
                        child: Text(isLogin ? "Sign Up" : "Log In"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
