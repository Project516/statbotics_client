import 'dart:convert';
import 'dart:io';

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
              'record': <String, dynamic>{
                'qual': <String, dynamic>{'rank': 2, 'num_teams': 40},
                'total': <String, dynamic>{'wins': 8, 'losses': 4, 'ties': 0},
              },
              'epa': <String, dynamic>{
                'total_points': 42.1,
              },
            },
            <String, dynamic>{
              'team': 1234,
              'event': '2026mrcmp',
              'event_name': 'Mid-Atlantic Championship',
              'year': 2026,
              'record': <String, dynamic>{
                'qual': <String, dynamic>{'rank': 1, 'num_teams': 40},
                'total': <String, dynamic>{'wins': 10, 'losses': 2, 'ties': 0},
              },
              'epa': <String, dynamic>{
                'total_points': 48.5,
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
      expect(teams[0].epa.totalPoints, closeTo(48.5, 0.01));
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
        'record': <String, dynamic>{
          'total': <String, dynamic>{'wins': 1, 'losses': 0, 'ties': 0},
        },
        'epa': <String, dynamic>{},
      });
      expect(te.teamName, 'Spectrum');
    });

    test('StatboticsTeamEvent without a team_name reads as empty', () {
      final te = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 3847,
        'event': '2026txhou',
        'year': 2026,
        'record': <String, dynamic>{
          'total': <String, dynamic>{'wins': 0, 'losses': 0, 'ties': 0},
        },
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
        'record': <String, dynamic>{
          'qual': <String, dynamic>{'rank': 7, 'num_teams': 42},
          'total': <String, dynamic>{'wins': 1, 'losses': 0, 'ties': 0},
        },
        'epa': <String, dynamic>{
          'total_points': 41.2,
          'unitless': 1710.0,
          'norm': 1655.0,
          'breakdown': <String, dynamic>{'auto_points': 9.5},
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
      expect(restored.epa.totalPoints, closeTo(41.2, 0.01));
      expect(restored.epa.autoPoints, closeTo(9.5, 0.01));
    });

    test('StatboticsTeamEvent.toJson round-trips an empty team_name', () {
      final original = StatboticsTeamEvent.fromJson(<String, dynamic>{
        'team': 111,
        'event': '2026x',
        'event_name': 'X',
        'year': 2026,
        'record': <String, dynamic>{
          'total': <String, dynamic>{'wins': 0, 'losses': 0, 'ties': 0},
        },
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
        'record': <String, dynamic>{
          'total': <String, dynamic>{'wins': 6, 'losses': 3, 'ties': 0},
        },
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
        'record': <String, dynamic>{
          'total': <String, dynamic>{'wins': 5, 'losses': 3, 'ties': 1},
        },
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
        'record': <String, dynamic>{
          'total': <String, dynamic>{'wins': 0, 'losses': 0, 'ties': 0},
        },
        'epa': <String, dynamic>{},
      });
      expect(te.epa.totalPoints, isNull);
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

    test('getTeamEvents parses the history and sorts newest season first',
        () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.statbotics.io/v3/team_events?team=254&limit=1000',
        );
        expect(request.url.queryParameters['team'], '254');
        expect(request.url.queryParameters['limit'], '1000');
        return http.Response(
          jsonEncode(<Map<String, dynamic>>[
            <String, dynamic>{
              'team': 254,
              'event': '2024cafr',
              'event_name': 'Cal Games',
              'team_name': 'The Cheesy Poofs',
              'year': 2024,
              'record': <String, dynamic>{
                'qual': <String, dynamic>{'rank': 1, 'num_teams': 40},
                'total': <String, dynamic>{'wins': 9, 'losses': 1, 'ties': 0},
              },
              'epa': <String, dynamic>{
                'total_points': 55.0,
              },
            },
            <String, dynamic>{
              'team': 254,
              'event': '2023cafr',
              'event_name': 'Cal Games',
              'team_name': 'The Cheesy Poofs',
              'year': 2023,
              'record': <String, dynamic>{
                'qual': <String, dynamic>{'rank': 2, 'num_teams': 40},
                'total': <String, dynamic>{'wins': 8, 'losses': 2, 'ties': 0},
              },
              'epa': <String, dynamic>{
                'total_points': 50.0,
              },
            },
            <String, dynamic>{
              'team': 254,
              'event': '2024txaus',
              'event_name': 'Austin',
              'team_name': 'The Cheesy Poofs',
              'year': 2024,
              'record': <String, dynamic>{
                'qual': <String, dynamic>{'rank': 3, 'num_teams': 38},
                'total': <String, dynamic>{'wins': 7, 'losses': 3, 'ties': 0},
              },
              'epa': <String, dynamic>{
                'total_points': 52.0,
              },
            },
          ]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final client = StatboticsClient(httpClient: mockClient);
      final history = await client.getTeamEvents(254);

      expect(history.length, 3);
      // Newest season first, then event key ascending within a season.
      expect(history[0].year, 2024);
      expect(history[0].event, '2024cafr');
      expect(history[0].teamName, 'The Cheesy Poofs');
      expect(history[1].year, 2024);
      expect(history[1].event, '2024txaus');
      expect(history[2].year, 2023);
      expect(history[2].event, '2023cafr');
    });

    test('getTeamEvents forwards the optional year filter', () async {
      final mockClient = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.statbotics.io/v3/team_events?team=254&limit=1000&year=2024',
        );
        expect(request.url.queryParameters['year'], '2024');
        return http.Response(
          jsonEncode(<List<Map<String, dynamic>>>[]),
          200,
          headers: <String, String>{'content-type': 'application/json'},
        );
      });

      final client = StatboticsClient(httpClient: mockClient);
      final history = await client.getTeamEvents(254, year: 2024);
      expect(history, isEmpty);
    });

    test('getTeamEvents returns an empty list on 404 (unknown team)', () async {
      final client = StatboticsClient(
        httpClient: MockClient((_) async => http.Response('', 404)),
      );
      final history = await client.getTeamEvents(999999);
      expect(history, isEmpty);
    });
  });

  fixtureTests();
}

