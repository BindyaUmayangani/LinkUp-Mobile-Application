import 'dart:convert'; // For JSON encode/decode
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// In‑memory cache to hold the profile data during the app session.
class ProfileDataCache {
  static Map<String, dynamic>? userData;
  static String? profileImageUrl;
}

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  User? _user;
  Map<String, dynamic>? _userData;
  String? _profileImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _loadCachedData().then((_) {
      // If no in-memory cache exists, fetch data from Firestore
      if (ProfileDataCache.userData == null && _user != null) {
        _loadProfile();
      } else {
        _userData = ProfileDataCache.userData;
        _profileImageUrl = ProfileDataCache.profileImageUrl;
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  /// Loads cached profile data from SharedPreferences.
  Future<void> _loadCachedData() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedData = prefs.getString('cachedProfileData');
    if (cachedData != null && cachedData.isNotEmpty) {
      final Map<String, dynamic> data = json.decode(cachedData);
      _userData = data;
      _profileImageUrl = data['profileImageUrl'];
      ProfileDataCache.userData = data;
      ProfileDataCache.profileImageUrl = _profileImageUrl;
    }
  }

  /// Fetches profile data from Firestore and updates both in-memory and persistent caches.
  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_user!.uid)
          .get();

      if (doc.exists) {
        _userData = doc.data();
        _profileImageUrl = _userData!['profileImageUrl'] ?? '';

        // Update in-memory cache
        ProfileDataCache.userData = _userData;
        ProfileDataCache.profileImageUrl = _profileImageUrl;

        // Update SharedPreferences cache with JSON encoded data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedProfileData', json.encode(_userData));
        await prefs.setString('cachedProfileImageUrl', _profileImageUrl!);

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Profile load error: $e");
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildDetail(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        const SizedBox(height: 5),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
            color: Colors.grey.shade100,
          ),
          child: Text(value, style: const TextStyle(fontSize: 15)),
        ),
        const SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = _userData?['fullName'] ?? '';
    final email = _user?.email ?? '';
    final phone = _userData?['contactNumber'] ?? '';
    final gender = _userData?['gender'] ?? '';
    final birthDate = _userData?['birthDate'] ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('My Profile', style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Profile Picture using CachedNetworkImageProvider for proper caching
            CircleAvatar(
              radius: 50,
              backgroundImage: _profileImageUrl != null && _profileImageUrl!.isNotEmpty
                  ? CachedNetworkImageProvider(_profileImageUrl!)
                  : const AssetImage('assets/profile.jpg') as ImageProvider,
            ),
            const SizedBox(height: 15),
            // Name & Email
            Text(name,
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(email, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 25),
            // Details
            _buildDetail("Contact Number", phone),
            _buildDetail("Gender", gender),
            _buildDetail("Birth Date", birthDate),
            const SizedBox(height: 20),
            // Change Password Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                );
              },
              icon: const Icon(Icons.lock_outline, color: Colors.white),
              label: const Text("Change Password",
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully")),
        );
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong.";
      if (e.code == 'wrong-password') {
        message = "Current password is incorrect.";
      } else if (e.code == 'weak-password') {
        message = "New password is too weak.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Change Password"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text("Enter your current and new password", style: TextStyle(fontSize: 16)),
              const SizedBox(height: 25),
              TextFormField(
                controller: _currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val != null && val.length < 6
                    ? 'Password must be at least 6 characters'
                    : null,
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val != _newPasswordController.text
                    ? 'Passwords do not match'
                    : null,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    _changePassword();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.lock_reset),
                label: const Text("Update Password"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
