import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/person.dart';
import '../../bloc/people/people_bloc.dart';
import '../../components/shared/image_editor_modal.dart';

class AddEditPersonScreen extends StatefulWidget {
  final Person? person;

  const AddEditPersonScreen({super.key, this.person});

  @override
  State<AddEditPersonScreen> createState() => _AddEditPersonScreenState();
}

class _AddEditPersonScreenState extends State<AddEditPersonScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _tagController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _streetController;
  late TextEditingController _phoneController;
  DateTime? _birthday;
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _existingImageUrl;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.person?.firstName ?? '',
    );
    _lastNameController = TextEditingController(
      text: widget.person?.lastName ?? '',
    );
    _tagController = TextEditingController(
      text: widget.person?.relationshipTag ?? 'FRIEND',
    );
    _cityController = TextEditingController(text: widget.person?.city ?? '');
    _stateController = TextEditingController(text: widget.person?.state ?? '');
    _countryController = TextEditingController(
      text: widget.person?.country ?? '',
    );
    _streetController = TextEditingController(
      text: widget.person?.street ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.person?.phoneNumber ?? '',
    );
    _birthday = widget.person?.birthday;
    _existingImageUrl = widget.person?.profileImageUrl;
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _tagController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _countryController.dispose();
    _streetController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
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
            _selectedImageBytes = croppedBytes;
            // Create XFile from bytes for the bloC event later
            _selectedImage = XFile.fromData(
              croppedBytes,
              name: 'person_image.png',
              mimeType: 'image/png',
            );
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
      }
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            if (_selectedImage != null || _existingImageUrl != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Remove Photo',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                    _selectedImageBytes = null;
                    _existingImageUrl = null;
                  });
                },
              ),
          ],
        ),
      ),
    );
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final person = Person(
        id: widget.person?.id ?? '',
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        relationshipTag: _tagController.text,
        city: _cityController.text,
        state: _stateController.text,
        country: _countryController.text,
        street: _streetController.text.isNotEmpty
            ? _streetController.text
            : null,
        phoneNumber: _phoneController.text.isNotEmpty
            ? _phoneController.text
            : null,
        birthday: _birthday,
        latitude: widget.person?.latitude,
        longitude: widget.person?.longitude,
        profileImageUrl: _existingImageUrl,
      );

      if (widget.person != null) {
        context.read<PeopleBloc>().add(
          UpdatePerson(person, profileImage: _selectedImage),
        );
      } else {
        context.read<PeopleBloc>().add(
          AddPerson(person, profileImage: _selectedImage),
        );
      }
      Navigator.pop(context);
    }
  }

  void _delete() {
    if (widget.person != null) {
      context.read<PeopleBloc>().add(DeletePerson(widget.person!.id));
      Navigator.pop(context);
    }
  }

  Widget _buildProfileImagePicker() {
    return Center(
      child: GestureDetector(
        onTap: _showImagePickerOptions,
        child: Stack(
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: Colors.grey[300],
              backgroundImage: _selectedImageBytes != null
                  ? MemoryImage(_selectedImageBytes!)
                  : (_existingImageUrl != null
                            ? NetworkImage(_existingImageUrl!)
                            : null)
                        as ImageProvider?,
              child: (_selectedImageBytes == null && _existingImageUrl == null)
                  ? Icon(Icons.person, size: 60, color: Colors.grey[600])
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.person != null ? 'Edit Person' : 'Add Person'),
        actions: [
          if (widget.person != null)
            IconButton(icon: const Icon(Icons.delete), onPressed: _delete),
        ],
      ),
      body: LayoutBuilder(
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
                  child: ListView(
                    children: [
                      _buildProfileImagePicker(),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _firstNameController,
                        decoration: const InputDecoration(
                          labelText: 'First Name (Required)',
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _lastNameController,
                        decoration: const InputDecoration(
                          labelText: 'Last Name (Required)',
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: _tagController.text.isNotEmpty
                            ? _tagController.text
                            : 'FRIEND',
                        items: const [
                          DropdownMenuItem(
                            value: 'FRIEND',
                            child: Text('Friend'),
                          ),
                          DropdownMenuItem(
                            value: 'FAMILY',
                            child: Text('Family'),
                          ),
                        ],
                        onChanged: (val) =>
                            setState(() => _tagController.text = val!),
                        decoration: const InputDecoration(
                          labelText: 'Relationship Tag',
                        ),
                      ),
                      TextFormField(
                        controller: _cityController,
                        decoration: const InputDecoration(
                          labelText: 'City (Required)',
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _stateController,
                        decoration: const InputDecoration(
                          labelText: 'State (Required)',
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _countryController,
                        decoration: const InputDecoration(
                          labelText: 'Country (Required)',
                        ),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Required' : null,
                      ),
                      TextFormField(
                        controller: _streetController,
                        decoration: const InputDecoration(
                          labelText: 'Street Address (Optional)',
                        ),
                      ),
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone Number (Optional)',
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      ListTile(
                        title: Text(
                          _birthday == null
                              ? 'Birthday (Optional)'
                              : 'Birthday: ${_birthday!.toLocal().toString().split(' ')[0]}',
                        ),
                        trailing: const Icon(Icons.calendar_today),
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _birthday ?? DateTime.now(),
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) setState(() => _birthday = date);
                        },
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _save,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