/// Decodes a captured response body from `test/fixtures/`.
///
/// These are real `api.statbotics.io/v3` bodies, saved verbatim on
/// 2026-09-02. The hand-written maps above are readable but they are also
/// the author's belief about the API, and a model can satisfy every one of
/// them while failing on the real thing: that is how the client came to read
/// `epa.total_points` as a `{mean, sd}` object it has never been. Assert
/// against a captured body, and a shape change fails a test instead of
/// reaching a device.
///
/// Refresh one with, for example:
/// `curl -s 'https://api.statbotics.io/v3/team_years?team=254&limit=2'`
Object _fixture(String name) {
  return jsonDecode(File('test/fixtures/$name.json').readAsStringSync());
}

List<Map<String, dynamic>> _fixtureList(String name) {
  return (_fixture(name) as List<dynamic>)
      .map((e) => (e as Map).cast<String, dynamic>())
      .toList(growable: false);
}

/// Every model, run against a captured live body rather than a hand-written
/// one.
void fixtureTests() {
  group('captured live responses', () {
    test('StatboticsTeamEvent decodes a real /team_events row', () {
      final rows = _fixtureList('team_events_by_event');
      final te = StatboticsTeamEvent.fromJson(rows.first);

      expect(te.team, greaterThan(0));
      expect(te.event, '2025cabe');
      expect(te.eventName, isNotEmpty);
      expect(te.teamName, isNotEmpty);
      expect(te.year, 2025);
      // The regression this file exists to catch: every one of these reads a
      // nested or bare field the client previously looked for in the wrong
      // place, so each would be null or zero against a live body.
      expect(te.epa.totalPoints, isNotNull);
      expect(te.epa.autoPoints, isNotNull);
      expect(te.epa.teleopPoints, isNotNull);
      expect(te.epa.endgamePoints, isNotNull);
      expect(te.rank, isNotNull);
      expect(te.numTeams, isNotNull);
      expect(te.wins + te.losses + te.ties, greaterThan(0));
    });

    test('a real /team_events row survives the cache round-trip', () {
      final original = StatboticsTeamEvent.fromJson(
        _fixtureList('team_events_by_event').first,
      );
      final restored = StatboticsTeamEvent.fromJson(original.toJson());

      expect(restored.team, original.team);
      expect(restored.teamName, original.teamName);
      expect(restored.eventName, original.eventName);
      expect(restored.record, original.record);
      expect(restored.rank, original.rank);
      expect(restored.numTeams, original.numTeams);
      expect(restored.epa.totalPoints, original.epa.totalPoints);
      expect(restored.epa.autoPoints, original.epa.autoPoints);
      expect(restored.epa.teleopPoints, original.epa.teleopPoints);
      expect(restored.epa.endgamePoints, original.epa.endgamePoints);
    });

    test('a team-filtered /team_events row decodes the same way', () {
      final rows = _fixtureList('team_events_by_team');
      final te = StatboticsTeamEvent.fromJson(rows.first);

      expect(te.team, 254);
      expect(te.epa.totalPoints, isNotNull);
      expect(te.eventName, isNotEmpty);
    });

    test('StatboticsTeamYear decodes a real /team_years row', () {
      final rows = _fixtureList('team_years_by_team');
      final ty = StatboticsTeamYear.fromJson(rows.first);

      expect(ty.team, 254);
      expect(ty.year, greaterThan(1991));
      expect(ty.name, isNotEmpty);
      // /team_years reports the record flat, unlike /team_events.
      expect(ty.wins + ty.losses + ty.ties, greaterThan(0));
      expect(ty.epa.totalPoints, isNotNull);
      expect(ty.epa.unitless, isNotNull);
      expect(ty.epa.norm, isNotNull);
      expect(ty.epaRank, isNotNull);
      expect(ty.epaRankTeamCount, isNotNull);
    });

    test('a real /team_years row survives the cache round-trip', () {
      final original = StatboticsTeamYear.fromJson(
        _fixtureList('team_years_by_team').first,
      );
      final restored = StatboticsTeamYear.fromJson(original.toJson());

      expect(restored.team, original.team);
      expect(restored.year, original.year);
      expect(restored.name, original.name);
      expect(restored.record, original.record);
      expect(restored.epaRank, original.epaRank);
      expect(restored.epaRankTeamCount, original.epaRankTeamCount);
      expect(restored.epa.totalPoints, original.epa.totalPoints);
      expect(restored.epa.unitless, original.epa.unitless);
      expect(restored.epa.norm, original.epa.norm);
    });

    test('an early season has no per-phase breakdown and reads as null', () {
      // 2002 predates the auto/teleop/endgame split, so breakdown carries
      // total_points alone. Nullable fields, not zeros.
      final early = _fixtureList('team_years_by_team')
          .map(StatboticsTeamYear.fromJson)
          .firstWhere((ty) => ty.year < 2010);

      expect(early.epa.totalPoints, isNotNull);
      expect(early.epa.autoPoints, isNull);
      expect(early.epa.teleopPoints, isNull);
      expect(early.epa.endgamePoints, isNull);
    });

    test('StatboticsMatch decodes a real /matches row', () {
      final rows = _fixtureList('matches_by_event');
      final match = StatboticsMatch.fromJson(rows.first);

      expect(match.key, startsWith('2025cabe_'));
      expect(match.event, '2025cabe');
      expect(match.compLevel, isNotEmpty);
      expect(match.redTeams, hasLength(3));
      expect(match.blueTeams, hasLength(3));
      expect(match.allTeams.every((t) => t > 0), isTrue);
    });

    test('StatboticsEvent decodes a real /events row', () {
      final rows = _fixtureList('events_by_year');
      final event = StatboticsEvent.fromJson(rows.first);

      expect(event.key, isNotEmpty);
      expect(event.name, isNotEmpty);
      expect(event.year, 2025);
      expect(event.week, isNotNull);
      expect(event.startDate, isNotNull);
      expect(event.endDate, isNotNull);
    });

    test('StatboticsEvent decodes a real /event/{key} body', () {
      final event = StatboticsEvent.fromJson(
        (_fixture('event') as Map).cast<String, dynamic>(),
      );

      expect(event.key, '2025cabe');
      expect(event.name, isNotEmpty);
      expect(event.year, 2025);
    });

    test('StatboticsTeamBasic decodes a real /teams row', () {
      final rows = _fixtureList('teams');
      final team = StatboticsTeamBasic.fromJson(rows.first);

      expect(team.team, greaterThan(0));
      expect(team.nickname, isNotEmpty);
    });
  });
}
