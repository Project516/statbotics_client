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
      case 'sf':
        return 'SF$matchNumber';
      case 'f':
        return 'F$matchNumber';
      default:
        return '$compLevel$matchNumber';
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

/// EPA (Expected Points Added) breakdown for a team at an event.
class StatboticsEpa {
  const StatboticsEpa({
    this.totalPointsMean,
    this.totalPointsSd,
    this.autoPointsMean,
    this.teleopPointsMean,
    this.endgamePointsMean,
  });

  factory StatboticsEpa.fromJson(Map<String, dynamic> json) {
    final total =
        (json['total_points'] as Map?)?.cast<String, dynamic>() ?? const {};
    final auto =
        (json['auto_points'] as Map?)?.cast<String, dynamic>() ?? const {};
    final teleop =
        (json['teleop_points'] as Map?)?.cast<String, dynamic>() ?? const {};
    final endgame =
        (json['endgame_points'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StatboticsEpa(
      totalPointsMean: (total['mean'] as num?)?.toDouble(),
      totalPointsSd: (total['sd'] as num?)?.toDouble(),
      autoPointsMean: (auto['mean'] as num?)?.toDouble(),
      teleopPointsMean: (teleop['mean'] as num?)?.toDouble(),
      endgamePointsMean: (endgame['mean'] as num?)?.toDouble(),
    );
  }

  final double? totalPointsMean;
  final double? totalPointsSd;
  final double? autoPointsMean;
  final double? teleopPointsMean;
  final double? endgamePointsMean;

  static const StatboticsEpa empty = StatboticsEpa();

  /// Round-trips through [StatboticsEpa.fromJson] for the on-device
  /// last-good cache (#512).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'total_points': <String, dynamic>{
        'mean': totalPointsMean,
        'sd': totalPointsSd,
      },
      'auto_points': <String, dynamic>{'mean': autoPointsMean},
      'teleop_points': <String, dynamic>{'mean': teleopPointsMean},
      'endgame_points': <String, dynamic>{'mean': endgamePointsMean},
    };
  }
}

/// Performance data for one team at one event.
class StatboticsTeamEvent {
  StatboticsTeamEvent({
    required this.team,
    required this.event,
    required this.eventName,
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
    return StatboticsTeamEvent(
      team: (json['team'] as num?)?.toInt() ?? 0,
      event: (json['event'] as String?) ?? '',
      eventName: (json['event_name'] as String?) ?? '',
      year: (json['year'] as num?)?.toInt() ?? 0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      ties: (json['ties'] as num?)?.toInt() ?? 0,
      rank: (json['rank'] as num?)?.toInt(),
      numTeams: (json['num_teams'] as num?)?.toInt(),
      epa:
          rawEpa != null ? StatboticsEpa.fromJson(rawEpa) : StatboticsEpa.empty,
    );
  }

  final int team;
  final String event;
  final String eventName;
  final int year;
  final int wins;
  final int losses;
  final int ties;
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
      'year': year,
      'wins': wins,
      'losses': losses,
      'ties': ties,
      'rank': rank,
      'num_teams': numTeams,
      'epa': epa.toJson(),
    };
  }

  String get record => '$wins-$losses${ties > 0 ? '-$ties' : ''}';
}
