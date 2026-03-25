import 'dart:io';

import 'package:calendar/screens/memo_screen.dart';
import 'package:calendar/screens/select_family_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import 'calendar_screen.dart';
import 'login_screen.dart';
import 'voice_memo_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();

  static const bgColor = Color(0xFFF8F7F6);
  static const primaryColor = Color(0xFF0F172A);
  static const accentColor = Color(0xFFE2B736);
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _isUploadingPhoto = false;

  String _fullName = 'User';
  String _familyName = 'No Family';
  String _photoURL = '';

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      String fullName = 'User';
      String photoURL = '';
      String familyName = 'No Family';

      if (userDoc.exists) {
        final data = userDoc.data();

        if (data != null) {
          fullName = (data['fullName'] ?? 'User').toString();
          photoURL = (data['photoURL'] ?? '').toString();
        }
      }

      final familySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('families')
          .limit(1)
          .get();

      if (familySnapshot.docs.isNotEmpty) {
        final familyData = familySnapshot.docs.first.data();
        familyName =
            (familyData['familyName'] ?? familyData['name'] ?? 'My Family')
                .toString();
      }

      if (!mounted) return;
      setState(() {
        _fullName = fullName;
        _photoURL = photoURL;
        _familyName = familyName;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load user info: $e')),
      );
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = true;
      });

      final String fileName =
          'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(currentUser.uid)
          .child('avatars')
          .child(fileName);

      UploadTask uploadTask;

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        final file = File(pickedFile.path);
        uploadTask = storageRef.putFile(
          file,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .set({
        'photoURL': downloadUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        _photoURL = downloadUrl;
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload avatar: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SettingsScreen.bgColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildProfileSection(),
                        _buildSettingsList(),
                        _buildLogOutButton(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildBottomNav(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFAF2).withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFFF3EEE0),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.arrow_back, size: 20, color: Colors.black54),
              ),
            ),
          ),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: SettingsScreen.primaryColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildProfileSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickAndUploadAvatar,
                child: Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SettingsScreen.accentColor,
                      width: 4,
                    ),
                    color: const Color(0xFFE8B4A8),
                  ),
                  child: ClipOval(
                    child: _isLoading
                        ? const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Stack(
                      fit: StackFit.expand,
                      children: [
                        _photoURL.isNotEmpty
                            ? Image.network(
                          _photoURL,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return const Center(
                              child: Icon(
                                Icons.person,
                                size: 60,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                            : const Center(
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                        if (_isUploadingPhoto)
                          Container(
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: _isUploadingPhoto ? null : _pickAndUploadAvatar,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: SettingsScreen.accentColor,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: SettingsScreen.bgColor,
                      width: 4,
                    ),
                  ),
                  child: const Center(
                    child: Icon(Icons.edit, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _isLoading ? 'Loading...' : _fullName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: SettingsScreen.primaryColor,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _isLoading ? '' : _familyName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: SettingsScreen.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildSettingItem('Account Details', Icons.person),
                Divider(
                  color: const Color(0xFFF1F5F9),
                  height: 1,
                  indent: 56,
                  endIndent: 20,
                ),
                _buildSettingItem('Notifications', Icons.notifications),
                Divider(
                  color: const Color(0xFFF1F5F9),
                  height: 1,
                  indent: 56,
                  endIndent: 20,
                ),
                _buildSettingItem('Family Members', Icons.people),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogOutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: GestureDetector(
        onTap: () async {
          await FirebaseAuth.instance.signOut();
          if (!mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
          );
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(
                Icons.logout,
                size: 18,
                color: Color(0xFF475569),
              ),
              SizedBox(width: 8),
              Text(
                'Log Out',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingItem(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SettingsScreen.accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(48),
            ),
            child: Center(
              child: Icon(
                icon,
                size: 16,
                color: SettingsScreen.accentColor,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: SettingsScreen.primaryColor,
              ),
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios,
            size: 12,
            color: Color(0xFF64748B),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 16, 25, 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.8),
        border: const Border(
          top: BorderSide(color: Color(0xFFF1F5F9)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _navItem(
            context,
            Icons.chat_bubble_outline,
            'Memo',
            selected: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const MemoScreen()),
              );
            },
          ),
          _navItem(
            context,
            Icons.people,
            'Family',
            selected: false,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SelectFamilyScreen()),
            ),
          ),
          _navItem(
            context,
            Icons.calendar_today,
            'Today',
            selected: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            },
          ),
          _navItem(
            context,
            Icons.settings,
            'Settings',
            selected: true,
            onTap: null,
          ),
        ],
      ),
    );
  }

  Widget _navItem(
      BuildContext context,
      IconData icon,
      String label, {
        bool selected = false,
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 20,
            color: selected
                ? SettingsScreen.accentColor
                : const Color(0xFF94A3B8),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? SettingsScreen.accentColor
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }
}