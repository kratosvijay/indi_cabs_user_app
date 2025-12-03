import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project_taxi_with_ai/widgets/snackbar.dart';
import 'package:project_taxi_with_ai/widgets/pro_library.dart';

class ProfilePage extends StatefulWidget {
  final User user;
  const ProfilePage({super.key, required this.user});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _imageFile;
  bool _isLoading = false;
  bool _isEmailReadOnly = false;
  bool _hasChanges = false; // Track if changes exist

  // Store initial values to compare against
  String _initialFirstName = '';
  String _initialLastName = '';
  String _initialEmail = '';

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Add listeners to check for changes
    _firstNameController.addListener(_checkForChanges);
    _lastNameController.addListener(_checkForChanges);
    _emailController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    final hasChanges =
        _firstNameController.text.trim() != _initialFirstName ||
        _lastNameController.text.trim() != _initialLastName ||
        _emailController.text.trim() != _initialEmail ||
        _imageFile != null;

    if (_hasChanges != hasChanges) {
      setState(() {
        _hasChanges = hasChanges;
      });
    }
  }

  Future<void> _loadUserData() async {
    await widget.user.reload();
    final freshUser = FirebaseAuth.instance.currentUser!;

    // Check for social login providers or verified email
    if (freshUser.emailVerified) {
      _isEmailReadOnly = true;
      if (mounted) {
        // Show snackbar after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          displaySnackBar(context, "Email Verified", isError: false);
        });
      }
    } else {
      for (final provider in freshUser.providerData) {
        if (provider.providerId == 'google.com' ||
            provider.providerId == 'apple.com') {
          _isEmailReadOnly = true;
          break;
        }
      }
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(freshUser.uid)
        .get();
    if (userDoc.exists) {
      final userData = userDoc.data() as Map<String, dynamic>;
      _initialFirstName = userData['firstName'] ?? '';
      _initialLastName = userData['lastName'] ?? '';
      _initialEmail = userData['email'] ?? '';

      _firstNameController.text = _initialFirstName;
      _lastNameController.text = _initialLastName;
      _emailController.text = _initialEmail;
      _phoneController.text = userData['phoneNumber'] ?? '';
    } else {
      _initialEmail = freshUser.email ?? '';
      _emailController.text = _initialEmail;
      _phoneController.text = freshUser.phoneNumber ?? '';
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _showImageSourceDialog() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Select Image Source"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Camera"),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery"),
              onTap: () {
                Get.back();
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 50,
    );
    if (pickedFile != null) {
      setState(() {
        _imageFile = pickedFile;
      });
      _checkForChanges(); // Check for changes after picking image
    }
  }

  Future<String?> _uploadProfilePicture() async {
    if (_imageFile == null) return null;

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${widget.user.uid}.jpg');

      await ref.putFile(File(_imageFile!.path));
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) displaySnackBar(context, "Failed to upload image: $e");
      return null;
    }
  }

  Future<void> _updateProfile() async {
    if (!_hasChanges) return; // Prevent update if no changes

    setState(() => _isLoading = true);

    try {
      String? photoURL;
      if (_imageFile != null) {
        photoURL = await _uploadProfilePicture();
      }

      await widget.user.updateDisplayName(
        '${_firstNameController.text} ${_lastNameController.text}',
      );
      if (photoURL != null) {
        await widget.user.updatePhotoURL(photoURL);
      }

      final userDoc = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid);
      final Map<String, dynamic> dataToUpdate = {
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        // Only update email if it's not read-only
        if (!_isEmailReadOnly) 'email': _emailController.text.trim(),
      };
      if (photoURL != null) {
        dataToUpdate['photoURL'] = photoURL;
      }
      await userDoc.set(dataToUpdate, SetOptions(merge: true));

      await FirebaseAuth.instance.currentUser?.reload();

      if (mounted) {
        displaySnackBar(
          context,
          "Profile updated successfully!",
          isError: false,
        );
        // Return true to indicate successful update
        Get.back(result: true);
      }
    } catch (e) {
      if (mounted) displaySnackBar(context, "Failed to update profile: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser ?? widget.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: const ProAppBar(titleText: "Edit Profile"),
      body: FadeInSlide(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // --- Header with Gradient & Avatar ---
              Stack(
                alignment: Alignment.bottomCenter,
                clipBehavior: Clip.none,
                children: [
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [Colors.black, const Color(0xFF2C2C2C)]
                            : [Colors.blueAccent, Colors.blue.shade800],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    child: Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 4,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 60,
                            backgroundColor: Colors.grey.shade800,
                            backgroundImage: _imageFile != null
                                ? FileImage(File(_imageFile!.path))
                                : (currentUser.photoURL != null
                                          ? NetworkImage(currentUser.photoURL!)
                                          : null)
                                      as ImageProvider?,
                            child:
                                _imageFile == null &&
                                    currentUser.photoURL == null
                                ? Icon(
                                    Icons.person,
                                    size: 60,
                                    color: Colors.grey.shade400,
                                  )
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.blueAccent,
                              border: Border.all(
                                color: Theme.of(
                                  context,
                                ).scaffoldBackgroundColor,
                                width: 3,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                size: 20,
                                color: Colors.white,
                              ),
                              onPressed: _showImageSourceDialog,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 70), // Space for the overlapping avatar
              // --- Form Fields ---
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLabel("First Name"),
                    ProTextField(
                      controller: _firstNameController,
                      hintText: 'Enter your first name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Last Name"),
                    ProTextField(
                      controller: _lastNameController,
                      hintText: 'Enter your last name',
                      icon: Icons.person_outline,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel(
                      _isEmailReadOnly ? "Email (Not Editable)" : "Email",
                    ),
                    ProTextField(
                      controller: _emailController,
                      hintText: 'Enter your email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      readOnly: _isEmailReadOnly,
                    ),
                    const SizedBox(height: 20),
                    _buildLabel("Mobile Number (Not Editable)"),
                    ProTextField(
                      controller: _phoneController,
                      hintText: '',
                      icon: Icons.phone,
                      readOnly: true,
                    ),
                    const SizedBox(height: 40),
                    ProButton(
                      text: "Save Changes",
                      isLoading: _isLoading,
                      // Disable button if no changes
                      onPressed: _hasChanges ? _updateProfile : null,
                      // Grey out background if disabled
                      backgroundColor: _hasChanges
                          ? null // Use default gradient
                          : (isDark
                                ? Colors.grey.shade800
                                : Colors.grey.shade300),
                      // Grey out text if disabled
                      textColor: _hasChanges
                          ? Colors.white
                          : (isDark
                                ? Colors.grey.shade500
                                : Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Theme.of(
            context,
          ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}
