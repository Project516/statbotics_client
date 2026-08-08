import 'dart:convert';

import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:statbotics_client/statbotics_client.dart';
import 'package:http/testing.dart';

/// Builds the JSON object Statbotics returns for a single match, with the
/// [team_keys] form the v3 API actually uses for alliances.
Map<String, dynamic> _matchJson(
  String key,
  String compLevel,
  int matchNumber,
  List<int> redTeams,
  List<int> blueTeams,
) {
  return <String, dynamic>{
    'key': key,
    'event': '2026mrcmp',
    'match_number': matchNumber,
    'comp_level': compLevel,
    'alliances': <String, dynamic>{
      'red': <String, dynamic>{
        'team_keys': redTeams,
        'surrogate_team_keys': const <int>[],
        'dq_team_keys': const <int>[],
      },
      'blue': <String, dynamic>{
        'team_keys': blueTeams,
        'surrogate_team_keys': const <int>[],
        'dq_team_keys': const <int>[],
      },
    },
  };
}

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

    test('StatboticsTeamEvent reads the nickname team_events carries', () {
      // The only event-scoped source of names: /teams ignores its `event`
      // parameter and answers with the global list.
      final te = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 3847,
        'event': '2026txhou',
        'event_name': 'Houston',
        'team_name': 'Spectrum',
        'year': 2026,
        'wins': 1,
        'losses': 0,
        'ties': 0,
        'epa': <String, dynamic>{},
      });
      expect(te.teamName, 'Spectrum');
    });

    test('StatboticsTeamEvent without a team_name reads as empty', () {
      final te = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 3847,
        'event': '2026txhou',
        'year': 2026,
        'wins': 0,
        'losses': 0,
        'ties': 0,
        'epa': <String, dynamic>{},
      });
      expect(te.teamName, isEmpty);
    });

    test('StatboticsTeamEvent.toJson round-trips team_name', () {
      // toJson advertised a round-trip for the on-device last-good cache, but
      // omitted team_name, so a cached StatboticsTeamEvent came back with an
      // empty nickname. The cache key Statbotics itself does not store is the
      // one event-scoped name source (/teams ignores its event param), so the
      // loss was silent.
      final original = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 3847,
        'event': '2026txhou',
        'event_name': 'Houston',
        'team_name': 'Spectrum',
        'year': 2026,
        'wins': 1,
        'losses': 0,
        'ties': 0,
        'rank': 7,
        'num_teams': 42,
        'epa': <String, dynamic>{
          'total_points': <String, dynamic>{'mean': 41.2, 'sd': 2.9},
          'auto_points': <String, dynamic>{'mean': 9.5},
        },
      });
      final restored = StatboticsTeamEvent.fromJson(original.toJson());
      expect(restored.teamName, 'Spectrum');
      expect(restored.team, 3847);
      expect(restored.event, '2026txhou');
      expect(restored.eventName, 'Houston');
      expect(restored.year, 2026);
      expect(restored.wins, 1);
      expect(restored.losses, 0);
      expect(restored.ties, 0);
      expect(restored.rank, 7);
      expect(restored.numTeams, 42);
      expect(restored.epa.totalPointsMean, closeTo(41.2, 0.01));
      expect(restored.epa.autoPointsMean, closeTo(9.5, 0.01));
    });

    test('StatboticsTeamEvent.toJson round-trips an empty team_name', () {
      final original = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 111,
        'event': '2026x',
        'event_name': 'X',
        'year': 2026,
        'wins': 0,
        'losses': 0,
        'ties': 0,
        'epa': <String, dynamic>{},
      });
      final restored = StatboticsTeamEvent.fromJson(original.toJson());
      expect(restored.teamName, isEmpty);
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

    test('StatboticsMatch.displayName formats every comp level consistently',
        () {
      // Every known FRC comp level uses its conventional two-letter
      // abbreviation; qualification matches collapse to "Q<number>".
      // Unknown levels fall through to "<LEVEL><n>" in upper case so a
      // future level never silently renders lower case.
      matchOf(String level, int n) =>
          StatboticsMatch.fromJson(<String, dynamic>{
            'key': '2026x_$level$n',
            'event': '2026x',
            'match_number': n,
            'comp_level': level,
            'alliances': const <String, dynamic>{},
          });
      expect(matchOf('qm', 12).displayName, 'Q12');
      expect(matchOf('ef', 2).displayName, 'EF2');
      expect(matchOf('qf', 3).displayName, 'QF3');
      expect(matchOf('sf', 1).displayName, 'SF1');
      expect(matchOf('f', 2).displayName, 'F2');
      expect(matchOf('xx', 5).displayName, 'XX5');
      expect(matchOf('qm', 1).isQualification, isTrue);
    });

    // The year is a server-side query parameter, not a client-side filter, so
    // the assertions here are the request URL and the ordering of what comes
    // back.
    test('getEvents requests the year and sorts by week then name', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.statbotics.io/v3/events?year=2026&limit=500',
        );
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            // Deliberately out of order: a later-week event first, then a
            // null-week event, then an earlier-week event sharing a week with
            // another entry to exercise the secondary name sort.
            <String, dynamic>{
              'key': '2026txhou',
              'name': 'Houston District',
              'year': 2026,
              'week': 4,
            },
            <String, dynamic>{
              'key': '2026off',
              'name': 'Off-Season Demo',
              'year': 2026,
              // week omitted -> null, must sort after every numbered week.
            },
            <String, dynamic>{
              'key': '2026nyfl',
              'name': 'Finger Lakes Regional',
              'year': 2026,
              'week': 2,
            },
            <String, dynamic>{
              'key': '2026azpx',
              'name': 'A high-desert Event',
              'year': 2026,
              'week': 2,
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final client = StatboticsClient(httpClient: mockClient);
      final events = await client.getEvents(2026);

      expect(events.length, 4);
      // Sorted by week ascending, then name; null week sorts last.
      expect(events[0].key, '2026azpx'); // week 2, "A high-desert Event"
      expect(events[1].key, '2026nyfl'); // week 2, "Finger Lakes Regional"
      expect(events[2].key, '2026txhou'); // week 4
      expect(events[3].key, '2026off'); // null week -> end
      expect(events[3].week, isNull);
    });

    test('getEvents returns empty list on 404', () async {
      final client = StatboticsClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
      );
      final events = await client.getEvents(2026);
      expect(events, isEmpty);
    });

    test('getEventMatches parses list and sorts by comp level then number',
        () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.statbotics.io/v3/matches?event=2026mrcmp&limit=200',
        );
        expect(request.url.queryParameters['event'], '2026mrcmp');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            _matchJson('2026mrcmp_qf2', 'qf', 2, [1, 2, 3], [4, 5, 6]),
            _matchJson('2026mrcmp_qm75', 'qm', 75, [7, 8, 9], [10, 11, 12]),
            _matchJson('2026mrcmp_f1', 'f', 1, [13, 14, 15], [16, 17, 18]),
            _matchJson('2026mrcmp_qf1', 'qf', 1, [19, 20, 21], [22, 23, 24]),
            _matchJson('2026mrcmp_sf1', 'sf', 1, [25, 26, 27], [28, 29, 30]),
            _matchJson('2026mrcmp_ef1', 'ef', 1, [31, 32, 33], [34, 35, 36]),
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final client = StatboticsClient(httpClient: mockClient);
      final matches = await client.getEventMatches('2026mrcmp');

      expect(matches.length, 6);
      // qm < ef < qf < sf < f, then by match number within a level.
      expect(matches[0].key, '2026mrcmp_qm75');
      expect(matches[1].key, '2026mrcmp_ef1');
      expect(matches[2].key, '2026mrcmp_qf1');
      expect(matches[3].key, '2026mrcmp_qf2');
      expect(matches[4].key, '2026mrcmp_sf1');
      expect(matches[5].key, '2026mrcmp_f1');
      expect(matches.first.redTeams, [7, 8, 9]);
      expect(matches.last.isQualification, isFalse);
    });

    test('getEventMatches returns empty list on 404', () async {
      final client = StatboticsClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
      );
      final matches = await client.getEventMatches('9999xxx');
      expect(matches, isEmpty);
    });

    test('getEventTeamsBasic parses the basic team list', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.statbotics.io/v3/teams?event=2026mrcmp&limit=100',
        );
        expect(request.url.queryParameters['event'], '2026mrcmp');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'team': 2714,
              'name': 'Mech Tech',
              'country': 'USA',
            },
            <String, dynamic>{
              'team': 1234,
              'name': 'Example Robotics',
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final client = StatboticsClient(httpClient: mockClient);
      final teams = await client.getEventTeamsBasic('2026mrcmp');

      expect(teams.length, 2);
      expect(teams[0].team, 2714);
      expect(teams[0].nickname, 'Mech Tech');
      expect(teams[1].nickname, 'Example Robotics');
    });

    test('getEventTeamsBasic returns an empty list when the endpoint fails',
        () async {
      // The basic-team endpoint is best-effort: a non-transient error from the
      // API must not bubble up, it must degrade to an empty list.
      var calls = 0;
      final mockClient = MockClient((_) async {
        calls++;
        return http.Response('forbidden', 403);
      });
      final client = StatboticsClient(
        httpClient: mockClient,
        sleep: (_) async {},
      );
      final teams = await client.getEventTeamsBasic('2026mrcmp');
      expect(teams, isEmpty);
      // 403 is not transient, so the request is attempted exactly once.
      expect(calls, 1);
    });

    test('getEventTeamsBasic swallows a malformed response with an empty list',
        () async {
      // A truncated/garbled body would throw during jsonDecode; the handler
      // catches that and reports no teams rather than crashing callers.
      final mockClient = MockClient(
        (_) async => http.Response('not json at all', 200),
      );
      final client = StatboticsClient(httpClient: mockClient);
      final teams = await client.getEventTeamsBasic('2026mrcmp');
      expect(teams, isEmpty);
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
