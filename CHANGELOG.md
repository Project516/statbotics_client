# Changelog

## 0.4.0

Breaking. The live v3 API does not send the shape this client's EPA and
team-event models were written against, so `getEventTeams` threw a
`TypeError` on every real response. Statbotics answered HTTP 500 on every
data endpoint from 2026-06-15 to around 2026-09-02, which is why nothing
caught it sooner: the models could not be exercised against a live body, and
the tests asserted against hand-written maps that agreed with the models
rather than with the API.

- `StatboticsEpa` now decodes the shape the API sends. `epa.total_points` is
  a bare number, not a `{mean, sd}` object, and the per-phase measures live
  under `epa.breakdown`. Renamed to match: `totalPointsMean` ->
  `totalPoints`, `autoPointsMean` -> `autoPoints`, `teleopPointsMean` ->
  `teleopPoints`, `endgamePointsMean` -> `endgamePoints`. Added `unitless`
  and `norm`, the cross-season comparable scales. Removed `totalPointsSd`,
  which the API no longer reports anywhere.
- `StatboticsTeamEvent` reads its record from the nested `record` object:
  `wins`/`losses`/`ties` from `record.total`, and `rank`/`numTeams` from
  `record.qual`. They were previously read as top-level fields, which the
  API has no such thing as, so every one decoded to 0 or null.
- Added `getTeamYears(team)` and `StatboticsTeamYear` for season-over-season
  history, completing issue #9. One row per season with that season's EPA,
  record, and worldwide EPA rank. Note `/team_years` reports its record flat,
  unlike `/team_events`.
- `StatboticsEpa.fromJson` still reads the old `{mean, sd}` form for
  `total_points`, so a last-good cache written by an earlier version loads
  instead of throwing on upgrade.
- Model tests now assert against captured live response bodies in
  `test/fixtures/`, so an API shape change fails a test.
- Corrected two doc comments: an unknown team number answers 200 with `[]`,
  not 404. A team number of 100000 or more is rejected with HTTP 422.
- Includes `getTeamEvents(team, {year})`, merged but never released under
  0.3.2: a team's history across events, from `/team_events` with a `team`
  filter, sorted newest season first then by event key.

Migrating: rename the four EPA field reads. Nothing else in the public API
changed, and code that only reads `record`, `rank` or `numTeams` off a
`StatboticsTeamEvent` needs no edit, though it was reading zeros before.

## 0.3.1

- `StatboticsTeamEvent.toJson` now serializes `team_name`, so the
  `toJson`/`fromJson` round trip preserves the nickname it advertises.
  Previously the field was decoded but left out of `toJson`, so a
  cached record came back from the on-device last-good cache with an empty
  `teamName` even though `/team_events` had carried one. Only `team_name` was at
  risk; every other field already round-tripped.

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
