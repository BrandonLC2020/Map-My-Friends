import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/person.dart';
import '../bloc/people/people_bloc.dart';

class AddEditPersonScreen extends StatefulWidget {
  final Person? person;

  const AddEditPersonScreen({super.key, this.person});

  @override
  State<AddEditPersonScreen> createState() => _AddEditPersonScreenState();
}

class _AddEditPersonScreenState extends State<AddEditPersonScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _tagController;
  late TextEditingController _cityController;
  late TextEditingController _stateController;
  late TextEditingController _countryController;
  late TextEditingController _streetController;
  late TextEditingController _phoneController;
  DateTime? _birthday; // Handling date

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

  void _save() {
    if (_formKey.currentState!.validate()) {
      final person = Person(
        id:
            widget.person?.id ??
            '', // ID handled by backend if empty string? Or maybe omit. Backend likely assigns ID.
        // If ID is empty, backend assigns. But here we need to know if update or add.
        // If widget.person is not null, update.
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
        latitude: widget.person?.latitude, // Should ideally geocode the address
        longitude: widget.person?.longitude,
      );

      if (widget.person != null) {
        context.read<PeopleBloc>().add(UpdatePerson(person));
      } else {
        context.read<PeopleBloc>().add(AddPerson(person));
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
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
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
                initialValue: _tagController.text.isNotEmpty
                    ? _tagController.text
                    : 'FRIEND',
                items: const [
                  DropdownMenuItem(value: 'FRIEND', child: Text('Friend')),
                  DropdownMenuItem(value: 'FAMILY', child: Text('Family')),
                ],
                onChanged: (val) => setState(() => _tagController.text = val!),
                decoration: const InputDecoration(
                  labelText: 'Relationship Tag',
                ),
              ),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: 'City (Required)'),
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
              ElevatedButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
  }
}
