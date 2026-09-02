class StatboticsTeamBasic {
  StatboticsTeamBasic({required this.team, required this.nickname});

  factory StatboticsTeamBasic.fromJson(Map<String, dynamic> json) {
    return StatboticsTeamBasic(
      team: (json['team'] as num?)?.toInt() ?? 0,
      nickname: (json['name'] as String?) ?? '',
    );
  }

  final int team;
  final String nickname;
}

class StatboticsMatch {
  StatboticsMatch({
    required this.key,
    required this.event,
    required this.matchNumber,
    required this.compLevel,
    required this.redTeams,
    required this.blueTeams,
  });

  factory StatboticsMatch.fromJson(Map<String, dynamic> json) {
    final alliances =
        (json['alliances'] as Map?)?.cast<String, dynamic>() ?? {};
    final red = (alliances['red'] as Map?)?.cast<String, dynamic>() ?? {};
    final blue = (alliances['blue'] as Map?)?.cast<String, dynamic>() ?? {};

    List<int> extractTeams(Map<String, dynamic> alliance) {
      // Statbotics v3 uses 'team_keys' (list of ints).
      final teamKeysList = alliance['team_keys'] as List<dynamic>?;
      if (teamKeysList != null) {
        return teamKeysList
            .map((t) => (t as num).toInt())
            .where((t) => t > 0)
            .toList(growable: false);
      }
      final teamsList = alliance['teams'] as List<dynamic>?;
      if (teamsList != null) {
        return teamsList
            .map((t) => (t as num).toInt())
            .where((t) => t > 0)
            .toList(growable: false);
      }
      final teams = <int>[];
      for (var i = 1; i <= 3; i++) {
        final t = alliance['team_$i'];
        if (t != null) teams.add((t as num).toInt());
      }
      return teams;
    }

    return StatboticsMatch(
      key: (json['key'] as String?) ?? '',
      event: (json['event'] as String?) ?? '',
      matchNumber: (json['match_number'] as num?)?.toInt() ?? 0,
      compLevel: (json['comp_level'] as String?) ?? 'qm',
      redTeams: extractTeams(red),
      blueTeams: extractTeams(blue),
    );
  }

  final String key;
  final String event;
  final int matchNumber;
  final String compLevel;
  final List<int> redTeams;
  final List<int> blueTeams;

  /// Round-trips through [StatboticsMatch.fromJson] for the on-device
  /// last-good cache (#512).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'event': event,
      'match_number': matchNumber,
      'comp_level': compLevel,
      'alliances': <String, dynamic>{
        'red': <String, dynamic>{'team_keys': redTeams},
        'blue': <String, dynamic>{'team_keys': blueTeams},
      },
    };
  }

  bool get isQualification => compLevel == 'qm';

  String get displayName {
    switch (compLevel) {
      case 'qm':
        return 'Q$matchNumber';
      case 'ef':
        return 'EF$matchNumber';
      case 'qf':
        return 'QF$matchNumber';
      case 'sf':
        return 'SF$matchNumber';
      case 'f':
        return 'F$matchNumber';
      default:
        return '${compLevel.toUpperCase()}$matchNumber';
    }
  }

  List<int> get allTeams => [...redTeams, ...blueTeams];

  int? teamForStation(String station) {
    switch (station) {
      case 'R1':
        return redTeams.isNotEmpty ? redTeams[0] : null;
      case 'R2':
        return redTeams.length > 1 ? redTeams[1] : null;
      case 'R3':
        return redTeams.length > 2 ? redTeams[2] : null;
      case 'B1':
        return blueTeams.isNotEmpty ? blueTeams[0] : null;
      case 'B2':
        return blueTeams.length > 1 ? blueTeams[1] : null;
      case 'B3':
        return blueTeams.length > 2 ? blueTeams[2] : null;
      default:
        return null;
    }
  }
}

class StatboticsEvent {
  StatboticsEvent({
    required this.key,
    required this.name,
    required this.year,
    this.week,
    this.country,
    this.state,
    this.startDate,
    this.endDate,
  });

  factory StatboticsEvent.fromJson(Map<String, dynamic> json) {
    return StatboticsEvent(
      key: (json['key'] as String?) ?? '',
      name: (json['name'] as String?) ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      week: (json['week'] as num?)?.toInt(),
      country: json['country'] as String?,
      state: json['state'] as String?,
      startDate: json['start_date'] as String?,
      endDate: json['end_date'] as String?,
    );
  }

