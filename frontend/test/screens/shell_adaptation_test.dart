import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:map_my_friends/bloc/airport/airport_bloc.dart';
import 'package:map_my_friends/bloc/airport/airport_event.dart';
import 'package:map_my_friends/bloc/airport/airport_state.dart';
import 'package:map_my_friends/bloc/location/location_bloc.dart';
import 'package:map_my_friends/bloc/map/map_settings_cubit.dart';
import 'package:map_my_friends/bloc/people/people_bloc.dart';
import 'package:map_my_friends/bloc/profile/profile_bloc.dart';
import 'package:map_my_friends/bloc/profile/profile_event.dart';
import 'package:map_my_friends/bloc/profile/profile_state.dart';
import 'package:map_my_friends/bloc/station/station_bloc.dart';
import 'package:map_my_friends/bloc/station/station_state.dart';
import 'package:map_my_friends/bloc/trip/trip_bloc.dart';
import 'package:map_my_friends/bloc/trip/trip_event.dart';
import 'package:map_my_friends/bloc/trip/trip_state.dart';
import 'package:map_my_friends/main.dart';
import 'package:map_my_friends/utils/app_theme.dart';

class MockLocationBloc extends Mock implements LocationBloc {}

class MockPeopleBloc extends Mock implements PeopleBloc {}

class MockMapSettingsCubit extends Mock implements MapSettingsCubit {}

class MockProfileBloc extends Mock implements ProfileBloc {}

class MockAirportBloc extends Mock implements AirportBloc {}

class MockStationBloc extends Mock implements StationBloc {}

class MockTripBloc extends Mock implements TripBloc {}

/// Device classes this project actually ships to. The pair that matters is
/// phone portrait vs phone landscape: they are the same device, and only one
/// of them is narrow.
const _phonePortrait = Size(390, 844);
const _phoneLandscape = Size(844, 390);
const _smallPhoneLandscape = Size(667, 375);
const _tabletPortrait = Size(834, 1112);
const _tabletLandscape = Size(1112, 834);

void main() {
  late LocationBloc locationBloc;
  late PeopleBloc peopleBloc;
  late MapSettingsCubit mapSettingsCubit;
  late ProfileBloc profileBloc;
  late AirportBloc airportBloc;
  late StationBloc stationBloc;
  late TripBloc tripBloc;

  setUpAll(() {
    registerFallbackValue(LoadLocation());
    registerFallbackValue(LoadPeople());
    registerFallbackValue(LoadProfile());
    registerFallbackValue(LoadMapAirports());
    registerFallbackValue(const MapStationsLoaded([]));
    registerFallbackValue(const ClearTrip());
  });

  setUp(() {
    locationBloc = MockLocationBloc();
    peopleBloc = MockPeopleBloc();
    mapSettingsCubit = MockMapSettingsCubit();
    profileBloc = MockProfileBloc();
    airportBloc = MockAirportBloc();
    stationBloc = MockStationBloc();
    tripBloc = MockTripBloc();

    when(() => locationBloc.state).thenReturn(const LocationLoaded());
    when(
      () => locationBloc.stream,
    ).thenAnswer((_) => const Stream<LocationState>.empty());
    when(() => locationBloc.close()).thenAnswer((_) => Future.value());

    when(() => peopleBloc.state).thenReturn(const PeopleLoaded([]));
    when(
      () => peopleBloc.stream,
    ).thenAnswer((_) => const Stream<PeopleState>.empty());
    when(() => peopleBloc.close()).thenAnswer((_) => Future.value());

    when(() => mapSettingsCubit.state).thenReturn(const MapSettingsState());
    when(
      () => mapSettingsCubit.stream,
    ).thenAnswer((_) => const Stream<MapSettingsState>.empty());
    when(() => mapSettingsCubit.close()).thenAnswer((_) => Future.value());

    when(
      () => profileBloc.state,
    ).thenReturn(ProfileLoaded(username: 'test', email: 'test@test.com'));
    when(
      () => profileBloc.stream,
    ).thenAnswer((_) => const Stream<ProfileState>.empty());
    when(() => profileBloc.close()).thenAnswer((_) => Future.value());

    when(() => airportBloc.state).thenReturn(const MapAirportsLoaded([]));
    when(
      () => airportBloc.stream,
    ).thenAnswer((_) => const Stream<AirportState>.empty());
    when(() => airportBloc.close()).thenAnswer((_) => Future.value());

    when(() => stationBloc.state).thenReturn(const MapStationsLoaded([]));
    when(
      () => stationBloc.stream,
    ).thenAnswer((_) => const Stream<StationState>.empty());
    when(() => stationBloc.close()).thenAnswer((_) => Future.value());

    when(() => tripBloc.state).thenReturn(const TripState());
    when(
      () => tripBloc.stream,
    ).thenAnswer((_) => const Stream<TripState>.empty());
    when(() => tripBloc.close()).thenAnswer((_) => Future.value());
  });

  Future<void> pumpShell(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: locationBloc),
          BlocProvider.value(value: peopleBloc),
          BlocProvider.value(value: mapSettingsCubit),
          BlocProvider.value(value: profileBloc),
          BlocProvider.value(value: airportBloc),
          BlocProvider.value(value: stationBloc),
          BlocProvider.value(value: tripBloc),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const MainScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  for (final entry in <String, Size>{
    'phone portrait': _phonePortrait,
    'phone landscape': _phoneLandscape,
    'small phone landscape': _smallPhoneLandscape,
    'tablet portrait': _tabletPortrait,
    'tablet landscape': _tabletLandscape,
  }.entries) {
    testWidgets('shell lays out without overflow on ${entry.key}', (
      tester,
    ) async {
      await pumpShell(tester, entry.value);

      expect(
        tester.takeException(),
        isNull,
        reason: 'navigation overflowed at ${entry.value}',
      );
    });

    testWidgets('every destination is reachable on ${entry.key}', (
      tester,
    ) async {
      await pumpShell(tester, entry.value);
      final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;

      // The rail is a Positioned with only `left` and `top`, so it is
      // vertically unconstrained: it paints past the bottom edge instead of
      // reporting an overflow. Nothing throws, the tabs are simply gone.
      for (final label in ['Map', 'People', 'Pulse', 'Trips', 'Me']) {
        final finder = find.text(label);
        expect(finder, findsOneWidget, reason: '$label tab missing');

        final rect = tester.getRect(finder);
        expect(
          rect.bottom,
          lessThanOrEqualTo(viewport.height),
          reason:
              '$label tab is painted below the ${viewport.height}pt viewport '
              'at ${entry.value} — clipped, unreachable, and silent',
        );
        expect(
          rect.right,
          lessThanOrEqualTo(viewport.width),
          reason: '$label tab is painted past the right edge at ${entry.value}',
        );
      }
    });
  }

  // Visual inspection artefacts, not assertions — regenerated on demand with
  // --update-goldens and reviewed by eye.
  for (final entry in <String, Size>{
    'phone_portrait': _phonePortrait,
    'phone_landscape': _phoneLandscape,
    'tablet_portrait': _tabletPortrait,
    'tablet_landscape': _tabletLandscape,
  }.entries) {
    testWidgets('golden ${entry.key}', (tester) async {
      await pumpShell(tester, entry.value);
      await expectLater(
        find.byType(MainScreen),
        matchesGoldenFile('goldens/shell_${entry.key}.png'),
      );
    });
  }
}
