# Company Foundations

Company Foundations adds a playable company-management layer for normal Endless
Sky pilots. You can register a company at accessible inhabited spaceports and run
Shuttle, Mining, Trading, and Security divisions from a headquarters planet.

The current build is an MVP balance pass for fresh playthroughs, with simulated
company fleets, route and license growth, managers, headquarters accounting,
orbital infrastructure, and company valuation.

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

## Payouts And AutoPay

Positive net profit is allocated according to the owner payout share. Supported
shares are 0%, 10%, 25%, 50%, 75%, and 100%.

AutoPay is now the normal payout path. Owner allocations enter a technical transfer
queue and are automatically paid to the pilot in batches with no tax or transaction
deduction. Manual payout and AutoPay-disable controls are hidden behind explicit
debug or compatibility conditions.

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

- Orbital company office: costs 5M credits, adds 1,500 credits per day, costs 800
  credits per day in upkeep, and reduces headquarters taxes by 500 credits per day.
- Logistics station: costs 15M credits, adds 5,000 credits per day, and costs
  2,000 credits per day in upkeep.
- Industrial dock station: costs 45M credits, adds 14,000 credits per day, and
  costs 6,500 credits per day in upkeep.

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
records, admiral tribute income, and station income. Completing a sale closes the
company charter, operating licenses, stations, management contracts, and
headquarters record.