  final String key;
  final String name;
  final int year;
  final int? week;
  final String? country;
  final String? state;
  final String? startDate;
  final String? endDate;

  /// Round-trips through [StatboticsEvent.fromJson] for the on-device
  /// last-good cache (#512).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'key': key,
      'name': name,
      'year': year,
      'week': week,
      'country': country,
      'state': state,
      'start_date': startDate,
      'end_date': endDate,
    };
  }
}

/// EPA (Expected Points Added) for a team, as `/team_events` and
/// `/team_years` report it.
///
/// [totalPoints] is the point estimate the API puts at `epa.total_points`,
/// not an average over matches -- `epa.stats.mean` is a different number and
/// this model does not carry it. The per-phase measures live under
/// `epa.breakdown` and are absent for seasons predating that game's scoring
/// split, so every field here is nullable.
class StatboticsEpa {
  const StatboticsEpa({
    this.totalPoints,
    this.unitless,
    this.norm,
    this.autoPoints,
    this.teleopPoints,
    this.endgamePoints,
  });

  factory StatboticsEpa.fromJson(Map<String, dynamic> json) {
    final breakdown =
        (json['breakdown'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StatboticsEpa(
      totalPoints: (json['total_points'] as num?)?.toDouble(),
      unitless: (json['unitless'] as num?)?.toDouble(),
      norm: (json['norm'] as num?)?.toDouble(),
      autoPoints: (breakdown['auto_points'] as num?)?.toDouble(),
      teleopPoints: (breakdown['teleop_points'] as num?)?.toDouble(),
      endgamePoints: (breakdown['endgame_points'] as num?)?.toDouble(),
    );
  }

  /// The team's EPA in game points.
  final double? totalPoints;

  /// The unitless EPA scale, comparable across seasons where [totalPoints] is
  /// not, since a season's point values are its own.
  final double? unitless;

  /// The normalized EPA scale, centred so 1500 is an average team.
  final double? norm;

  final double? autoPoints;
  final double? teleopPoints;
  final double? endgamePoints;

  static const StatboticsEpa empty = StatboticsEpa();

  /// Round-trips through [StatboticsEpa.fromJson] for the on-device
  /// last-good cache (#512).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total_points': totalPoints,
      'unitless': unitless,
      'norm': norm,
      'breakdown': <String, dynamic>{
        'auto_points': autoPoints,
        'teleop_points': teleopPoints,
        'endgame_points': endgamePoints,
      },
    };
  }
}

/// Performance data for one team at one event.
class StatboticsTeamEvent {
  StatboticsTeamEvent({
    required this.team,
    required this.event,
    required this.eventName,
    this.teamName = '',
    required this.year,
    required this.wins,
    required this.losses,
    required this.ties,
    this.rank,
    this.numTeams,
    required this.epa,
  });

  factory StatboticsTeamEvent.fromJson(Map<String, dynamic> json) {
    final rawEpa = (json['epa'] as Map?)?.cast<String, dynamic>();
    final record =
        (json['record'] as Map?)?.cast<String, dynamic>() ?? const {};
    final total =
        (record['total'] as Map?)?.cast<String, dynamic>() ?? const {};
    final qual = (record['qual'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StatboticsTeamEvent(
      team: (json['team'] as num?)?.toInt() ?? 0,
      event: (json['event'] as String?) ?? '',
      eventName: (json['event_name'] as String?) ?? '',
      teamName: (json['team_name'] as String?) ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      wins: (total['wins'] as num?)?.toInt() ?? 0,
      losses: (total['losses'] as num?)?.toInt() ?? 0,
      ties: (total['ties'] as num?)?.toInt() ?? 0,
      rank: (qual['rank'] as num?)?.toInt(),
      numTeams: (qual['num_teams'] as num?)?.toInt(),
      epa:
          rawEpa != null ? StatboticsEpa.fromJson(rawEpa) : StatboticsEpa.empty,
    );
  }

  final int team;
  final String event;
  final String eventName;

  /// The team's nickname, as `/team_events` reports it.
  ///
  /// Worth reading here because `/teams` takes an `event` parameter and ignores
  /// it, returning the global team list whatever event you ask for, so this is
  /// the only endpoint that gives event-scoped names. Empty when the payload
  /// omits it.
  final String teamName;
  final int year;

  /// Won-lost-tied over the whole event, quals and elims together, from
  /// `record.total`.
  final int wins;
  final int losses;
  final int ties;

  /// Qualification rank and field size, from `record.qual`. Null before the
  /// event has ranked anyone, and for an event Statbotics has no record of.
  final int? rank;
  final int? numTeams;
  final StatboticsEpa epa;

  /// Round-trips through [StatboticsTeamEvent.fromJson] for the on-device
  /// last-good cache (#512).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'team': team,
      'event': event,
      'event_name': eventName,
      'team_name': teamName,
      'year': year,
      'record': <String, dynamic>{
        'qual': <String, dynamic>{'rank': rank, 'num_teams': numTeams},
        'total': <String, dynamic>{
          'wins': wins,
          'losses': losses,
          'ties': ties,
        },
      },
      'epa': epa.toJson(),
    };
  }

