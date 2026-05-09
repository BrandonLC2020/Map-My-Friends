import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:map_my_friends/bloc/trip/trip_bloc.dart';
import 'package:map_my_friends/bloc/trip/trip_event.dart';
import 'package:map_my_friends/bloc/trip/trip_state.dart';
import 'package:map_my_friends/components/map/map_bottom_sheets.dart';
import 'package:map_my_friends/models/airport.dart';
import 'package:map_my_friends/models/station.dart';

class MockTripBloc extends Mock implements TripBloc {}

void main() {
  late TripBloc tripBloc;

  setUpAll(() {
    registerFallbackValue(const ClearTrip());
  });

  setUp(() {
    tripBloc = MockTripBloc();
    when(() => tripBloc.state).thenReturn(const TripState());
    when(() => tripBloc.stream).thenAnswer((_) => Stream<TripState>.empty());
    when(() => tripBloc.close()).thenAnswer((_) => Future.value());
  });

  group('AirportBottomSheet', () {
    final airport = Airport(
      name: 'San Francisco International Airport',
      iataCode: 'SFO',
      city: 'San Francisco',
      country: 'USA',
      latitude: 37.6213,
      longitude: -122.3790,
      airportType: 'large_airport',
    );

    testWidgets('renders airport information correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: tripBloc,
              child: AirportBottomSheet(airport: airport),
            ),
          ),
        ),
      );

      expect(find.text('San Francisco International Airport'), findsOneWidget);
      expect(find.text('SFO'), findsOneWidget);
      expect(find.text('San Francisco, USA'), findsOneWidget);
      expect(find.text('International Airport'), findsOneWidget);
    });

    testWidgets('Add to Trip button dispatches AddAirportStop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: tripBloc,
              child: AirportBottomSheet(airport: airport),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add to Trip'));
      verify(() => tripBloc.add(any(that: isA<AddAirportStop>()))).called(1);
    });
  });

  group('StationBottomSheet', () {
    final station = Station(
      name: 'Grand Central Terminal',
      osmId: 123,
      city: 'New York',
      country: 'USA',
      latitude: 40.7527,
      longitude: -73.9772,
      stationType: 'major_station',
      uicRef: '8000001',
    );

    testWidgets('renders station information correctly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: tripBloc,
              child: StationBottomSheet(station: station),
            ),
          ),
        ),
      );

      expect(find.text('Grand Central Terminal'), findsOneWidget);
      expect(find.text('Ref: 8000001'), findsOneWidget);
      expect(find.text('New York, USA'), findsOneWidget);
      expect(find.text('Major Station'), findsOneWidget);
    });

    testWidgets('Add to Trip button dispatches AddStationStop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: BlocProvider.value(
              value: tripBloc,
              child: StationBottomSheet(station: station),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add to Trip'));
      verify(() => tripBloc.add(any(that: isA<AddStationStop>()))).called(1);
    });
  });
}
