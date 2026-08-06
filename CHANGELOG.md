# Changelog

## 0.3.0

- `StatboticsTeamEvent.teamName` exposes the nickname `/team_events` already
  returns. It is the only endpoint that gives event-scoped names: `/teams`
  accepts an `event` parameter and ignores it, answering with the global team
  list whatever event you ask for, which is documented on the new field and in
  `getEventTeamsBasic`. Defaults to an empty string, so nothing that builds a
  `StatboticsTeamEvent` by hand has to change.

## 0.2.0

- `StatboticsMatch.displayName` renders every playoff level in the same case as
  the qualification and final ones: `EF2` and `QF3` rather than `ef2` and `qf3`.
  Only `qm`, `sf` and `f` had explicit cases, so `ef` and `qf` fell through to a
  branch that passed the raw lowercase level straight out. That branch now
  upper-cases whatever it is given, so a level Statbotics adds later reads the
  same way.
- Documented the full public API surface and the transient-error retry
  behavior in the README.

## 0.1.0

- Initial release: `StatboticsClient` (`getEvent`, `getEventTeams`,
  `getEvents`, `getEventMatches`, `getEventTeamsBasic`) with typed EPA,
  event, team, and match models, plus transient-error retry with backoff.
