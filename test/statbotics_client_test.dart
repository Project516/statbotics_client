import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:statbotics_client/statbotics_client.dart';
import 'package:http/testing.dart';

void main() {
  group('StatboticsClient', () {
    test('getEvent parses event fields', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.statbotics.io/v3/event/2026mrcmp',
        );
        return http.Response(
          jsonEncode(<String, dynamic>{
            'key': '2026mrcmp',
            'name': 'Mid-Atlantic Championship',
            'year': 2026,
            'week': 8,
            'country': 'USA',
            'state': 'PA',
          }),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final client = StatboticsClient(httpClient: mockClient);
      final event = await client.getEvent('2026mrcmp');

      expect(event, isNotNull);
      expect(event!.key, '2026mrcmp');
      expect(event.name, 'Mid-Atlantic Championship');
      expect(event.year, 2026);
      expect(event.week, 8);
    });

    test('getEvent returns null on 404', () async {
      final client = StatboticsClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
      );
      final event = await client.getEvent('9999xxx');
      expect(event, isNull);
    });

    test('getEvent throws StatboticsApiException on non-200/404', () async {
      final client = StatboticsClient(
        httpClient: MockClient((_) async => http.Response('server error', 500)),
      );
      expect(
        () => client.getEvent('2026mrcmp'),
        throwsA(isA<StatboticsApiException>()),
      );
    });

    test('getEventTeams parses list and sorts by rank', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          contains('api.statbotics.io/v3/team_events'),
        );
        expect(request.url.queryParameters['event'], '2026mrcmp');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'team': 2714,
              'event': '2026mrcmp',
              'event_name': 'Mid-Atlantic Championship',
              'year': 2026,
              'wins': 8,
              'losses': 4,
              'ties': 0,
              'rank': 2,
              'num_teams': 40,
              'epa': <String, dynamic>{
                'total_points': <String, dynamic>{'mean': 42.1, 'sd': 3.0},
              },
            },
            <String, dynamic>{
              'team': 1234,
              'event': '2026mrcmp',
              'event_name': 'Mid-Atlantic Championship',
              'year': 2026,
              'wins': 10,
              'losses': 2,
              'ties': 0,
              'rank': 1,
              'num_teams': 40,
              'epa': <String, dynamic>{
                'total_points': <String, dynamic>{'mean': 48.5, 'sd': 2.8},
              },
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final client = StatboticsClient(httpClient: mockClient);
      final teams = await client.getEventTeams('2026mrcmp');

      expect(teams.length, 2);
      // Sorted by rank ascending: rank 1 first.
      expect(teams[0].team, 1234);
      expect(teams[0].rank, 1);
      expect(teams[0].epa.totalPointsMean, closeTo(48.5, 0.01));
      expect(teams[0].record, '10-2');
      expect(teams[1].team, 2714);
      expect(teams[1].rank, 2);
    });

    test('getEventTeams returns empty list on 404', () async {
      final client = StatboticsClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
      );
      final teams = await client.getEventTeams('9999xxx');
      expect(teams, isEmpty);
    });

    test('StatboticsTeamEvent.record omits ties when zero', () {
      final te = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 1234,
        'event': 'test',
        'event_name': 'Test',
        'year': 2026,
        'wins': 6,
        'losses': 3,
        'ties': 0,
        'epa': <String, dynamic>{},
      });
      expect(te.record, '6-3');
    });

    test('StatboticsTeamEvent.record includes ties when non-zero', () {
      final te = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 1234,
        'event': 'test',
        'event_name': 'Test',
        'year': 2026,
        'wins': 5,
        'losses': 3,
        'ties': 1,
        'epa': <String, dynamic>{},
      });
      expect(te.record, '5-3-1');
    });

    test('StatboticsEpa handles missing sub-fields gracefully', () {
      final te = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 999,
        'event': 'test',
        'event_name': 'Test',
        'year': 2026,
        'wins': 0,
        'losses': 0,
        'ties': 0,
        'epa': <String, dynamic>{},
      });
      expect(te.epa.totalPointsMean, isNull);
    });

    test('StatboticsMatch parses team_keys from alliances', () {
      final match = StatboticsMatch.fromJson(<String, dynamic>{
        'key': '2025miket_qm1',
        'event': '2025miket',
        'match_number': 1,
        'comp_level': 'qm',
        'alliances': <String, dynamic>{
          'red': <String, dynamic>{
            'team_keys': <int>[4998, 5260, 3534],
            'surrogate_team_keys': <int>[],
            'dq_team_keys': <int>[],
          },
          'blue': <String, dynamic>{
            'team_keys': <int>[2137, 9776, 9207],
            'surrogate_team_keys': <int>[],
            'dq_team_keys': <int>[],
          },
        },
      });
      expect(match.redTeams, [4998, 5260, 3534]);
      expect(match.blueTeams, [2137, 9776, 9207]);
      expect(match.displayName, 'Q1');
    });

    test('retries a transient 500 then succeeds (#496)', () async {
      var calls = 0;
      final mockClient = MockClient((request) async {
        calls++;
        if (calls < 3) return http.Response('upstream error', 500);
        return http.Response(
          jsonEncode(<String, dynamic>{'key': '2026x', 'name': 'X'}),
          200,
        );
      });
      final client = StatboticsClient(
        httpClient: mockClient,
        sleep: (_) async {},
      );
      final event = await client.getEvent('2026x');
      expect(calls, 3);
      expect(event?.key, '2026x');
    });

    test('gives up after maxAttempts and throws on persistent 500', () async {
      var calls = 0;
      final mockClient = MockClient((_) async {
        calls++;
        return http.Response('nope', 500);
      });
      final client = StatboticsClient(
        httpClient: mockClient,
        maxAttempts: 3,
        sleep: (_) async {},
      );
      await expectLater(
        client.getEvent('2026x'),
        throwsA(isA<StatboticsApiException>()),
      );
      expect(calls, 3);
    });

    test('does not retry a 404 (returns null immediately)', () async {
      var calls = 0;
      final mockClient = MockClient((_) async {
        calls++;
        return http.Response('missing', 404);
      });
      final client = StatboticsClient(
        httpClient: mockClient,
        sleep: (_) async {},
      );
      expect(await client.getEvent('nope'), isNull);
      expect(calls, 1);
    });

    test('StatboticsTeamBasic uses name field not nickname', () {
      final team = StatboticsTeamBasic.fromJson(<String, dynamic>{
        'team': 1234,
        'name': 'Example',
        'country': 'USA',
        'state': 'PA',
      });
      expect(team.team, 1234);
      expect(team.nickname, 'Example');
    });
  });
}
