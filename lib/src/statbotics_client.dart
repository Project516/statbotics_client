import 'dart:convert';

import 'package:http/http.dart' as http;

import 'statbotics_models.dart';

/// Thin client for the Statbotics REST API v3.
///
/// No authentication is required. The API is public and read-only.
/// See https://www.statbotics.io/docs/rest for endpoint documentation.
class StatboticsClient {
  StatboticsClient({
    http.Client? httpClient,
    int maxAttempts = 3,
    Future<void> Function(Duration)? sleep,
  })  : _httpClient = httpClient ?? http.Client(),
        _maxAttempts = maxAttempts < 1 ? 1 : maxAttempts,
        _sleep = sleep ?? Future<void>.delayed;

  static const String baseUrl = 'https://api.statbotics.io/v3';

  final http.Client _httpClient;

  /// How many times a single request is attempted before giving up. Transient
  /// responses (HTTP 429 and 5xx, e.g. the sporadic 500s Statbotics returns
  /// under load, #496) are retried with a short exponential backoff; 404 and
  /// other 4xx are returned/thrown immediately.
  final int _maxAttempts;
  final Future<void> Function(Duration) _sleep;

  /// `GET /v3/event/{event_key}` — returns the event, or null on 404.
  Future<StatboticsEvent?> getEvent(String eventKey) async {
    final body = await _get('/event/$eventKey');
    if (body == null) return null;
    return StatboticsEvent.fromJson(jsonDecode(body) as Map<String, dynamic>);
  }

  /// `GET /v3/team_events?event={eventKey}&limit=100` — returns all
  /// team-event records for the given event, sorted by rank ascending.
  ///
  /// Statbotics caps the default page size at 100; most FRC events have
  /// fewer than 70 teams so a single request is sufficient.
  Future<List<StatboticsTeamEvent>> getEventTeams(String eventKey) async {
    final body = await _get(
      '/team_events',
      queryParameters: <String, String>{'event': eventKey, 'limit': '100'},
    );
    if (body == null) return const <StatboticsTeamEvent>[];
    final list = jsonDecode(body) as List<dynamic>;
    final results = list
        .map(
          (json) => StatboticsTeamEvent.fromJson(
            (json as Map).cast<String, dynamic>(),
          ),
        )
        .toList(growable: true);
    results.sort((a, b) {
      if (a.rank == null && b.rank == null) return 0;
      if (a.rank == null) return 1;
      if (b.rank == null) return -1;
      return a.rank!.compareTo(b.rank!);
    });
    return results;
  }

  /// `GET /v3/events?year={year}` — returns all events for the given year,
  /// sorted by week then name.
  Future<List<StatboticsEvent>> getEvents(int year) async {
    final body = await _get(
      '/events',
      queryParameters: <String, String>{
        'year': year.toString(),
        'limit': '500',
      },
    );
    if (body == null) return const <StatboticsEvent>[];
    final list = jsonDecode(body) as List<dynamic>;
    final results = list
        .map(
          (json) =>
              StatboticsEvent.fromJson((json as Map).cast<String, dynamic>()),
        )
        .toList(growable: true);
    results.sort((a, b) {
      final aw = a.week ?? 99;
      final bw = b.week ?? 99;
      if (aw != bw) return aw.compareTo(bw);
      return a.name.compareTo(b.name);
    });
    return results;
  }

  /// `GET /v3/matches?event={eventKey}&limit=200` — returns all match schedule
  /// entries for the event, sorted by comp level then match number.
  Future<List<StatboticsMatch>> getEventMatches(String eventKey) async {
    final body = await _get(
      '/matches',
      queryParameters: <String, String>{'event': eventKey, 'limit': '200'},
    );
    if (body == null) return const <StatboticsMatch>[];
    final list = jsonDecode(body) as List<dynamic>;
    final results = list
        .map(
          (json) =>
              StatboticsMatch.fromJson((json as Map).cast<String, dynamic>()),
        )
        .toList(growable: true);
    const levelOrder = <String, int>{
      'qm': 0,
      'ef': 1,
      'qf': 2,
      'sf': 3,
      'f': 4,
    };
    results.sort((a, b) {
      final la = levelOrder[a.compLevel] ?? 9;
      final lb = levelOrder[b.compLevel] ?? 9;
      if (la != lb) return la.compareTo(lb);
      return a.matchNumber.compareTo(b.matchNumber);
    });
    return results;
  }

  /// `GET /v3/teams?event={eventKey}&limit=100` — returns basic team info
  /// (number + nickname) for all teams at the event. Returns an empty list if
  /// the endpoint is unavailable.
  Future<List<StatboticsTeamBasic>> getEventTeamsBasic(String eventKey) async {
    try {
      final body = await _get(
        '/teams',
        queryParameters: <String, String>{'event': eventKey, 'limit': '100'},
      );
      if (body == null) return const <StatboticsTeamBasic>[];
      final list = jsonDecode(body) as List<dynamic>;
      return list
          .map(
            (json) => StatboticsTeamBasic.fromJson(
              (json as Map).cast<String, dynamic>(),
            ),
          )
          .toList(growable: false);
    } catch (_) {
      return const <StatboticsTeamBasic>[];
    }
  }

  void close() {
    _httpClient.close();
  }

  Future<String?> _get(
    String path, {
    Map<String, String>? queryParameters,
  }) async {
    final uri = Uri.parse(
      '$baseUrl$path',
    ).replace(queryParameters: queryParameters);
    for (var attempt = 1;; attempt++) {
      final response = await _httpClient.get(
        uri,
        headers: const <String, String>{'Accept': 'application/json'},
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode == 200) return response.body;
      // 429 (rate limit) and 5xx are transient: back off and retry a few times
      // before surfacing the error, so a momentary blip self-heals (#496).
      final transient =
          response.statusCode == 429 || response.statusCode >= 500;
      if (transient && attempt < _maxAttempts) {
        await _sleep(Duration(milliseconds: 300 * attempt * attempt));
        continue;
      }
      throw StatboticsApiException(response.statusCode, response.body);
    }
  }
}

class StatboticsApiException implements Exception {
  StatboticsApiException(this.statusCode, this.body);

  final int statusCode;
  final String body;

  @override
  String toString() => 'Statbotics API error $statusCode: $body';
}
