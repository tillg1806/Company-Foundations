# Company Foundations Steuerinfo

Sprache: [English](tax-info_EN.md) | Deutsch  
README: [English](README_EN.md) | [Deutsch](README_DE.md)

Diese Übersicht zeigt die tägliche HQ-Grundsteuer pro möglichem Hauptquartier sowie die Skalierung, mit der die Steuer im laufenden Betrieb steigt.

## Steuerformel

```text
tägliche HQ-Steuer = max(0, HQ-Grundsteuer + Personalsteuer - Stationsentlastung)
```

- Die HQ-Grundsteuer kommt aus Planet, Regierung und lokalen Attributen.
- Personalsteuer skaliert mit der gesamten Belegschaft.
- Ein orbitales Büro reduziert die HQ-Steuer um 500 Credits pro Tag.
- Die finale HQ-Grundsteuer wird bei 100 Credits Minimum und 2,000 Credits Maximum gekappt.

## Grundsteuer-Skalierung

| Regel | Effekt |
| --- | ---: |
| Basiswert | 300 |
| Republic, Syndicate, Free Worlds, Deep Security | setzt Basis auf 350 |
| Hai, Coalition, Heliarch | setzt Basis auf 450 |
| rim, frontier, dirt belt, south pirate, north pirate, core pirate, pirate | -150 |
| Pirate, Independent, Neutral | maximal 250 vor weiteren Attributen |
| south | -100 |
| core, urban, capital, paradise | +700 |
| rich, factory, military | +250 |
| tourism | +150 |
| Minimum / Maximum | 100 / 2,000 |

## Personalsteuer-Skalierung

Personalsteuer wird über `total staff` berechnet. Divisionen in der Formel sind ganzzahlige Schwellenwerte.

| Bestandteil | Berechnung |
| --- | ---: |
| Grundanteil | total staff * 5 |
| je 5 Staff | +20 |
| je 10 Staff | +40 |
| je 20 Staff | +100 |
| je 50 Staff | +250 |
| je 100 Staff | +600 |
| je 500 Staff | +4,000 |
| je 1,000 Staff | +10,000 |

## Staff-Berechnung

| Bestandteil | Berechnung |
| --- | --- |
| Worker staff | Schiff-Crew der aktiven Routen, Claims, Security-Verträge und Admiralflotte / 100 |
| Office staff | max(worker staff - 1, 0) / 2 |
| Specialist staff | aktive Specialist Trader + Manager + Fleet Admiral |
| Total staff | worker staff + office staff + specialist staff |

## Planetentabelle

Anzahl möglicher Hauptquartiere: 366

