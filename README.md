# Company Foundations

Tax details: [tax-info.md](tax-info.md)

Company Foundations adds a playable company-management layer for normal Endless
Sky pilots. You can register a company at accessible inhabited spaceports, choose
an operating focus, and grow it into a multi-division business with simulated
fleets, licenses, managers, taxes, headquarters logistics, orbital infrastructure,
and company valuation.

Current status: this is a playable alpha balance pass. The core loop is in place,
including Shuttle, Mining, Trading, and
Security starts; exploration-gated procurement; daily and monthly accounting;
AutoPay owner payouts; manager-driven reinvestment; headquarters relocation;
station construction; fleet-admiral deployments; pirate tribute pressure; and
selling the company. Existing companies are migrated to the unified accounting
model on their next landing after updating the plugin.

The plugin is still a prototype: it focuses on systems, balance, and progression
over story polish, custom artwork, or handcrafted mission arcs.

## Starting A Company

Company registrars are available at eligible visited spaceports when your
reputation allows you to land there. The current data supports 366 accessible
visitable headquarters.

Starting options:

- Shuttle company: 650,000 credits.
- Mining company: 900,000 credits.
- Trading company: 1.25M credits.
- Security company: 3.5M credits and at least 50 combat rating.

Every new company starts owner-managed, with AutoPay enabled, a 25% owner payout
share, headquarters tax registration, and one local operating asset. After
founding, additional divisions can be added from the company board if you have the
capital and meet the relevant requirements.

## Exploration And Procurement

Company growth is tied to exploration. Landing on a spaceport records the planet,
its system, and any local shipyards as known company suppliers.

Routes, licenses, mining claims, and pirate tribute targets only appear once the
relevant system or planet is known. Ship purchases only appear after you have
visited a shipyard that sells that ship. Starter ships are also backfilled as known
procurement channels so each company can continue buying its initial vessel type.

## Visible Company Fleets

The company government now produces conditional ambient traffic without requiring
an additional homeworld. Shuttle flights, mining convoys, trading convoys, and
security patrols can appear in the current headquarters system and at active route,
claim, or contract endpoints. The fleet entries stop spawning automatically when a
division is inactive, headquarters access is suspended, or the headquarters moves.

Visible traffic uses three representative size tiers. One or two simulated ships
produce small traffic, three to six produce medium traffic, and seven or more
produce large traffic. Security patrols and admiral groups use their combat rating
for the same tier selection. These ambient ships visualize company activity; they
do not replace the accounting fleet, and destroying one does not remove a simulated
company asset.

The admiral group appears only at its recorded deployment system and disappears
while in transit. Hiring an admiral through the generic headquarters board records
the initial deployment as the current headquarters, so station-based companies are
covered as well.

## Company Board

The headquarters board now works as a structured company terminal. It tracks:

- Firm value, reserve, fleet value, station value, and AutoPay queue.
- Projected daily gross, expenses, net profit, owner payout, and retained earnings.
- Division-level summaries for Shuttle, Mining, Trading, and Security.
- Staff, office payroll, employee tax, headquarters tax, and station operations.
- Lifetime gross, expenses, taxes, manager costs, owner allocations, and retained
  earnings.
- Headquarters relocations, access suspensions, and operating-loss files.

The board is split into practical menus for payout policy, licenses, ship
procurement, managers, detailed balance, headquarters administration, station
construction, and investment.

## Unified Daily Accounting

One company-wide daily operation advances every founded division. This lets a
Shuttle, Mining, Trading, and Security division earn in parallel instead of
competing for one shared pending mission. Company-wide overhead such as manager
salary, office payroll, headquarters tax, and station upkeep is charged once per
day; each division still keeps its own gross, expense, net, monthly, and lifetime
ledgers.

When upgrading an existing save, land once to run the invisible accounting and
headquarters-offer migrations. Old division-specific operation missions are
closed automatically and the company resumes in its existing management mode.

## Payouts And AutoPay

Positive net profit is allocated according to the owner payout share. Supported
shares are 0%, 10%, 25%, 50%, 75%, and 100%.

AutoPay is the normal payout path. Owner allocations enter a technical transfer
queue and are automatically paid to the pilot in batches with no tax or
transaction deduction. Manual payout and AutoPay-disable controls are hidden
behind explicit debug or compatibility conditions.

Operating losses do not create owner payouts. Instead, they open a distress report
until the reserve is stabilized and the issue is closed at headquarters.

## Shuttle Division

Shuttle companies start with one local passenger route and one simulated Shuttle.
Route timing depends on assigned ship count, while payout size depends on route
length and passenger bunks.

Route tiers:

- Local: 48 passenger cap, 4-day cycle.
- Regional: 80 passenger cap, 6-day cycle.
- Long: 140 passenger cap, 8-day cycle.
- Frontier: 220 passenger cap, 10-day cycle.

Shuttle fleets use discovered transport and space-liner ships. Luxury ships unlock
one VIP service contract per route for an extra premium bonus. Each route has a
passenger cap, so expansion favors opening more routes and assigning appropriate
ships instead of stacking one corridor endlessly.

Managers can also buy route licenses and optimize shuttle routes into preset
packages once the required ships have been discovered and the company has at least
double the package cost in reserve.

## Mining Division

Mining companies start with a real nearby mineral claim and one simulated Sunder.
Additional rights are based on actual system minables and local market prices.

Claim tiers:

- Local: 160 cargo cap, 3-day cycle.
- Regional: 300 cargo cap, 5-day cycle.
- Deep: 480 cargo cap, 7-day cycle.
- Frontier: 700 cargo cap, 9-day cycle.

