# Changelog

All notable changes to Company Foundations are documented in this file.

## [0.2a] - 2026-08-09

This entry covers the changes between `v0.1` (`09cbdd4`) and the merged
`develop` release commit (`5f03ee2`).

### Added

- Added visible company shuttle, mining, trading, security, and admiral fleets
  at active headquarters and operating locations, with size tiers derived from
  the simulated company fleet.
- Added a shared, non-blocking company board with finance, division,
  headquarters, station, manager, procurement, and company-sale menus.
- Added persistent numeric IDs for headquarters, station systems, admiral
  locations, and admiral destinations.
- Added versioned, repeat-safe v0.1 save migrations and save schema 2.
- Added headquarters-station access enforcement and a dedicated player-company
  government for ambient corporate traffic.
- Added a save watcher with JSON Lines diagnostics, resolved location names,
  accounting anomaly checks, and business-risk reporting.
- Added static verification, deterministic regeneration checks, local save
  migration audits, Endless Sky asset-parser support, and GitHub Actions CI.
- Added plugin metadata and repository-wide line-ending and editor settings.

### Changed

- Replaced separate per-division operation loops with one unified daily company
  operation. Every founded division now advances in parallel while company-wide
  overhead is charged only once.
- Expanded division, monthly, lifetime, staff, tax, station, manager, and owner
  payout accounting while retaining a single company reserve.
- Made AutoPay the normal owner-payout path and converted the owner-payable
  balance into a technical transfer queue.
- Reworked headquarters-local offers, regional targets, routes, claims,
  licenses, and procurement to use assignments generated from live Endless Sky
  map, market, shipyard, and ship data.
- Replaced custom known-system flags with native visited-system requirements for
  exploration-gated expansion.
- Rebalanced starter fleet values, route book values, headquarters taxes,
  station income, manager eligibility, and fleet-admiral salary.
- Increased station income to 5,000 credits for the orbital office, 16,000 for
  the logistics deck, and 47,000 for the industrial dock while retaining their
  respective upkeep costs.
- Changed the manager contract to require at least 12,000 credits of projected
  daily net income and changed the fleet-admiral salary to 5,000 credits per day.
- Made ambient corporate ships uncapturable and added meaningful reputation
  penalties for attacking the player-company government.
- Compacted generated manager, admiral, and headquarters data to remove large
  amounts of repeated per-location output.
- Raised the minimum supported Endless Sky version to 0.11.2.

### Fixed

- Fixed multi-division companies advancing only one division at a time.
- Fixed manager salary, office costs, headquarters taxes, and station upkeep
  being charged more than once during a company day.
- Fixed stale manual and managed operation missions blocking or duplicating the
  current accounting loop.
- Fixed headquarters, station, and admiral tracking after headquarters moves,
  station construction, admiral deployment, and admiral transit.
- Fixed station-based companies not being handled consistently by the generic
  board and ambient fleet system.
- Fixed negative company reserve being reported as a broken invariant instead
  of an operating risk.
- Fixed the deterministic regeneration test overwriting its configured base-data
  path because of PowerShell's case-insensitive variable names.

### Savegame Migration from v0.1

- Converts legacy named headquarters, station, and admiral conditions to stable
  numeric IDs.
- Stops old division-specific and repair operation missions, clears their saved
  mission states, and resumes the existing manual or managed operating mode.
- Migrates headquarters-local offers, shuttle route book values, tax state, and
  unified accounting state behind individual version guards.
- Recalculates existing station modules to the current income, upkeep, staffing,
  valuation, and headquarters-tax model.
- Preserves company reserve, fleet value, divisions, contracts, payout policy,
  management mode, ownership, and historical accounting totals.
- Includes a compatibility tombstone for the removed v0.1 HQ-presence data so an
  in-place plugin update cannot leave the old generated missions active.
