# Company Foundations

Sprache: [English](README_EN.md) | Deutsch  
Steuerinfo: [English](tax-info_EN.md) | [Deutsch](tax-info_DE.md)

Company Foundations ergänzt Endless Sky um eine spielbare Firmenverwaltung für
normale Piloten. Du kannst an zugänglichen bewohnten Raumhäfen eine Firma
registrieren und Shuttle-, Mining-, Trading- und Security-Sparten von einem
Hauptquartier-Planeten aus betreiben.

Der aktuelle Stand ist ein MVP-Balance-Pass für frische Playthroughs, mit
simulierten Firmenflotten, Routen- und Lizenzwachstum, Managern,
Hauptquartier-Buchhaltung, orbitaler Infrastruktur und Firmenbewertung.

## Eine Firma Gründen

Firmenregistrare sind an geeigneten besuchten Raumhäfen verfügbar, wenn deine
Reputation dort zum Landen reicht. Die aktuellen Daten unterstützen 366
zugängliche und besuchbare Hauptquartiere.

Startoptionen:

- Shuttle-Firma: 650,000 Credits.
- Mining-Firma: 900,000 Credits.
- Trading-Firma: 1.25M Credits.
- Security-Firma: 3.5M Credits und mindestens 50 Combat Rating.

Jede neue Firma startet eigentümergeführt, mit aktiviertem AutoPay, 25% Owner
Payout Share, HQ-Steuerregistrierung und einem lokalen Start-Asset. Nach der
Gründung können weitere Sparten über das Firmenpanel hinzugefügt werden, wenn
Kapital und Anforderungen passen.

## Erkundung Und Beschaffung

Firmenwachstum hängt an Erkundung. Wenn du auf einem Raumhafen landest, merkt
sich die Firma den Planeten, das System und lokale Shipyards als bekannte
Lieferanten.

Routen, Lizenzen, Mining Claims und Pirate-Tribute-Ziele erscheinen erst, wenn
das relevante System oder der relevante Planet bekannt ist. Schiffskäufe
erscheinen erst, nachdem du einen Shipyard besucht hast, der dieses Schiff
verkauft. Startschiffe werden zusätzlich als bekannte Beschaffungskanäle
eingetragen, damit jede Firma ihren ersten Schiffstyp weiter kaufen kann.

## Firmenpanel

Das Hauptquartier-Panel funktioniert als strukturierter Firmenterminal. Es zeigt:

- Firmenwert, Reserve, Flottenwert, Stationswert und AutoPay-Warteschlange.
- Erwarteten Tagesumsatz, Ausgaben, Nettogewinn, Owner Payout und Retained
  Earnings.
- Spartenübersichten für Shuttle, Mining, Trading und Security.
- Staff, Office Payroll, Employee Tax, HQ Tax und Station Operations.
- Lifetime Gross, Expenses, Taxes, Manager Costs, Owner Allocations und Retained
  Earnings.
- HQ-Umzüge, Access Suspensions und Operating-Loss-Files.

Das Panel ist in praktische Menüs für Payout Policy, Lizenzen, Schiffe,
Manager, detaillierte Bilanz, HQ-Verwaltung, Stationsbau und Investment geteilt.

## Payouts Und AutoPay

Positiver Nettogewinn wird nach dem Owner Payout Share aufgeteilt. Mögliche
Werte sind 0%, 10%, 25%, 50%, 75% und 100%.

AutoPay ist der normale Auszahlungspfad. Owner Allocations landen in einer
technischen Transferwarteschlange und werden automatisch in Batches ohne Steuer-
oder Transaktionsabzug an den Piloten gezahlt. Manuelle Payout- und
AutoPay-Deaktivierungsoptionen sind nur hinter expliziten Debug- oder
Kompatibilitätsbedingungen sichtbar.

Verlustperioden erzeugen keinen Owner Payout. Stattdessen öffnen sie einen
Distress Report, bis die Reserve stabilisiert und das Problem im HQ geschlossen
wurde.

