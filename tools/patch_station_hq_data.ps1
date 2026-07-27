param(
	[string] $HqPath = "data/company hq.txt",
	[string] $PresencePath = "data/company hq presence.txt",
	[string] $StationsPath = "data/company stations.txt"
)

$ErrorActionPreference = "Stop"

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)
$companyGovernmentName = "Company Foundations Player Company"
$companyStationPlanetName = "Company Headquarters"

$stationSystems = @(Select-String -LiteralPath $StationsPath -Pattern '^event "Company Foundations: Station Site: (.+)"$' | ForEach-Object {
	$_.Matches[0].Groups[1].Value
})

function Add-StationChoiceLines {
	param([System.Collections.Generic.List[string]] $Out)

	foreach($line in @(
		"				``	Build a corporate station core for 5M company credits.``",
		"					to display",
		"						has `"cf: active`"",
		"						not `"cf: hq suspended`"",
		"						not `"cf: station orbital office`"",
		"						`"cf: reserve`" >= 5000000",
		"					goto `"menu station sites`"",
		"				``	Install a station outfitter deck for 15M company credits.``",
		"					to display",
		"						has `"cf: station orbital office`"",
		"						not `"cf: hq suspended`"",
		"						not `"cf: station logistics hub`"",
		"						`"cf: reserve`" >= 15000000",
		"					goto `"confirm build logistics station`"",
		"				``	Install an industrial shipyard dock for 45M company credits.``",
		"					to display",
		"						has `"cf: station logistics hub`"",
		"						not `"cf: hq suspended`"",
		"						not `"cf: station industrial dock`"",
		"						`"cf: reserve`" >= 45000000",
		"					goto `"confirm build industrial station`""
	)) {
		$Out.Add($line)
	}
}

function Add-SiteMenuLines {
	param([System.Collections.Generic.List[string]] $Out)

	$Out.Add("			label `"menu station sites`"")
	$Out.Add("			``Choose a human-space system with no landable planet for the company headquarters station.``")
	$Out.Add("			choice")
	foreach($systemName in $stationSystems) {
		$Out.Add("				``	Build in $systemName.``")
		$Out.Add("					to display")
		$Out.Add("						has `"cf: active`"")
		$Out.Add("						not `"cf: hq suspended`"")
		$Out.Add("						not `"cf: station orbital office`"")
		$Out.Add("						`"cf: reserve`" >= 5000000")
		$Out.Add("					goto `"confirm build station in $systemName`"")
	}
	$Out.Add("				``	Back.``")
	$Out.Add("					goto `"menu stations`"")
}

function Add-BuildStationLabels {
	param([System.Collections.Generic.List[string]] $Out)

	foreach($systemName in $stationSystems) {
		$Out.Add("			label `"confirm build station in $systemName`"")
		$Out.Add("			``Build the company headquarters station in the $systemName system for 5,000,000 company credits?``")
		$Out.Add("			choice")
		$Out.Add("				``	Build station.``")
		$Out.Add("					goto `"build station in $systemName`"")
		$Out.Add("				``	Cancel.``")
		$Out.Add("					goto `"menu station sites`"")
		$Out.Add("			label `"build station in $systemName`"")
		$Out.Add("			action")
		$Out.Add("				`"cf: reserve`" -= 5000000")
		$Out.Add("				set `"cf: station orbital office`"")
		$Out.Add("				set `"cf: hq station built`"")
		$Out.Add("				set `"cf: hq: $companyStationPlanetName`"")
		$Out.Add("				set `"cf: hq station system: $systemName`"")
		$Out.Add("				set `"cf: at hq`"")
		$Out.Add("				`"reputation: $companyGovernmentName`" >?= 1000")
		$Out.Add("				`"cf: station count`" ++")
		$Out.Add("				`"cf: station value`" += 5000000")
		$Out.Add("				`"cf: station daily income`" += 1500")
		$Out.Add("				`"cf: station daily upkeep`" += 800")
		$Out.Add("				`"cf: hq tax relief`" += 500")
		$Out.Add("				`"cf: hq daily tax`" -= 500")
		$Out.Add("				event `"Company Foundations: Station Site: $systemName`"")
		$Out.Add("				log `"Company Foundations`" `"Headquarters Station`" ``Built the company headquarters station in the $systemName system.``")
		$Out.Add("			``Your company charters a compact headquarters station in the $systemName system. The new station handles customs, berthing contracts, and dispatch traffic, adding 1,500 credits per day in service income, 800 credits per day in upkeep, and reducing local HQ taxes by 500 credits per day.``")
		$Out.Add("				goto `"company transaction summary`"")
	}
}

function Add-LogisticsLabels {
	param([System.Collections.Generic.List[string]] $Out)

	foreach($line in @(
		"			label `"confirm build logistics station`"",
		"			``Install a station outfitter deck for 15,000,000 company credits?``",
		"			choice",
		"				``	Build station.``",
		"					goto `"build logistics station`"",
		"				``	Cancel.``",
		"					goto `"company main menu`"",
		"			label `"build logistics station`"",
		"			action",
		"				`"cf: reserve`" -= 15000000",
		"				set `"cf: station logistics hub`"",
		"				`"cf: station count`" ++",
		"				`"cf: station value`" += 15000000",
		"				`"cf: station daily income`" += 5000",
		"				`"cf: station daily upkeep`" += 2000",
		"				event `"Company Foundations: Station Stage 2 Outfitter`"",
		"			``The company expands the headquarters station with an outfitter deck. Cargo handling, shuttle transfers, and crew services add 5,000 credits per day in station income, with 2,000 credits per day in upkeep.``",
		"				goto `"company transaction summary`""
	)) {
		$Out.Add($line)
	}
}

function Add-IndustrialLabels {
	param([System.Collections.Generic.List[string]] $Out)

	foreach($line in @(
		"			label `"confirm build industrial station`"",
		"			``Install an industrial shipyard dock for 45,000,000 company credits?``",
		"			choice",
		"				``	Build station.``",
		"					goto `"build industrial station`"",
		"				``	Cancel.``",
		"					goto `"company main menu`"",
		"			label `"build industrial station`"",
		"			action",
		"				`"cf: reserve`" -= 45000000",
		"				set `"cf: station industrial dock`"",
		"				`"cf: station count`" ++",
		"				`"cf: station value`" += 45000000",
		"				`"cf: station daily income`" += 14000",
		"				`"cf: station daily upkeep`" += 6500",
		"				event `"Company Foundations: Station Stage 3 Shipyard`"",
		"			``The company builds an industrial shipyard dock with repair berths, warehousing, and contractor shops. It adds 14,000 credits per day in station income, with 6,500 credits per day in upkeep.``",
		"				goto `"company transaction summary`""
	)) {
		$Out.Add($line)
	}
}

$inputLines = [System.Collections.Generic.List[string]]::new()
foreach($line in [System.IO.File]::ReadLines((Resolve-Path $HqPath))) {
	$inputLines.Add($line)
}

$outputLines = [System.Collections.Generic.List[string]]::new()
for($i = 0; $i -lt $inputLines.Count; $i++) {
	$line = $inputLines[$i]
	if($line.Contains("Build an orbital company office for 5M company credits.")) {
		Add-StationChoiceLines $outputLines
		while($i + 1 -lt $inputLines.Count -and -not $inputLines[$i].Contains('goto "confirm build industrial station"')) {
			$i++
		}
		continue
	}
	if($line.Contains('label "menu invest"') -and -not ($outputLines | Where-Object { $_.Contains('label "menu station sites"') } | Select-Object -First 1)) {
		Add-SiteMenuLines $outputLines
	}
	if($line.Contains('label "confirm build orbital office"')) {
		Add-BuildStationLabels $outputLines
		while($i + 1 -lt $inputLines.Count -and -not $inputLines[$i + 1].Contains('label "confirm build logistics station"')) {
			$i++
		}
		continue
	}
	if($line.Contains('label "confirm build logistics station"')) {
		Add-LogisticsLabels $outputLines
		while($i + 1 -lt $inputLines.Count -and -not $inputLines[$i + 1].Contains('label "confirm build industrial station"')) {
			$i++
		}
		continue
	}
	if($line.Contains('label "confirm build industrial station"')) {
		Add-IndustrialLabels $outputLines
		while($i + 1 -lt $inputLines.Count -and -not $inputLines[$i + 1].Contains('label "confirm invest 1000"')) {
			$i++
		}
		continue
	}
	$outputLines.Add($line)
}

[System.IO.File]::WriteAllLines((Resolve-Path $HqPath), $outputLines, $utf8NoBom)

$presence = [System.IO.File]::ReadAllText((Resolve-Path $PresencePath))
if($presence -notmatch '(?m)^mission "Company Foundations: Mark At Headquarters: Company Headquarters"$') {
	$stationPresence = @"
mission "Company Foundations: Mark At Headquarters: Company Headquarters"
	name "At Company Headquarters"
	invisible
	landing
	repeat
	source "Company Headquarters"
	to offer
		has "cf: active"
		has "cf: hq station built"
		not "cf: at hq"
	on offer
		set "cf: at hq"
		"reputation: Company Foundations Player Company" >?= 1000
		fail

"@
	[System.IO.File]::WriteAllText((Resolve-Path $PresencePath), $stationPresence + $presence, $utf8NoBom)
}

Write-Host "Patched $($stationSystems.Count) station site choices."