| Planet | Regierung | HQ-Grundsteuer / Tag |
| --- | --- | ---: |
| Aava-Aasa-Khora | Old Houses | 300 |
| Ablub's Invention | Coalition | 700 |
| Ada | Republic | 1,300 |
| Ahr | Coalition | 1,550 |
| Albatross | Pirate | 100 |
| Alexandria | Republic | 500 |
| Alfheim | Republic | 600 |
| Allhome | Hai | 1,150 |
| Alta Hai | Quarg (Hai) | 300 |
| Alvorada | Pirate | 300 |
| Amathil | Avgi | 300 |
| Amazon | Syndicate | 1,050 |
| Angko | Bunrodea | 550 |
| Antipode | Syndicate | 900 |
| Arabia | Republic | 200 |
| Araio | Avgi | 150 |
| Arroharg | Quarg (Gegno) | 300 |
| Asgard | Republic | 1,300 |
| Ashy Reach | Coalition | 450 |
| Aventine | Remnant | 300 |
| Aviskir | Avgi | 1,000 |
| Bailey | Pirate | 100 |
| Bank of Blugtad | Coalition | 1,150 |
| Belug's Plunge | Coalition | 450 |
| Big Sky | Republic | 200 |
| Bivrost | Republic | 1,300 |
| Bloodsea | Pirate | 100 |
| Bloptab's Furnace | Coalition | 450 |
| Blubipad's Workshop | Coalition | 1,550 |
| Blue Interior | Coalition | 1,300 |
| Bluestone | Syndicate | 900 |
| Bosunothro | Bunrodea (Guard) | 300 |
| Bounty | Republic | 450 |
| Bourne | Republic | 1,150 |
| Brass Second | Coalition | 1,150 |
| Bright Echo | Coalition | 1,300 |
| Buccaneer Bay | Pirate | 850 |
| Bunthro | Bunrodea (Guard) | 300 |
| Burthen | Syndicate | 1,050 |
| Caelian | Remnant | 300 |
| Calda | Republic | 1,200 |
| Canyon | Syndicate | 900 |
| Celestial Third | Coalition | 1,400 |
| Charon Station | Republic | 250 |
| Chiron | Republic | 1,300 |
| Chosen Nexus | Coalition | 1,150 |
| Cipi | Gegno Scin | 300 |
| Clark | Republic | 450 |
| Cloudfire | Hai | 700 |
| Cold Horizon | Coalition | 600 |
| Cool Forest | Coalition | 1,150 |
| Cornucopia | Republic | 100 |
| Corral of Meblumem | Coalition | 450 |
| Covert | Pirate | 850 |
| Crossroads | Syndicate | 1,050 |
| Cyreal | Avgi | 450 |
| Dancer | Republic | 250 |
| Darkcloak | Hai (Unfettered) | 300 |
| Darkmetal | Hai | 450 |
| Darkstone | Republic | 100 |
| Deadman's Cove | Pirate | 850 |
| Deep | Republic | 250 |
| Deep Treasure | Coalition | 450 |
| Deep Water | Coalition | 450 |
| Deli Kasi | Bunrodea | 300 |
| Deli Kat | Bunrodea | 300 |
| Delve | Syndicate | 1,050 |
| Delve of Bloptab | Coalition | 450 |
| Disara | Bunrodea | 1,250 |
| Double Haze | Coalition | 1,400 |
| Dueitch Ae | Gegno Scin | 300 |
| Dueyu Eitch | Gegno | 300 |
| Dune | Republic | 200 |
| Dusk Companion | Coalition | 450 |
| Dustmaker | Hai | 450 |
| Dwelling of Speloog | Coalition | 1,150 |
| Earth | Republic | 1,450 |
| Echo | Quarg | 200 |
| Ef Aourtdye | Gegno | 550 |
| Ef Osch | Gegno Scin | 300 |
| Ember Reaches | Uninhabited | 300 |
| Ember Wormhole | Uninhabited | 300 |
| Enbye | Gegno Vi | 300 |
| Enn Bue | Gegno Scin | 300 |
| Erabuthro | Bunrodea (Guard) | 1,000 |
| Eragarthro | Bunrodea (Guard) | 300 |
| Ergastirio Station | Avgi (Consonance) | 550 |
| Essime | Gegno Vi | 300 |
| Everhope | Hai | 450 |
| Factory of Eblumab | Coalition | 700 |
| Far Garden | Coalition | 1,300 |
| Far Home | Coalition | 1,300 |
| Farpoint | Republic | 450 |
| Farseer | Republic | 1,200 |
| Farwater | Hai | 450 |
| Featherweight | Republic | 200 |
| Fenrir Station | Republic | 350 |
| Feo Platform | Avgi (Twilight Guard) | 550 |
| Firelode | Hai (Unfettered) | 300 |
| Flood | Republic | 350 |
| Flowing Fields | Coalition | 450 |
| Follower | Republic | 1,300 |
| Forpelog | Quarg | 200 |
| Foundry | Syndicate | 1,300 |
| Fourth Shadow | Coalition | 1,400 |
| Freedom | Pirate | 150 |
| Frostmark | Hai | 1,150 |
| Furnace | Syndicate | 1,300 |
| Gagarin | Pirate | 1,000 |
| Garden Empyreal | Coalition | 600 |
| Geminus | Republic | 1,300 |
| Gemstone | Republic | 200 |
| Gentle Rain | Coalition | 600 |
| Geyser | Republic | 600 |
| Gi Tiures | Gegno | 300 |
| Giaru Gegno | Quarg (Gegno) | 300 |
| Giverstone | Hai | 450 |
| Glaze | Republic | 400 |
| Glittering Ice | Coalition | 450 |
| Glory | Republic | 1,050 |
| Graede | Gegno Vi | 300 |
| Grakhord | Quarg | 200 |
| Greenbloom | Hai | 450 |
| Greenrock | Pirate | 100 |
| Greenview | Hai | 450 |
| Greenwater | Hai | 450 |
| Gresku Fodar | Korath | 300 |
| Greymoon | Hai | 450 |
| Guardian Array Sapphire | Coalition | 450 |
| Gue Faur | Gegno Scin | 300 |
| Hai-home | Hai | 1,150 |
| Hammer of Debrugt | Coalition | 1,150 |
| Harmony | Republic | 100 |
| Haven | Pirate | 150 |
| Haze | Republic | 600 |
| Heartland | Republic | 450 |
| Heartvalley | Hai | 450 |
| Helheim | Republic | 350 |
| Hephaestus | Syndicate | 1,300 |
| Hermes | Republic | 1,050 |
| Hestia | Republic | 1,050 |
| Hippocrates | Syndicate | 900 |
| Hopper | Republic | 200 |
| Humanika | Quarg | 200 |
| Icefall | Syndicate | 900 |
| Icelake | Hai | 1,400 |
| Iddesato | Bunrodea | 300 |
| Iemn Eitch | Gegno | 300 |
| Illbo Avo | Bunrodea (Guard) | 550 |
| Illbo Elo | Bunrodea | 550 |
| Ingot | Republic | 200 |
| Inmost Blue | Coalition | 1,150 |
| Into White | Coalition | 450 |
| Iyra-Ijasa-Iret | Successor | 300 |
| Jakobsen | Pirate | 100 |
| Jentuthro | Bunrodea (Guard) | 300 |
| Karek Fornati | Kor Efret | 300 |
| Kasii-Cavasaa-Oa | House Aqrabe | 300 |
| Kasii-Tuur-Saqru | People's Houses | 300 |
| Kasi-Osolaa-Sossa | Successor | 300 |
| Kessel Sepret | Korath | 300 |
| Khora-Vasa-Reyyaa | House Chydiyi | 550 |
| Ki Patek Ka | Coalition | 1,300 |
| Kisarra | Bunrodea | 300 |
| Korati Efreti | Kor Efret | 300 |
| Kort Kehai | Wanderer | 300 |
| Kort Vek'kri | Wanderer | 300 |
| Kraken Station | Syndicate | 350 |
| Kua-Oa-Aava | Successor | 300 |
| Kuwaru Efreti | Quarg (Kor Efret) | 300 |
| Lagrange | Quarg | 350 |
| Laki Nemparu | Kor Efret | 300 |
| Leviathan Station | Republic | 350 |
| Lichen | Republic | 100 |
| Livolua | Avgi | 1,000 |
| Lodestone | Syndicate | 1,050 |
| Longjump | Republic | 600 |
| Luna | Republic | 750 |
| Maelstrom | Republic | 200 |
| Mainsail | Republic | 1,050 |
| Maker | Syndicate | 1,300 |
| Makerplace | Hai | 1,150 |
| Mani | Republic | 350 |
| Market of Gupta | Coalition | 450 |
| Mars | Republic | 500 |
| Martini | Republic | 1,200 |
| Mavra-Sol-Kvel | Successor | 300 |
| Mebla's Portion | Coalition | 1,150 |
| Melenci | Bunrodea | 300 |
| Memory | Republic | 600 |
| Mere | Republic | 200 |
| Miblulub's Plenty | Coalition | 450 |
| Midgard | Republic | 1,300 |
| Midway Emerald | Coalition | 1,150 |
| Millrace | Syndicate | 1,300 |
| Mirrorlake | Hai | 450 |
| Moonshake | Syndicate | 1,300 |
| Mordente-Bridi | Pirate | 1,000 |
| Mosaa-Oa-Vyret | Successor | 300 |
| Muninn Station | Republic | 600 |
| Muspel | Republic | 600 |
| Navigeo Yards | Avgi (Twilight Guard) | 550 |
| Nearby Jade | Coalition | 1,150 |
| New Argentina | Republic | 200 |
| New Austria | Republic | 200 |
| New Boston | Republic | 200 |
| New Britain | Republic | 1,150 |
| New China | Republic | 1,050 |
| New Finding | Coalition | 450 |
| New Greenland | Republic | 200 |
| New Holland | Republic | 450 |
| New Iceland | Republic | 450 |
| New India | Republic | 100 |
| New Kansas | Republic | 200 |
| New Portland | Republic | 200 |
| New Sahara | Republic | 450 |
| New Switzerland | Republic | 500 |
| New Tibet | Republic | 450 |
| New Tortuga | Pirate | 1,100 |
| New Wales | Republic | 200 |
| New Washington | Republic | 200 |
| Newhome | Hai | 1,150 |
| Nifel | Republic | 350 |
| Nimbus | Syndicate | 1,050 |
| Norn | Republic | 350 |
| Oasis | Republic | 200 |
| Oblivion | Republic | 200 |
| Ochrescoop | Hai | 450 |
| Ogmur's Siphon | Coalition | 450 |
| Okoity | Bunrodea | 1,000 |
| Oup Je | Gegno Scin | 300 |
| Outpost Enka | Avgi (Dissonance) | 300 |
| Outpost Leto | Avgi (Dissonance) | 300 |
| Outpost Pilos | Avgi (Consonance) | 300 |
| Outpost Tekis | Avgi (Dissonance) | 300 |
| O-Vasa-Oa | New Houses | 1,000 |
| Pearl | Republic | 1,200 |
| Pelubta Station | Coalition | 450 |
| Periaxle Circuit | Coalition | 450 |
| Peripheria | Avgi (Consonance) | 1,000 |
| Pilot | Republic | 350 |
| Placer | Syndicate | 900 |
| Plort's Water | Coalition | 450 |
| Poisonwood | Republic | 350 |
| Pon'tes | Hicemus | 300 |
| Poseidos | Republic | 200 |
| Prime | Republic | 1,300 |
| Pugglemug | Pug | 300 |
| Pugglequat | Pug | 300 |
| Quicksilver | Syndicate | 1,050 |
| Raaqa-Kvelq-Ryuit | House Myurej | 1,000 |
| Raaqa-Puan-Uuoru | House Kaatrij | 300 |
| Rand | Republic | 200 |
| Redias | Conlatio | 300 |
| Refuge of Belugt | Coalition | 1,300 |
| Relic | Republic | 350 |
| Remnant Wormhole | Uninhabited | 300 |
| Remote Blue | Coalition | 1,150 |
| Reunion | Syndicate | 1,300 |
| Ring of Friendship | Heliarch | 450 |
| Ring of Power | Heliarch | 450 |
| Ring of Wisdom | Heliarch | 450 |
| Ruelogakk | Quarg (Gegno) | 300 |
| Rust | Republic | 450 |
| Rusty Second | Coalition | 1,150 |
| Safaresk Enlai | Korath | 300 |
| Sandy Two | Coalition | 1,400 |
| Sardva | Bunrodea (Guard) | 300 |
| Saros | Coalition | 1,300 |
| Saska-Aa-Noorr | House Myurej | 300 |
| Second Cerulean | Coalition | 450 |
| Second Rose | Coalition | 450 |
| Second Viridian | Coalition | 1,150 |
| Secret Sky | Coalition | 450 |
| Separa Tiklar | Korath | 300 |
| Septar Lorku | Korath | 300 |
| Serpens | Republic | 350 |
| Sessiliki Far | Korath | 300 |
| Setar Fort | Kor Efret | 300 |
| Shadow of Leaves | Coalition | 1,150 |
| Shadowed Valley | Coalition | 450 |
| Shangri-La | Syndicate | 900 |
| Shassa-Wyra-Orrou | Successor | 450 |
| Shifting Sand | Coalition | 450 |
| Shiver | Republic | 350 |
| Shorebreak | Republic | 200 |
| Shroud | Republic | 200 |
| Siedi | Gegno Vi | 300 |
| Sies Upi | Gegno Vi | 300 |
| Silo of Ablodab | Coalition | 700 |
| Silver | Republic | 350 |
| Sinter | Republic | 100 |
| Skillet | Republic | 200 |
| Skyfarm | Hai | 450 |
| Skymoot | Republic | 350 |
| Smuggler's Den | Pirate | 100 |
| Snowfeather | Hai | 450 |
| Solace | Republic | 1,050 |
| Sopoyra | Bunrodea | 300 |
| Spec Inci | Quarg (Incipias) | 300 |
| Splashdown | Republic | 350 |
| Staja-Kella-Oa | House Sioeora | 300 |
| Starcross | Republic | 200 |
| Starting Rubin | Coalition | 450 |
| Station Cian | Coalition | 450 |
| Stilacrest | Avgi | 300 |
| Stonebreak | Hai | 1,150 |
| Stormhold | Pirate | 850 |
| Stronghold of Flugbu | Coalition | 700 |
| Successor Wormhole | Uninhabited | 300 |
| Sundive | Syndicate | 900 |
| Sundrinker | Republic | 100 |
| Sunracer | Syndicate | 1,150 |
| Swiftsong | Hai | 450 |
| Tebuteb's Table | Coalition | 450 |
| Ternituul | Gegno Vi | 300 |
| Thilos | Avgi | 300 |
| Third Umber | Coalition | 700 |
| Thrall | Republic | 1,050 |
| Thshybothro | Bunrodea (Guard) | 300 |
| Thule | Pirate | 100 |
| Thunder | Republic | 200 |
| Tik Klai | Wanderer | 300 |
| Tinker | Syndicate | 600 |
| Trinket | Republic | 400 |
| Triton Station | Republic | 600 |
| Trove | Syndicate | 1,050 |
| Truklar | Quarg (Gegno) | 300 |
| Tschyss | Gegno | 300 |
| Tundra | Republic | 200 |
| Turquoise Four | Coalition | 450 |
| Tuur-Aasa-Kaska | Old Houses | 300 |
| Twinstar | Republic | 250 |
| Uo-Oraa-Vayya | Successor | 300 |
| Ut Divitas | Quarg (Incipias) | 300 |
| Vail | Republic | 1,200 |
| Valhalla | Republic | 1,300 |
| Var' Kar'i'i | Wanderer | 1,000 |
| Var' Kayi | Wanderer | 1,000 |
| Var' Roi | Wanderer | 300 |
| Vara Kehi'ki | Wanderer | 300 |
| Vara Ke'sok | Wanderer | 300 |
| Vara Ke'stai | Wanderer | 300 |
| Vara Pug | Pug (Wanderer) | 300 |
| Vara Rakak | Wanderer | 300 |
| Varu Ek'lak'lai | Wanderer | 300 |
| Varu K'est | Wanderer | 550 |
| Varu K'prai | Wanderer | 300 |
| Varu Mer'ek | Wanderer | 550 |
| Varu Tek'kai | Wanderer | 550 |
| Varu Tev'kei | Wanderer | 550 |
| Vibrant Water | Coalition | 450 |
| Viminal | Remnant | 300 |
| Vinci | Republic | 1,300 |
| Warfeed | Hai (Unfettered) | 300 |
| Warm Slope | Coalition | 1,150 |
| Warm Wind | Coalition | 600 |
| Wayfarer | Republic | 650 |
| Weir of Glubatub | Coalition | 450 |
| Weledos | Avgi | 150 |
| Windblain | Republic | 350 |
| Winter | Republic | 350 |
| Wyvern Station | Republic | 200 |
| Yoqqa-Vasa-Vasa | House Seineq | 450 |
| Zenith | Pirate | 150 |
| Zug | Republic | 450 |
