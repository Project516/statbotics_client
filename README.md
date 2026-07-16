# statbotics_client

A typed Dart client for the [Statbotics](https://www.statbotics.io) API v3: EPA statistics, events, event team lists, and match schedules for FRC. Pure Dart, so it works in Flutter apps, CLIs, and servers alike.

```dart
import 'package:statbotics_client/statbotics_client.dart';

final client = StatboticsClient();
final events = await client.getEvents(2026);
final teams = await client.getEventTeams('2026txhou');
client.close();
```

No API key needed. Transient server errors are retried with a pluggable `sleep` (inject a no-op in tests); non-transient failures throw `StatboticsApiException` with the status code.

## Installation

Add the dependency in `pubspec.yaml`:

```yaml
dependencies:
  statbotics_client: ^0.1.0
```

Or pull the latest from Git:

```yaml
dependencies:
  statbotics_client:
    git: https://github.com/Project516/statbotics_client.git
```

## API reference

`StatboticsClient` targets `https://api.statbotics.io/v3`. It needs no auth key.
Single-object endpoints return `null` on 404; list endpoints return an empty
list. Anything else outside 2xx throws `StatboticsApiException`. Remember to
call `close()` when you are done so the underlying HTTP client is released.

| Method | Endpoint | Returns |
| --- | --- | --- |
| `getEvent(eventKey)` | `GET /event/{eventKey}` | `StatboticsEvent?` |
| `getEvents(year)` | `GET /events?year={year}` | `List<StatboticsEvent>` |
| `getEventTeams(eventKey)` | `GET /team_events?event={eventKey}` | `List<StatboticsTeamEvent>` |
| `getEventTeamsBasic(eventKey)` | `GET /teams?event={eventKey}` | `List<StatboticsTeamBasic>` |
| `getEventMatches(eventKey)` | `GET /matches?event={eventKey}` | `List<StatboticsMatch>` |

- `getEventTeams` sorts results by rank ascending.
- `getEvents` sorts results by week then name.
- `getEventMatches` sorts results by comp level (`qm`, `ef`, `qf`, `sf`, `f`)
  then match number.
- `getEventTeamsBasic` returns basic team info (number + nickname) and returns
  an empty list if the endpoint is unavailable.

The API is public and read-only, so models only decode the fields each endpoint
exposes (EPA means and standard deviations on `StatboticsTeamEvent`, alliance
teams on `StatboticsMatch`, dates and location on `StatboticsEvent`). Each model
also round-trips through `toJson` for caching.

## Retries and backoff

The Statbotics API returns occasional 500s under load. `StatboticsClient`
retries transient responses (HTTP 429 and any 5xx) up to `maxAttempts` times
(default 3) with exponential backoff (`300 * attempt^2` ms) before surfacing
the error. 404 and other 4xx are returned or thrown immediately, with no retry.

```dart
final client = StatboticsClient(
  maxAttempts: 5,
  sleep: (duration) async {
    // use your own sleeper (e.g. a fake clock in tests)
  },
);
```

## License

AGPL-3.0
