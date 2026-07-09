# statbotics_client

A typed Dart client for the [Statbotics](https://www.statbotics.io) API v3: EPA statistics, events, event team lists, and match schedules for FRC. Pure Dart, so it works in Flutter apps, CLIs, and servers alike.

```dart
import 'package:statbotics_client/statbotics_client.dart';

final client = StatboticsClient();
final events = await client.getEvents(2026);
final teams = await client.getEventTeams('2026txhou');
```

No API key needed. Transient server errors are retried with a pluggable `sleep` (inject a no-op in tests); non-transient failures throw `StatboticsApiException` with the status code.

## License

AGPL-3.0
