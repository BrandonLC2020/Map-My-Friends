import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../../components/shared/image_editor_modal.dart';
import '../../components/shared/custom_text_form_field.dart';
import '../../bloc/auth/auth_bloc.dart';
import '../../bloc/auth/auth_event.dart';
import '../settings/settings_screen.dart';

class MeScreen extends StatefulWidget {
  const MeScreen({super.key});

  @override
  State<MeScreen> createState() => _MeScreenState();
}

class _MeScreenState extends State<MeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _countryController = TextEditingController();
  final _streetController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _imagePicker = ImagePicker();
  Uint8List?
  _localImageBytes; // For showing local image immediately after picking

  @override
  void initState() {
    super.initState();
    // Load profile when screen loads
    context.read<ProfileBloc>().add(LoadProfile());
  }

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1024, // Increased to allow better quality potential for zoom
      maxHeight: 1024,
      imageQuality: 90,
    );

    if (pickedFile != null && mounted) {
      final bytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      // Open editor
      // ignore: use_build_context_synchronously
      final Uint8List? croppedBytes = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ImageEditorModal(imageBytes: bytes, isCircular: true),
        ),
      );

      if (croppedBytes != null) {
        setState(() {
          _localImageBytes = croppedBytes;
        });

        // Upload to server
        // We need to pass the bytes, or save to a file first.
        // The UploadProfileImage event takes an XFile.
        // We can create an XFile from bytes.
        final tempFile = XFile.fromData(
          croppedBytes,
          name: 'profile_image.png',
          mimeType: 'image/png',
        );

        if (mounted) {
          context.read<ProfileBloc>().add(UploadProfileImage(image: tempFile));
        }
      }
    }
  }

  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _populateFieldsFromProfile(ProfileLoaded state) {
    if (_cityController.text.isEmpty && state.city != null) {
      _cityController.text = state.city!;
    }
    if (_stateController.text.isEmpty && state.state != null) {
      _stateController.text = state.state!;
    }
    if (_countryController.text.isEmpty && state.country != null) {
      _countryController.text = state.country!;
    }
    if (_streetController.text.isEmpty && state.street != null) {
      _streetController.text = state.street!;
    }
    if (_firstNameController.text.isEmpty && state.firstName != null) {
      _firstNameController.text = state.firstName!;
    }
    if (_lastNameController.text.isEmpty && state.lastName != null) {
      _lastNameController.text = state.lastName!;
    }
    if (_phoneNumberController.text.isEmpty && state.phoneNumber != null) {
      _phoneNumberController.text = state.phoneNumber!;
    }
    if (_birthDateController.text.isEmpty && state.birthDate != null) {
      _birthDateController.text = state.birthDate!;
    }
  }

  @override
  void dispose() {
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _streetController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneNumberController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<ProfileBloc, ProfileState>(
              listener: (context, state) {
                if (state is ProfileLoaded) {
                  _populateFieldsFromProfile(state);
                  // Clear local image path once server image is loaded
                  if (state.profileImageUrl != null) {
                    setState(() {
                      _localImageBytes = null;
                    });
                  }
                } else if (state is ProfileError) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(state.message)));
                }
              },
            ),
          ],
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 600;

              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isDesktop ? 600 : double.infinity,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 32.0,
                    ),
                    child: Form(
                      key: _formKey,
                      child: BlocBuilder<ProfileBloc, ProfileState>(
                        builder: (context, profileState) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Profile Picture Section
                              Center(
                                child: Stack(
                                  children: [
                                    _buildProfileAvatar(profileState),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: Theme.of(
                                              context,
                                            ).scaffoldBackgroundColor,
                                            width: 2,
                                          ),
                                        ),
                                        child: InkWell(
                                          onTap: profileState is ProfileUpdating
                                              ? null
                                              : _showImageSourceDialog,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.all(8.0),
                                            child:
                                                profileState is ProfileUpdating
                                                ? const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : Icon(
                                                    Icons.camera_alt,
                                                    size: 20,
                                                    color: Theme.of(
                                                      context,
                                                    ).colorScheme.onPrimary,
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'Personal Info',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: CustomTextFormField(
                                      controller: _firstNameController,
                                      labelText: 'First Name',
                                      prefixIcon: const Icon(
                                        Icons.person_outline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextFormField(
                                      controller: _lastNameController,
                                      labelText: 'Last Name',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              CustomTextFormField(
                                controller: _phoneNumberController,
                                labelText: 'Phone Number',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: 16),
                              CustomTextFormField(
                                controller: _birthDateController,
                                labelText: 'Birth Date (YYYY-MM-DD)',
                                prefixIcon: const Icon(Icons.cake_outlined),
                                keyboardType: TextInputType.datetime,
                                readOnly: true,
                                onTap: () async {
                                  FocusScope.of(
                                    context,
                                  ).requestFocus(FocusNode());
                                  final date = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        DateTime.tryParse(
                                          _birthDateController.text,
                                        ) ??
                                        DateTime.now(),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (date != null) {
                                    _birthDateController.text =
                                        "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
                                  }
                                },
                              ),
                              const SizedBox(height: 32),
                              Text(
                                'My Address',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),

                              CustomTextFormField(
                                controller: _streetController,
                                labelText: 'Street Address (Optional)',
                                prefixIcon: const Icon(Icons.home_outlined),
                              ),
                              const SizedBox(height: 16),

                              CustomTextFormField(
                                controller: _cityController,
                                labelText: 'City (Required)',
                                prefixIcon: const Icon(Icons.location_city),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'City is required'
                                    : null,
                              ),
                              const SizedBox(height: 16),

                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: CustomTextFormField(
                                      controller: _stateController,
                                      labelText: 'State (Required)',
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: CustomTextFormField(
                                      controller: _countryController,
                                      labelText: 'Country (Required)',
                                      validator: (value) =>
                                          value == null || value.isEmpty
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 32),

                              SizedBox(
                                height: 50,
                                child: FilledButton(
                                  onPressed: profileState is ProfileUpdating
                                      ? null
                                      : () {
                                          if (_formKey.currentState!
                                              .validate()) {
                                            context.read<ProfileBloc>().add(
                                              UpdateProfile(
                                                firstName:
                                                    _firstNameController
                                                        .text
                                                        .isNotEmpty
                                                    ? _firstNameController.text
                                                    : null,
                                                lastName:
                                                    _lastNameController
                                                        .text
                                                        .isNotEmpty
                                                    ? _lastNameController.text
                                                    : null,
                                                phoneNumber:
                                                    _phoneNumberController
                                                        .text
                                                        .isNotEmpty
                                                    ? _phoneNumberController
                                                          .text
                                                    : null,
                                                birthDate:
                                                    _birthDateController
                                                        .text
                                                        .isNotEmpty
                                                    ? _birthDateController.text
                                                    : null,
                                                city: _cityController.text,
                                                state: _stateController.text,
                                                country:
                                                    _countryController.text,
                                                street:
                                                    _streetController
                                                        .text
                                                        .isNotEmpty
                                                    ? _streetController.text
                                                    : null,
                                              ),
                                            );
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text('Profile Saved'),
                                                behavior:
                                                    SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        },
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: profileState is ProfileUpdating
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          'Save Profile',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                height: 50,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    context.read<AuthBloc>().add(
                                      LogoutRequested(),
                                    );
                                  },
                                  icon: const Icon(
                                    Icons.logout,
                                    color: Colors.red,
                                  ),
                                  label: const Text(
                                    'Logout',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(
                                      color: Colors.red,
                                      width: 2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(
                                height: 120,
                              ), // Bottom padding for navigation bar
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(ProfileState profileState) {
    ImageProvider? backgroundImage;

    // Priority: local image (just picked) > server image
    if (_localImageBytes != null) {
      backgroundImage = MemoryImage(_localImageBytes!);
    } else if (profileState is ProfileLoaded &&
        profileState.profileImageUrl != null) {
      backgroundImage = NetworkImage(profileState.profileImageUrl!);
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: 4,
        ),
        shape: BoxShape.circle,
      ),
      child: CircleAvatar(
        radius: 64,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        backgroundImage: backgroundImage,
        child: backgroundImage == null
            ? Icon(
                Icons.person,
                size: 64,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
      ),
    );
  }
}