## Shuttle-Sparte

Shuttle-Firmen starten mit einer lokalen Passagierroute und einem simulierten
Shuttle. Die Routendauer hängt von der Anzahl zugewiesener Schiffe ab, die
Auszahlung von Routenlänge und Passenger Bunks.

Routenstufen:

- Local: 48 Passenger Cap, 4-Tage-Zyklus.
- Regional: 80 Passenger Cap, 6-Tage-Zyklus.
- Long: 140 Passenger Cap, 8-Tage-Zyklus.
- Frontier: 220 Passenger Cap, 10-Tage-Zyklus.

Shuttle-Flotten nutzen entdeckte Transport- und Space-Liner-Schiffe. Luxury Ships
schalten pro Route einen VIP-Servicevertrag für einen Bonus frei. Jede Route hat
ein Passenger Cap, daher lohnt sich Expansion über mehr Routen und passende
Schiffe statt eine einzelne Route endlos zu stapeln.

Manager können außerdem Routenlizenzen kaufen und Shuttle-Routen in
vordefinierte Pakete optimieren, sobald die benötigten Schiffe entdeckt sind und
die Firma mindestens das Doppelte der Paketkosten als Reserve hat.

## Mining-Sparte

Mining-Firmen starten mit einem echten nahegelegenen Mineral Claim und einem
simulierten Sunder. Weitere Rechte basieren auf echten System-Minables und lokalen
Marktpreisen.

Claim-Stufen:

- Local: 160 Cargo Cap, 3-Tage-Zyklus.
- Regional: 300 Cargo Cap, 5-Tage-Zyklus.
- Deep: 480 Cargo Cap, 7-Tage-Zyklus.
- Frontier: 700 Cargo Cap, 9-Tage-Zyklus.

Mining-Flotten nutzen entdeckte Utility-Schiffe mit passender Cargo-Kapazität
sowie den Starter-Sunder und die Mule Mining Conversion. Mining Drones kosten
58,000 Credits, geben jeweils +15% simulierte Extraction Efficiency und sind durch
die verfügbare Drone-Bay-Kapazität der Mining-Schiffe begrenzt.

## Trading-Sparte

Trading-Firmen starten mit einer lokalen Trade License und einem simulierten Star
Barge. Weitere Trade Licenses basieren auf echten Trade-Price-Tabellen und sind
durch lizenzierten Cargo Throughput begrenzt.

Routenstufen:

- Local: 250 Cargo Cap, 4-Tage-Zyklus.
- Regional: 500 Cargo Cap, 6-Tage-Zyklus.
- Long: 900 Cargo Cap, 8-Tage-Zyklus.
- Frontier: 1,300 Cargo Cap, 10-Tage-Zyklus.

Trading-Flotten nutzen entdeckte Freighter, Transports, Utility Ships und Space
Liners mit genug Cargo-Kapazität. Pro Route kann ein Specialist Trader für
10,000 Credits pro Tag eingesetzt werden. Er schaltet die Route von einer
konservativen Basismarge auf den stärksten bekannten statischen Commodity Spread
um.

## Security-Sparte

Security-Firmen starten mit einer lokalen Escort License und einem simulierten
Manta. Weitere Escort Licenses nutzen nur bewohnte Routenendpunkte; leere oder
unbewohnte Systeme dazwischen brauchen keine eigene Bürokratie.

Contract-Stufen:

- Local: Rating Cap 8, 4-Tage-Zyklus.
- Regional: Rating Cap 14, 6-Tage-Zyklus.
- Long: Rating Cap 22, 8-Tage-Zyklus.
- Frontier: Rating Cap 34, 10-Tage-Zyklus.

Security-Flotten nutzen entdeckte Interceptors und Warships. Crew-Kosten basieren
auf echten Schiff-Crew-Werten, und Routenkapazität basiert auf Escort Rating.

