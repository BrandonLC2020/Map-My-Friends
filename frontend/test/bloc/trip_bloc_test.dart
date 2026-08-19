import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:mocktail/mocktail.dart';
import 'package:map_my_friends/bloc/trip/trip_bloc.dart';
import 'package:map_my_friends/bloc/trip/trip_event.dart';
import 'package:map_my_friends/bloc/trip/trip_state.dart';
import 'package:map_my_friends/models/person.dart';
import 'package:map_my_friends/models/trip.dart';
import 'package:map_my_friends/services/routing_service.dart';
import 'package:map_my_friends/services/api_service.dart';

class MockRoutingService extends Mock implements RoutingService {}

class MockApiService extends Mock implements ApiService {}

void main() {
  late RoutingService routingService;
  late ApiService apiService;
  late TripBloc tripBloc;

  final testPerson = Person(
    id: '1',
    firstName: 'Test',
    lastName: 'User',
    relationshipTag: 'Friend',
    city: 'City',
    state: 'State',
    country: 'Country',
    latitude: 10.0,
    longitude: 10.0,
  );

  setUpAll(() {
    registerFallbackValue(const TripState());
    registerFallbackValue(testPerson);
    registerFallbackValue(
      AddStop(
        Person(
          id: '0',
          firstName: '',
          lastName: '',
          relationshipTag: '',
          city: '',
          state: '',
          country: '',
        ),
      ),
    );
    registerFallbackValue(
      Trip(name: 'Test Trip', date: DateTime.now(), stops: const []),
    );
  });

  setUp(() {
    routingService = MockRoutingService();
    apiService = MockApiService();
    tripBloc = TripBloc(routingService: routingService, apiService: apiService);

    // Default mock behavior
    when(() => routingService.getRoute(any())).thenAnswer((_) async => []);
  });

  tearDown(() {
    tripBloc.close();
  });

  group('TripBloc', () {
    test('initial state is empty TripState', () {
      expect(tripBloc.state, const TripState());
    });

    blocTest<TripBloc, TripState>(
      'AddStop updates state and triggers routing',
      build: () => tripBloc,
      act: (bloc) => bloc.add(AddStop(testPerson)),
      expect: () => [
        predicate<TripState>(
          (state) => state.stops.length == 1 && state.isOptimizing,
        ),
        predicate<TripState>(
          (state) => state.stops.length == 1 && !state.isOptimizing,
        ),
      ],
      verify: (_) {
        verify(() => routingService.getRoute(any())).called(1);
      },
    );

    blocTest<TripBloc, TripState>(
      'ClearTrip resets state',
      build: () => tripBloc,
      seed: () => TripState(
        stops: [TripStop(location: const LatLng(0, 0), sequenceOrder: 0)],
        routePoints: const [LatLng(0, 0)],
      ),
      act: (bloc) => bloc.add(const ClearTrip()),
      expect: () => [const TripState()],
    );

    blocTest<TripBloc, TripState>(
      'FetchUserTrips emits [isLoading: true, isLoading: false] with trips',
      build: () {
        when(() => apiService.getTrips()).thenAnswer((_) async => []);
        return tripBloc;
      },
      act: (bloc) => bloc.add(const FetchUserTrips()),
      expect: () => [
        const TripState(isLoading: true),
        const TripState(isLoading: false, userTrips: []),
      ],
    );

    blocTest<TripBloc, TripState>(
      'SaveTrip (new) calls apiService.createTrip and emits success',
      build: () {
        final savedTrip = Trip(
          id: '123',
          name: 'Saved',
          date: DateTime.now(),
          stops: [],
        );
        when(
          () => apiService.createTrip(any()),
        ).thenAnswer((_) async => savedTrip);
        when(() => apiService.getTrips()).thenAnswer((_) async => [savedTrip]);
        return tripBloc;
      },
      act: (bloc) =>
          bloc.add(const SaveTrip(name: 'New Trip', status: TripStatus.draft)),
      expect: () => [
        const TripState(isLoading: true),
        predicate<TripState>(
          (state) => !state.isLoading && state.currentTripId == '123',
        ),
        predicate<TripState>(
          (state) => state.isLoading && state.currentTripId == '123',
        ),
        predicate<TripState>(
          (state) =>
              !state.isLoading &&
              state.currentTripId == '123' &&
              state.userTrips.isNotEmpty,
        ),
      ],
    );

    blocTest<TripBloc, TripState>(
      'LoadTrip updates stops and fetches route',
      build: () => tripBloc,
      act: (bloc) {
        final trip = Trip(
          id: '456',
          name: 'Existing',
          date: DateTime.now(),
          stops: [TripStop(location: const LatLng(1, 1), sequenceOrder: 0)],
        );
        bloc.add(LoadTrip(trip));
      },
      expect: () => [
        predicate<TripState>(
          (state) => state.isLoading && state.currentTripId == '456',
        ),
        predicate<TripState>(
          (state) => !state.isLoading && state.currentTripId == '456',
        ),
      ],
      verify: (_) {
        verify(() => routingService.getRoute(any())).called(1);
      },
    );
  });
}
