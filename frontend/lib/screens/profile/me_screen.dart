import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../bloc/location/location_bloc.dart';
import '../../bloc/profile/profile_bloc.dart';
import '../../bloc/profile/profile_event.dart';
import '../../bloc/profile/profile_state.dart';
import '../../components/shared/image_editor_modal.dart';

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
  }

  @override
  void dispose() {
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _streetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MultiBlocListener(
          listeners: [
            BlocListener<LocationBloc, LocationState>(
              listener: (context, state) {
                if (state is LocationPermissionDenied) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location permission denied')),
                  );
                } else if (state is LocationPermissionDeniedForever) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Location permission denied forever'),
                    ),
                  );
                } else if (state is LocationLoaded) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location loaded')),
                  );
                }
              },
            ),
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
                    maxWidth: isDesktop ? 500 : double.infinity,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: BlocBuilder<ProfileBloc, ProfileState>(
                        builder: (context, profileState) {
                          return ListView(
                            children: [
                              // Profile Picture Section
                              Center(
                                child: Stack(
                                  children: [
                                    _buildProfileAvatar(profileState),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        radius: 18,
                                        backgroundColor: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                        child: profileState is ProfileUpdating
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                            : IconButton(
                                                icon: Icon(
                                                  Icons.camera_alt,
                                                  size: 18,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.onPrimary,
                                                ),
                                                onPressed:
                                                    _showImageSourceDialog,
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              BlocBuilder<LocationBloc, LocationState>(
                                builder: (context, state) {
                                  if (state is LocationLoading) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return ElevatedButton.icon(
                                    onPressed: () {
                                      context.read<LocationBloc>().add(
                                        RequestPermission(),
                                      );
                                    },
                                    icon: const Icon(Icons.location_searching),
                                    label: const Text('Use Current Location'),
                                  );
                                },
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'My Address',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _cityController,
                                decoration: const InputDecoration(
                                  labelText: 'City (Required)',
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              TextFormField(
                                controller: _stateController,
                                decoration: const InputDecoration(
                                  labelText: 'State (Required)',
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              TextFormField(
                                controller: _countryController,
                                decoration: const InputDecoration(
                                  labelText: 'Country (Required)',
                                ),
                                validator: (value) =>
                                    value == null || value.isEmpty
                                    ? 'Required'
                                    : null,
                              ),
                              TextFormField(
                                controller: _streetController,
                                decoration: const InputDecoration(
                                  labelText: 'Street Address (Optional)',
                                ),
                              ),
                              const SizedBox(height: 20),
                              ElevatedButton(
                                onPressed: profileState is ProfileUpdating
                                    ? null
                                    : () {
                                        if (_formKey.currentState!.validate()) {
                                          context.read<ProfileBloc>().add(
                                            UpdateProfile(
                                              city: _cityController.text,
                                              state: _stateController.text,
                                              country: _countryController.text,
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
                                              content: Text('Address Saved'),
                                            ),
                                          );
                                        }
                                      },
                                child: profileState is ProfileUpdating
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Save Address'),
                              ),
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

    return CircleAvatar(
      radius: 60,
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      backgroundImage: backgroundImage,
      child: backgroundImage == null
          ? Icon(
              Icons.person,
              size: 60,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            )
          : null,
    );
  }
}