## Fleet Admiral

Security-Firmen können einen Fleet Admiral für 300,000 Company Credits plus
20,000 Credits pro Tag einstellen. Der Admiral kommandiert eine unabhängige
Strike Fleet; Escort-Schiffe zählen nicht zum Admiral Fleet Rating.

Der Admiral hat sein Büro im HQ, aber die Strike Fleet hat einen eigenen
physischen Einsatzort. Sie startet im HQ-System und kann für 200,000 Company
Credits zu einem anderen zugänglichen Spaceport verlegt werden. Transit dauert
fünf Betriebstage.

Während die Strike Fleet unterwegs ist, sind Admiral-Flottenkäufe und
Pirate-Tribute-Kampagnen nicht verfügbar. Tribute-Kampagnen verlangen, dass die
Strike Fleet physisch am Zielplaneten stationiert ist.

## Hauptquartier Und Steuern

Lokale HQ-Steuern hängen von Jurisdiction und Planetenattributen ab. Core,
Urban, Capital, Paradise, Rich, Factory, Military und Tourism Worlds kosten eher
mehr. Frontier, Rim, South, Dirt Belt und Pirate Regions sind eher günstiger.

Wenn die Firma wächst, zählt Schiff-Crew als Worker. Größere Belegschaften
erzeugen simulierten Office Staff, grob ein Office Worker pro zwei Company Worker
nach dem ersten Worker. Employee Taxes skalieren progressiv mit größeren
Staff-Werten.

Wenn deine Reputation unter die Landing Requirement des HQ-Planeten fällt,
werden Operations pausiert, bis der Zugang wiederhergestellt ist oder du das HQ
von einem anderen zugänglichen Registrar verlegst. Relocation kostet 500,000
Company Credits und behält den bestehenden Managementmodus.

## Orbitale Infrastruktur

Firmen können simulierte orbitale Infrastruktur aus der Company Reserve bauen:

- Orbital Company Office: kostet 5M Credits, bringt 1,500 Credits pro Tag, kostet
  800 Credits Upkeep pro Tag und reduziert HQ Taxes um 500 Credits pro Tag.
- Logistics Station: kostet 15M Credits, bringt 5,000 Credits pro Tag und kostet
  2,000 Credits Upkeep pro Tag.
- Industrial Dock Station: kostet 45M Credits, bringt 14,000 Credits pro Tag und
  kostet 6,500 Credits Upkeep pro Tag.

Station Operations zählen in Daily Accounting, Monthly Reports, Projections und
Company Valuation. Sie pausieren mit der Firma, wenn HQ Access suspended ist.

## Manager

Ein Operations Manager kostet 250,000 Credits beim Einstellen und 10,000 Credits
pro Tag. Manager folgen der aktuellen Payout Policy und reinvestieren retained
Company Reserve, wenn mindestens das Doppelte der Kaufkosten verfügbar ist.

Manager können Routen, Mining Rights, Lizenzen, Schiffe, Mining Drones,
Shuttle-Optimization-Packages, Specialist Traders, Fleet Admirals,
Admiral-Schiffe und Pirate-Tribute-Kampagnen kaufen, wenn die benötigten
Supplier und Ziele bekannt sind.

Wenn die Firma das Manager-Gehalt von 10,000 Credits an zwei geprueften
Betriebstagen in Folge nicht decken kann, kündigt der Manager und die Firma
kehrt zu owner-managed operations zurück. Der Manager kann auch manuell im
Firmenpanel entlassen werden.

## Firmenverkauf

Das HQ-Menü kann die gesamte Firma bewerten und verkaufen. Die Bewertung umfasst
Reserve, Owner Payable, Fleet Value, Station Value, aktive Routen- und
Lizenzdaten, Admiral Tribute Income und Station Income. Ein abgeschlossener
Verkauf schließt Company Charter, Operating Licenses, Stations, Management
Contracts und HQ Record.
