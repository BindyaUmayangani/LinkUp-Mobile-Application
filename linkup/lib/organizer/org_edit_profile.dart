import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrgEditProfileScreen extends StatefulWidget {
  const OrgEditProfileScreen({super.key});

  @override
  State<OrgEditProfileScreen> createState() => _OrgEditProfileScreenState();
}

class _OrgEditProfileScreenState extends State<OrgEditProfileScreen> {
  final orgNameController = TextEditingController();
  final emailController = TextEditingController();
  final contactController = TextEditingController();

  User? _user;
  File? _imageFile;
  String? _uploadedImageUrl;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      emailController.text = _user!.email ?? '';
      _loadCachedOrganizerData().then((_) {
        _fetchOrganizerDataFromFirestore();
      });
    }
  }

  Future<void> _loadCachedOrganizerData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      orgNameController.text = prefs.getString('orgName') ?? '';
      contactController.text = prefs.getString('contactNumber') ?? '';
      _uploadedImageUrl = prefs.getString('cachedProfileImageUrl');
    } catch (_) {}
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _cacheOrganizerData(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('orgName', data['orgName'] ?? '');
    await prefs.setString('contactNumber', data['contactNumber'] ?? '');
    if (data['profileImageUrl'] != null) {
      await prefs.setString('cachedProfileImageUrl', data['profileImageUrl']);
    }
  }

  Future<void> _fetchOrganizerDataFromFirestore() async {
    final doc = await FirebaseFirestore.instance.collection('organizers').doc(_user!.uid).get();
    if (doc.exists) {
      final data = doc.data()!;
      orgNameController.text = data['orgName'] ?? orgNameController.text;
      contactController.text = data['contactNumber'] ?? '';
      _uploadedImageUrl = data['profileImageUrl'];
      await _cacheOrganizerData(data);
      setState(() {});
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _uploadImageToCloudinary() async {
    if (_imageFile == null) return;

    const cloudName = 'do7drlcop';
    const uploadPreset = 'LinkUp';
    final url = 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(_imageFile!.path),
      'upload_preset': uploadPreset,
    });

    try {
      final response = await Dio().post(url, data: formData);
      if (response.statusCode == 200) {
        _uploadedImageUrl = response.data['secure_url'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cachedProfileImageUrl', _uploadedImageUrl ?? '');
        showSnackbar("Image uploaded successfully");
      } else {
        showSnackbar("Failed to upload image");
      }
    } catch (e) {
      showSnackbar("Upload error: $e");
    }
  }

  Future<void> updateOrganizerProfile() async {
    try {
      if (_imageFile != null) {
        await _uploadImageToCloudinary();
      }

      final updatedData = {
        'orgName': orgNameController.text.trim(),
        'contactNumber': contactController.text.trim(),
        'profileImageUrl': _uploadedImageUrl,
      };

      await FirebaseFirestore.instance
          .collection('organizers')
          .doc(_user!.uid)
          .set(updatedData, SetOptions(merge: true));

      await _cacheOrganizerData(updatedData);

      showSnackbar("Profile updated successfully");
      Navigator.pop(context);
    } catch (e) {
      showSnackbar("Error: $e");
    }
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        centerTitle: true,
        title: Text(
          'Edit Organizer Profile',
          style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundImage: _imageFile != null
                      ? FileImage(_imageFile!)
                      : (_uploadedImageUrl != null
                      ? NetworkImage(_uploadedImageUrl!)
                      : const AssetImage('assets/profile.jpg')) as ImageProvider,
                  child: _imageFile == null && _uploadedImageUrl == null
                      ? const Icon(Icons.camera_alt, size: 50, color: Colors.grey)
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(orgNameController.text, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.w600)),
              Text(emailController.text, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
              const SizedBox(height: 30),
              _buildTextField("Organization Name", orgNameController),
              const SizedBox(height: 16),
              _buildTextField("Email", emailController, enabled: false),
              const SizedBox(height: 16),
              _buildTextField("Contact Number", contactController),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Colors.blueAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Cancel',
                          style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.w500)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: updateOrganizerProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Update',
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, {bool enabled = true}) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
