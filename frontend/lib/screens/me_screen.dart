import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/location/location_bloc.dart';

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
      appBar: AppBar(title: const Text('Me')),
      body: BlocListener<LocationBloc, LocationState>(
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Location loaded')));
            // Could fill address fields via reverse geocoding here
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                BlocBuilder<LocationBloc, LocationState>(
                  builder: (context, state) {
                    if (state is LocationLoading) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return ElevatedButton.icon(
                      onPressed: () {
                        context.read<LocationBloc>().add(RequestPermission());
                      },
                      icon: const Icon(Icons.location_searching),
                      label: const Text('Use Current Location'),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'My Address',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _cityController,
                  decoration: const InputDecoration(
                    labelText: 'City (Required)',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _stateController,
                  decoration: const InputDecoration(
                    labelText: 'State (Required)',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _countryController,
                  decoration: const InputDecoration(
                    labelText: 'Country (Required)',
                  ),
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Required' : null,
                ),
                TextFormField(
                  controller: _streetController,
                  decoration: const InputDecoration(
                    labelText: 'Street Address (Optional)',
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      context.read<LocationBloc>().add(
                        UpdateUserAddress(
                          city: _cityController.text,
                          state: _stateController.text,
                          country: _countryController.text,
                          street: _streetController.text.isNotEmpty
                              ? _streetController.text
                              : null,
                        ),
                      );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Address Saved')),
                      );
                    }
                  },
                  child: const Text('Save Address'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
