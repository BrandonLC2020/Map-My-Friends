import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'bloc/location/location_bloc.dart';
import 'bloc/people/people_bloc.dart';
import 'services/api_service.dart';
import 'screens/map_screen.dart';
import 'screens/people_screen.dart';
import 'screens/me_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize ApiService singleton
    final apiService = ApiService();

    return MultiBlocProvider(
      providers: [
        BlocProvider<LocationBloc>(
          create: (context) => LocationBloc()..add(LoadLocation()),
        ),
        BlocProvider<PeopleBloc>(
          create: (context) =>
              PeopleBloc(apiService: apiService)..add(LoadPeople()),
        ),
      ],
      child: MaterialApp(
        title: 'Map My Friends',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const MainScreen(),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  Widget _getScreen(int index) {
    switch (index) {
      case 0:
        return const MapScreen();
      case 1:
        return const PeopleScreen();
      case 2:
        return const MeScreen();
      default:
        return const MapScreen();
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 600;

        if (isDesktop) {
          // Desktop layout with NavigationRail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.all,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.map_outlined),
                      selectedIcon: Icon(Icons.map),
                      label: Text('Map'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.people_outline),
                      selectedIcon: Icon(Icons.people),
                      label: Text('People'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: Text('Me'),
                    ),
                  ],
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(child: _getScreen(_selectedIndex)),
              ],
            ),
          );
        } else {
          // Mobile layout with BottomNavigationBar
          return Scaffold(
            body: _getScreen(_selectedIndex),
            bottomNavigationBar: BottomNavigationBar(
              items: const <BottomNavigationBarItem>[
                BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Map'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.people),
                  label: 'People',
                ),
                BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Me'),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.blue,
              onTap: _onItemTapped,
            ),
          );
        }
      },
    );
  }
}