  String get record => '$wins-$losses${ties > 0 ? '-$ties' : ''}';
}

/// One team's season, as `/team_years` reports it.
///
/// The season-over-season counterpart to [StatboticsTeamEvent]: one row per
/// year a team competed, carrying that season's EPA and record.
///
/// Compare seasons on [StatboticsEpa.unitless] or [StatboticsEpa.norm] rather
/// than [StatboticsEpa.totalPoints]. Point values belong to a season's game,
/// so a 2002 total of 16.6 and a 2025 total of 92.77 say nothing about which
/// robot was better.
class StatboticsTeamYear {
  StatboticsTeamYear({
    required this.team,
    required this.year,
    this.name = '',
    required this.wins,
    required this.losses,
    required this.ties,
    this.epaRank,
    this.epaRankTeamCount,
    required this.epa,
  });

  factory StatboticsTeamYear.fromJson(Map<String, dynamic> json) {
    final rawEpa = (json['epa'] as Map?)?.cast<String, dynamic>();
    // Flat here, unlike `/team_events`, which splits the record into
    // qual/elim/total.
    final record =
        (json['record'] as Map?)?.cast<String, dynamic>() ?? const {};
    final ranks =
        (rawEpa?['ranks'] as Map?)?.cast<String, dynamic>() ?? const {};
    final total = (ranks['total'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StatboticsTeamYear(
      team: (json['team'] as num?)?.toInt() ?? 0,
      year: (json['year'] as num?)?.toInt() ?? 0,
      name: (json['name'] as String?) ?? '',
      wins: (record['wins'] as num?)?.toInt() ?? 0,
      losses: (record['losses'] as num?)?.toInt() ?? 0,
      ties: (record['ties'] as num?)?.toInt() ?? 0,
      epaRank: (total['rank'] as num?)?.toInt(),
      epaRankTeamCount: (total['team_count'] as num?)?.toInt(),
      epa:
          rawEpa != null ? StatboticsEpa.fromJson(rawEpa) : StatboticsEpa.empty,
    );
  }

  final int team;
  final int year;

  /// The team's nickname for that season.
  final String name;

  /// Won-lost-tied across the whole season.
  final int wins;
  final int losses;
  final int ties;

  /// Where this season's EPA placed the team worldwide, from
  /// `epa.ranks.total`, with the number of teams it was ranked against.
  final int? epaRank;
  final int? epaRankTeamCount;

  final StatboticsEpa epa;

  /// Round-trips through [StatboticsTeamYear.fromJson] for the on-device
  /// last-good cache (#512).
  Map<String, dynamic> toJson() {
    final epaJson = epa.toJson();
    epaJson['ranks'] = <String, dynamic>{
      'total': <String, dynamic>{
        'rank': epaRank,
        'team_count': epaRankTeamCount,
      },
    };
    return <String, dynamic>{
      'team': team,
      'year': year,
      'name': name,
      'record': <String, dynamic>{
        'wins': wins,
        'losses': losses,
        'ties': ties,
      },
      'epa': epaJson,
    };
  }

  String get record => '$wins-$losses${ties > 0 ? '-$ties' : ''}';
}