Mining fleets use discovered utility ships with suitable cargo capacity, plus the
starter Sunder and Mule mining conversion. Mining Drones cost 58,000 credits each,
add 15% simulated extraction efficiency, and are limited by available drone bay
capacity on company mining ships.

## Trading Division

Trading companies start with one local trade license and one simulated Star Barge.
Additional trade licenses are based on real system trade-price tables and are
capped by licensed cargo throughput.

Route tiers:

- Local: 250 cargo cap, 4-day cycle.
- Regional: 500 cargo cap, 6-day cycle.
- Long: 900 cargo cap, 8-day cycle.
- Frontier: 1,300 cargo cap, 10-day cycle.

Trading fleets use discovered freighters, transports, utility ships, and space
liners with enough cargo capacity. A specialist trader can be assigned to each
route for 10,000 credits per day, switching that route from its conservative base
margin to the strongest known static commodity spread.

## Security Division

Security companies start with one local escort license and one simulated Manta.
Additional escort licenses use inhabited route endpoints only; empty or
uninhabited systems in between do not need separate paperwork.

Contract tiers:

- Local: rating cap 8, 4-day cycle.
- Regional: rating cap 14, 6-day cycle.
- Long: rating cap 22, 8-day cycle.
- Frontier: rating cap 34, 10-day cycle.

Security fleets use discovered interceptors and warships. Crew costs are based on
real ship crew requirements, and route capacity is based on escort rating.

## Fleet Admiral

Security companies can hire one fleet admiral for 300,000 company credits plus
20,000 credits per day. The admiral commands an independent strike fleet; escort
ships do not count toward admiral fleet rating.

The admiral keeps an office at company headquarters, but the strike fleet has its
own physical deployment location. It starts in the headquarters system and can be
ordered to another accessible spaceport for 200,000 company credits. Transit takes
five operating days.

While the strike fleet is in transit, admiral fleet purchases and pirate tribute
campaigns are unavailable. Tribute campaigns require the strike fleet to be
physically deployed at the target planet.

## Headquarters And Taxes

Local headquarters taxes depend on jurisdiction and planet attributes. Core,
urban, capital, paradise, rich, factory, military, and tourism worlds tend to cost
more. Frontier, rim, south, dirt belt, and pirate regions tend to be cheaper.

As the company grows, ship crews count as workers. Larger workforces create
simulated office staff at roughly one office worker per two company workers after
the first worker. Employee taxes scale progressively at larger staff sizes.

If your reputation falls below the headquarters planet's landing requirement,
operations are suspended until access is restored or you relocate the headquarters
from another accessible registrar. Relocation costs 500,000 company credits and
keeps the existing management mode.

## Orbital Infrastructure

Companies can build simulated orbital infrastructure from company reserves:

- Orbital company office: costs 5M credits, adds 3,000 credits per day, costs
  2,000 credits per day in upkeep, and reduces headquarters taxes by 500 credits
  per day.
- Logistics outfitter deck: costs 15M credits, adds 8,500 credits per day, and
  costs 6,000 credits per day in upkeep.
- Industrial shipyard dock: costs 45M credits, adds 24,000 credits per day, and
  costs 17,000 credits per day in upkeep.

Station operations are included in daily accounting, monthly reports, projections,
and company valuation. They pause with the company when headquarters access is
suspended.

## Managers

An operations manager costs 250,000 credits to hire and 10,000 credits per day.
Managers follow the current payout policy and reinvest retained company reserve
when there is at least double the purchase cost available.

Managers can buy routes, mining rights, licenses, ships, mining drones, shuttle
optimization packages, specialist traders, fleet admirals, admiral ships, and
pirate tribute campaigns when the required suppliers and targets are known.

If the company cannot cover the manager's 10,000 credit salary for two checked
operating days in a row, the manager resigns and the company returns to
owner-managed operations. The manager can also be dismissed manually from the
company board.

## Company Sale

The headquarters menu can value and sell the entire company. Valuation includes
reserve, owner payable, fleet value, station value, active route and license
records, admiral tribute income, and station income. Fleet and station assets use
liquidation discounts, route and license records use conservative book values,
and a negative reserve remains a liability. This prevents founding a company and
immediately selling it for a risk-free profit. Completing a sale closes the
company charter, operating licenses, stations, management contracts, and
headquarters record.

## Logging And Diagnostics

The plugin records important migrations, manager investments, headquarters
changes, and company sales in the Endless Sky in-game log. Endless Sky data
plugins cannot directly create arbitrary files on the host system, so a companion
save watcher is included for structured external logging.

From the plugin directory, start it with a specific pilot save:

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\watch_company_foundations_log.ps1 -SavePath "$env:APPDATA\endless-sky\saves\Pilot Name.txt"
```

If `-SavePath` is omitted, the newest non-backup save is selected. Events are
appended as JSON Lines to `logs/company-foundations.jsonl`. The watcher logs a
baseline and each subsequent save change, including company totals, active
divisions, the operations mission, changed fields, and accounting anomalies.
Stop it with Ctrl+C. Useful diagnostic options are:

- `-Once` to write one snapshot and exit.
- `-LogPath <path>` to choose another output file.
- `-IntervalSeconds <n>` to change the polling interval.
- `-IncludeAllConditions` to include every `cf:` save condition instead of only
  the audit summary.

## Generated Data

Gameplay data is generated by `tools/generate_company_foundations.ps1` from the
installed Endless Sky map, market, and ship data. Planet-dependent routes,
licenses, taxes, and migrations remain HQ-specific. Planet-independent manager
fleet purchases are emitted once, and the former comment-only per-planet license
catalogs are no longer shipped.
