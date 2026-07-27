param(
    [string]$BaseData = "",
    [string]$SystemData = "",
    [string]$DataRoot = "",
    [string]$OutFile = ""
)

$explicitParameters = @{}
foreach($key in $PSBoundParameters.Keys) {
    $explicitParameters[$key] = $PSBoundParameters[$key]
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pluginRoot = Split-Path -Parent $scriptRoot
$localConfigPath = Join-Path $scriptRoot "company_foundations.local.ps1"

if(Test-Path -LiteralPath $localConfigPath) {
    . $localConfigPath
}

foreach($key in $explicitParameters.Keys) {
    Set-Variable -Name $key -Value $explicitParameters[$key] -Scope Local
}

if(-not $DataRoot) {
    $DataRoot = $env:ENDLESS_SKY_DATA
}

if(-not $DataRoot) {
    $steamCandidates = @(
        $(if(${env:ProgramFiles(x86)}) { Join-Path ${env:ProgramFiles(x86)} "Steam\steamapps\common\Endless Sky\data" }),
        $(if($env:ProgramFiles) { Join-Path $env:ProgramFiles "Steam\steamapps\common\Endless Sky\data" })
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

    if($steamCandidates.Count -gt 0) {
        $DataRoot = $steamCandidates[0]
    }
}

if(-not $DataRoot) {
    throw "Set -DataRoot, ENDLESS_SKY_DATA, or tools/company_foundations.local.ps1."
}

if(-not $BaseData) {
    $BaseData = Join-Path $DataRoot "map planets.txt"
}

if(-not $SystemData) {
    $SystemData = Join-Path $DataRoot "map systems.txt"
}

if(-not $OutFile) {
    $OutFile = Join-Path $pluginRoot "data\company foundations.txt"
}

$excludedAttributes = @(
    "avgi", "bunrodea", "coalition", "gegno", "hai", "incipias", "ka'het",
    "ka'sei", "korath", "pirate", "pug", "quarg", "remnant", "successor", "wanderer"
)

$excludedGovernments = @(
    "Avgi", "Bunrodea", "Coalition", "Drak", "Gegno", "Gegno Scin", "Gegno Vi",
    "Hai", "Heliarch", "Ka'het", "Ka'sei", "Kor Efret", "Korath", "Kor Mereti",
    "Kor Sestor", "Pug", "Quarg", "Remnant", "Successors", "Uninhabited",
    "Wanderer"
)

$excludedSystemAttributes = @(
    "arachi", "avgi", "bunrodea", "coalition", "gegno", "hai", "incipias",
    "ka'het", "ka'sei", "kimek", "korath", "pirate", "pug", "quarg",
    "remnant", "saryd", "successor", "wanderer"
)

$humanSystemAttributes = @(
    "core", "near earth", "paradise", "dirt belt", "deep", "rim", "south", "north"
)

$companyGovernmentName = "Company Foundations Player Company"
$companyStationPlanetName = "Company Headquarters"
$companyStationOutfitterName = "Company Station Outfitter"
$companyStationShipyardName = "Company Station Shipyard"

function ConvertFrom-ESTokenLine {
    param([string]$Line)

    $matches = [regex]::Matches($Line, '`([^`]*)`|"([^"]*)"|(\S+)')
    $tokens = New-Object System.Collections.Generic.List[string]
    foreach($match in $matches) {
        if($match.Groups[1].Success) {
            $tokens.Add($match.Groups[1].Value)
        } elseif($match.Groups[2].Success) {
            $tokens.Add($match.Groups[2].Value)
        } else {
            $tokens.Add($match.Groups[3].Value)
        }
    }
    return ,$tokens.ToArray()
}

function Format-ESToken {
    param([string]$Text)

    if($Text -match '^[A-Za-z0-9_.:+''-]+$') {
        return $Text
    }
    return '"' + $Text.Replace('"', '\"') + '"'
}

function Format-ESMissionName {
    param([string]$Text)
    return '"' + $Text.Replace('"', '\"') + '"'
}

function Format-CreditAmount {
    param([int]$Amount)
    return $Amount.ToString('N0', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Add-RouteAccountingLines {
    param(
        [string]$Prefix,
        [int]$Threshold,
        [int]$FarePerPassenger
    )

    Add-Line "		`"cf: shuttle $Prefix progress`" += `"cf: shuttle $Prefix ships`""
    Add-Line "		`"cf: shuttle $Prefix completed`" = `"cf: shuttle $Prefix progress`" / $Threshold"
    Add-Line "		`"cf: shuttle $Prefix income`" = `"cf: shuttle $Prefix trip payout`""
    Add-Line "		`"cf: shuttle $Prefix income`" += `"cf: shuttle $Prefix trip payout`" * `"cf: shuttle $Prefix vip`" * 2"
    Add-Line "		`"cf: shuttle $Prefix gross`" = `"cf: shuttle $Prefix completed`" * `"cf: shuttle $Prefix income`""
    Add-Line "		`"cf: shuttle $Prefix expenses`" = `"cf: shuttle $Prefix completed`" * `"cf: shuttle $Prefix trip expenses`""
    Add-Line "		`"cf: shuttle $Prefix profit`" = `"cf: shuttle $Prefix gross`" - `"cf: shuttle $Prefix expenses`""
    Add-Line "		`"cf: shuttle day gross`" += `"cf: shuttle $Prefix gross`""
    Add-Line "		`"cf: shuttle day expenses`" += `"cf: shuttle $Prefix expenses`""
    Add-Line "		`"cf: shuttle day profit`" += `"cf: shuttle $Prefix profit`""
    Add-Line "		`"cf: shuttle route revenue`" += `"cf: shuttle $Prefix gross`""
    Add-Line "		`"cf: shuttle $Prefix progress`" -= `"cf: shuttle $Prefix completed`" * $Threshold"
}

function Add-DivisionPeriodAccountingLines {
    param(
        [string]$Prefix,
        [string]$GrossCondition,
        [string]$ExpensesCondition,
        [string]$ProfitCondition,
        [int]$ManagerCost = 0
    )

    Add-Line "		`"cf: $Prefix last gross`" = `"$GrossCondition`""
    Add-Line "		`"cf: $Prefix last expenses`" = `"$ExpensesCondition`""
    Add-Line "		`"cf: $Prefix last net`" = `"$ProfitCondition`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: $Prefix last expenses`" += $ManagerCost"
        Add-Line "		`"cf: $Prefix last net`" -= $ManagerCost"
    }
    Add-Line "		`"cf: $Prefix total gross`" += `"$GrossCondition`""
    Add-Line "		`"cf: $Prefix total expenses`" += `"$ExpensesCondition`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: $Prefix total expenses`" += $ManagerCost"
    }
    Add-Line "		`"cf: $Prefix total net`" += `"$ProfitCondition`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: $Prefix total net`" -= $ManagerCost"
    }
    Add-Line "		`"cf: $Prefix month gross`" += `"$GrossCondition`""
    Add-Line "		`"cf: $Prefix month expenses`" += `"$ExpensesCondition`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: $Prefix month expenses`" += $ManagerCost"
    }
    Add-Line "		`"cf: $Prefix month net`" += `"$ProfitCondition`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: $Prefix month net`" -= $ManagerCost"
    }
}

function Add-ShuttleDailyAccountingLines {
    param([int]$ManagerCost = 0)

    Add-Line "		`"cf: shuttle day gross`" = 0"
    Add-Line "		`"cf: shuttle day expenses`" = 0"
    Add-Line "		`"cf: shuttle day profit`" = 0"
    Add-RouteAccountingLines "local" 4 700
    Add-RouteAccountingLines "regional" 6 1400
    Add-RouteAccountingLines "long" 8 2100
    Add-RouteAccountingLines "frontier" 10 2800
    Add-Line "		`"cf: last gross`" = `"cf: shuttle day gross`""
    Add-Line "		`"cf: last expenses`" = `"cf: shuttle day expenses`""
    Add-Line "		`"cf: last net profit`" = `"cf: shuttle day profit`""
    Add-Line "		`"cf: manager daily cost`" = 0"
    Add-DivisionPeriodAccountingLines "shuttle" "cf: shuttle day gross" "cf: shuttle day expenses" "cf: shuttle day profit" $ManagerCost
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: manager daily cost`" = $ManagerCost"
        Add-Line "		`"cf: last expenses`" += $ManagerCost"
        Add-Line "		`"cf: last net profit`" -= $ManagerCost"
        Add-Line "		`"cf: total manager costs`" += $ManagerCost"
    }
    Add-StaffAndTaxCalculationLines
    Add-OfficeStaffCostAccountingLines
    Add-StationDailyAccountingLines
    Add-Line "		`"cf: last expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: month tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last owner payout`" = 0"
    Add-Line "		`"cf: last retained earnings`" = `"cf: last net profit`""
    Add-Line "		`"cf: reserve`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: unallocated net`" += `"cf: last net profit`""
    Add-Line "		`"cf: total gross`" += `"cf: shuttle day gross`""
    Add-Line "		`"cf: total operating expenses`" += `"cf: shuttle day expenses`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total operating expenses`" += $ManagerCost"
    }
    Add-Line "		`"cf: total operating expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: total net profit`" += `"cf: shuttle day profit`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total net profit`" -= $ManagerCost"
    }
    Add-Line "		`"cf: total net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total retained earnings`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: month gross`" += `"cf: shuttle day gross`""
    Add-Line "		`"cf: month expenses`" += `"cf: last expenses`""
    Add-Line "		`"cf: month net profit`" += `"cf: last net profit`""
    Add-Line "		`"cf: month retained earnings`" += `"cf: last retained earnings`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: month manager costs`" += $ManagerCost"
    }
}

function Add-FixedDailyAccountingLines {
    param(
        [int]$Gross,
        [int]$OperatingExpenses = 0,
        [int]$ManagerCost = 0
    )

    $totalExpenses = $OperatingExpenses + $ManagerCost
    $netProfit = $Gross - $totalExpenses
    Add-Line "		`"cf: last gross`" = $Gross"
    Add-Line "		`"cf: last expenses`" = $totalExpenses"
    Add-Line "		`"cf: last net profit`" = $netProfit"
    Add-Line "		`"cf: last owner payout`" = 0"
    Add-Line "		`"cf: last retained earnings`" = $netProfit"
    Add-Line "		`"cf: reserve`" += $netProfit"
    Add-Line "		`"cf: unallocated net`" += $netProfit"
    Add-Line "		`"cf: total gross`" += $Gross"
    Add-Line "		`"cf: total operating expenses`" += $totalExpenses"
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total manager costs`" += $ManagerCost"
        Add-Line "		`"cf: month manager costs`" += $ManagerCost"
    }
    Add-Line "		`"cf: total net profit`" += $netProfit"
    Add-Line "		`"cf: total retained earnings`" += $netProfit"
    Add-Line "		`"cf: month gross`" += $Gross"
    Add-Line "		`"cf: month expenses`" += $totalExpenses"
    Add-Line "		`"cf: month net profit`" += $netProfit"
    Add-Line "		`"cf: month retained earnings`" += $netProfit"
}

function Add-HQTaxAccountingLines {
    Add-Line "		`"cf: last expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total operating expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: total tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: total net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: month expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: month tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: month net profit`" -= `"cf: hq daily tax`""
}

function Add-StationDailyAccountingLines {
    Add-Line "		`"cf: last gross`" += `"cf: station daily income`""
    Add-Line "		`"cf: last expenses`" += `"cf: station daily upkeep`""
    Add-Line "		`"cf: last net profit`" += `"cf: station daily income`""
    Add-Line "		`"cf: last net profit`" -= `"cf: station daily upkeep`""
    Add-Line "		`"cf: total station revenue`" += `"cf: station daily income`""
    Add-Line "		`"cf: total station upkeep`" += `"cf: station daily upkeep`""
    Add-Line "		`"cf: total gross`" += `"cf: station daily income`""
    Add-Line "		`"cf: total operating expenses`" += `"cf: station daily upkeep`""
    Add-Line "		`"cf: total net profit`" += `"cf: station daily income`""
    Add-Line "		`"cf: total net profit`" -= `"cf: station daily upkeep`""
    Add-Line "		`"cf: month station revenue`" += `"cf: station daily income`""
    Add-Line "		`"cf: month station upkeep`" += `"cf: station daily upkeep`""
    Add-Line "		`"cf: month gross`" += `"cf: station daily income`""
}

function Add-StaffAndTaxCalculationLines {
    Add-Line "		`"cf: worker staff`" = 0"
    foreach($route in $shuttleRouteTypes) {
        Add-Line "		`"cf: worker staff`" += `"cf: shuttle $($route.Prefix) daily crew`" / 100"
    }
    foreach($claim in $miningClaimTypes) {
        Add-Line "		`"cf: worker staff`" += `"cf: mining $($claim.Prefix) daily crew`" / 100"
    }
    foreach($route in $tradingRouteTypes) {
        Add-Line "		`"cf: worker staff`" += `"cf: trading $($route.Prefix) daily crew`" / 100"
    }
    foreach($contract in $securityContractTypes) {
        Add-Line "		`"cf: worker staff`" += `"cf: security $($contract.Prefix) daily crew`" / 100"
    }
    Add-Line "		`"cf: worker staff`" += `"cf: admiral daily crew`" / 100"

    Add-Line "		`"cf: office staff`" = `"cf: worker staff`""
    Add-Line "		`"cf: office staff`" -= 1"
    Add-Line "		`"cf: office staff`" >?= 0"
    Add-Line "		`"cf: office staff`" /= 2"

    Add-Line "		`"cf: specialist staff`" = 0"
    foreach($route in $tradingRouteTypes) {
        Add-Line "		`"cf: specialist staff`" += `"cf: trading $($route.Prefix) trader`""
    }
    Add-Line "		`"cf: specialist staff`" += `"cf: managed`""
    Add-Line "		`"cf: specialist staff`" += `"cf: security admiral`""

    Add-Line "		`"cf: total staff`" = `"cf: worker staff`""
    Add-Line "		`"cf: total staff`" += `"cf: office staff`""
    Add-Line "		`"cf: total staff`" += `"cf: specialist staff`""

    Add-Line "		`"cf: office daily cost`" = `"cf: office staff`" * 100"
    Add-Line "		`"cf: employee tax`" = `"cf: total staff`" * 5"
    Add-Line "		`"cf: employee tax`" += `"cf: total staff`" / 5 * 20"
    Add-Line "		`"cf: employee tax`" += `"cf: total staff`" / 10 * 40"
    Add-Line "		`"cf: employee tax`" += `"cf: total staff`" / 20 * 100"
    Add-Line "		`"cf: employee tax`" += `"cf: total staff`" / 50 * 250"
    Add-Line "		`"cf: employee tax`" += `"cf: total staff`" / 100 * 600"
    Add-Line "		`"cf: employee tax`" += `"cf: total staff`" / 500 * 4000"
    Add-Line "		`"cf: employee tax`" += `"cf: total staff`" / 1000 * 10000"

    Add-Line "		`"cf: hq daily tax`" = `"cf: hq base tax`""
    Add-Line "		`"cf: hq daily tax`" += `"cf: employee tax`""
    Add-Line "		`"cf: hq daily tax`" -= `"cf: hq tax relief`""
    Add-Line "		`"cf: hq daily tax`" >?= 0"
}

function Add-OfficeStaffCostAccountingLines {
    Add-Line "		`"cf: last expenses`" += `"cf: office daily cost`""
    Add-Line "		`"cf: last net profit`" -= `"cf: office daily cost`""
    Add-Line "		`"cf: total operating expenses`" += `"cf: office daily cost`""
    Add-Line "		`"cf: total office staff costs`" += `"cf: office daily cost`""
    Add-Line "		`"cf: total net profit`" -= `"cf: office daily cost`""
    Add-Line "		`"cf: month office staff costs`" += `"cf: office daily cost`""
}

$planets = New-Object System.Collections.Generic.List[object]
$current = $null

foreach($line in Get-Content -LiteralPath $BaseData) {
    if($line -match '^planet\s+') {
        if($current -ne $null) {
            $planets.Add([pscustomobject]$current)
        }
        $tokens = ConvertFrom-ESTokenLine $line
        $current = @{
            Name = $tokens[1]
            Attributes = @()
            Government = ""
            HasSpaceport = $false
            Shipyards = @()
            RequiredReputation = 0
            Tribute = 0
            TributeThreshold = 0
        }
        continue
    }

    if($current -eq $null) {
        continue
    }

    if($line -match '^\S') {
        $planets.Add([pscustomobject]$current)
        $current = $null
        continue
    }

    if($line -match '^\s+attributes\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        $current.Attributes = @($tokens | Select-Object -Skip 1)
    } elseif($line -match '^\s+government\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        $current.Government = $tokens[1]
    } elseif($line -match '^\s+spaceport(\s|$)') {
        $current.HasSpaceport = $true
    } elseif($line -match '^\s+shipyard\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 1 -and $tokens[1] -ne "clear") {
            $current.Shipyards += $tokens[1]
        }
    } elseif($line -match '^\s+"required reputation"\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 1) {
            $current.RequiredReputation = [int][double]$tokens[1]
        }
    } elseif($line -match '^\s+tribute\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 1 -and $tokens[1] -ne "clear") {
            $current.Tribute = [int]$tokens[1]
        }
    } elseif($line -match '^\s+threshold\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 1 -and $current.Tribute -gt 0) {
            $current.TributeThreshold = [int]$tokens[1]
        }
    }
}

if($current -ne $null) {
    $planets.Add([pscustomobject]$current)
}

$planetsByName = @{}
foreach($planet in $planets) {
    $planetsByName[$planet.Name] = $planet
}

$systemsByName = @{}
$systemsByPlanet = @{}
$currentSystem = $null

foreach($line in Get-Content -LiteralPath $SystemData) {
    if($line -match '^system\s+') {
        if($currentSystem -ne $null) {
            $systemsByName[$currentSystem.Name] = [pscustomobject]$currentSystem
        }
        $tokens = ConvertFrom-ESTokenLine $line
        $currentSystem = @{
            Name = $tokens[1]
            Government = ""
            Attributes = @()
            Links = @()
            Planets = @()
            Minables = @()
            Trade = @{}
        }
        continue
    }

    if($currentSystem -eq $null) {
        continue
    }

    if($line -match '^\S') {
        $systemsByName[$currentSystem.Name] = [pscustomobject]$currentSystem
        $currentSystem = $null
        continue
    }

    if($line -match '^\s+government\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        $currentSystem.Government = $tokens[1]
    } elseif($line -match '^\s+attributes\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        $currentSystem.Attributes = @($tokens | Select-Object -Skip 1)
    } elseif($line -match '^\s+link\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 1) {
            $currentSystem.Links += $tokens[1]
        }
    } elseif($line -match '^\s+object\s+\S') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 1) {
            $currentSystem.Planets += $tokens[1]
        }
    } elseif($line -match '^\s+minables\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 3) {
            $currentSystem.Minables += [pscustomobject]@{
                Name = $tokens[1]
                Abundance = [double]$tokens[2]
                Density = [double]$tokens[3]
            }
        }
    } elseif($line -match '^\s+trade\s+') {
        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -gt 2) {
            $currentSystem.Trade[$tokens[1]] = [int]$tokens[2]
        }
    }
}

if($currentSystem -ne $null) {
    $systemsByName[$currentSystem.Name] = [pscustomobject]$currentSystem
}

foreach($system in $systemsByName.Values) {
    foreach($planetName in @($system.Planets)) {
        $systemsByPlanet[$planetName] = [pscustomobject]@{
            Name = $system.Name
            Government = $system.Government
            Attributes = @($system.Attributes)
        }
    }
}

$shipsByShipyard = @{}
$soldShipNames = New-Object System.Collections.Generic.HashSet[string]
$shipyardFiles = @(Get-ChildItem -LiteralPath $DataRoot -Recurse -Filter "*.txt" -File)
foreach($file in $shipyardFiles) {
    $currentShipyard = $null
    foreach($line in Get-Content -LiteralPath $file.FullName) {
        if($line -match '^shipyard\s+') {
            $tokens = ConvertFrom-ESTokenLine $line
            if($tokens.Count -gt 1 -and $tokens[1] -ne "clear") {
                $currentShipyard = $tokens[1]
                if(-not $shipsByShipyard.ContainsKey($currentShipyard)) {
                    $shipsByShipyard[$currentShipyard] = New-Object System.Collections.Generic.HashSet[string]
                }
            }
            continue
        }

        if($null -eq $currentShipyard) {
            continue
        }

        if($line -match '^\S') {
            $currentShipyard = $null
            continue
        }

        if($line -match '^\s+\S') {
            $tokens = ConvertFrom-ESTokenLine $line
            if($tokens.Count -gt 0 -and $tokens[0] -notlike "#*") {
                [void]$shipsByShipyard[$currentShipyard].Add($tokens[0])
                [void]$soldShipNames.Add($tokens[0])
            }
        }
    }
}

function New-CFKey {
    param([string]$Text)

    $key = $Text.ToLowerInvariant() -replace '[^a-z0-9]+', ' '
    return $key.Trim()
}

$shipsByName = @{}
function Add-ParsedShip {
    param([hashtable]$Ship)

    if($null -eq $Ship -or -not $Ship.Name) {
        return
    }
    if(-not $soldShipNames.Contains($Ship.Name)) {
        return
    }
    if([int]$Ship.Cost -le 0) {
        return
    }

    $shipsByName[$Ship.Name] = [pscustomobject]@{
        Name = $Ship.Name
        Category = $Ship.Category
        Cost = [int]$Ship.Cost
        Crew = [int]$Ship.Crew
        Bunks = [int]$Ship.Bunks
        Cargo = [int]$Ship.Cargo
        Shields = [long]$Ship.Shields
        Hull = [long]$Ship.Hull
    }
}

foreach($file in $shipyardFiles) {
    $currentShip = $null
    foreach($line in Get-Content -LiteralPath $file.FullName) {
        if($line -match '^ship\s+') {
            Add-ParsedShip $currentShip
            $tokens = ConvertFrom-ESTokenLine $line
            $shipName = if($tokens.Count -gt 2) { $tokens[$tokens.Count - 1] } else { $tokens[1] }
            $currentShip = @{
                Name = $shipName
                Category = ""
                Cost = 0
                Crew = 0
                Bunks = 0
                Cargo = 0
                Shields = 0
                Hull = 0
            }
            continue
        }

        if($null -eq $currentShip) {
            continue
        }

        if($line -match '^\S') {
            Add-ParsedShip $currentShip
            $currentShip = $null
            continue
        }

        $tokens = ConvertFrom-ESTokenLine $line
        if($tokens.Count -lt 2) {
            continue
        }

        switch($tokens[0]) {
            "category" { $currentShip.Category = $tokens[1] }
            "cost" { $currentShip.Cost = [int]$tokens[1] }
            "required crew" { $currentShip.Crew = [int]$tokens[1] }
            "bunks" { $currentShip.Bunks = [int]$tokens[1] }
            "cargo space" { $currentShip.Cargo = [int]$tokens[1] }
            "shields" { $currentShip.Shields = [long]$tokens[1] }
            "hull" { $currentShip.Hull = [long]$tokens[1] }
        }
    }
    Add-ParsedShip $currentShip
}

function Get-KnownPlanetCondition {
    param([string]$Planet)
    return "cf: known planet: $Planet"
}

function Get-KnownSystemCondition {
    param([string]$System)
    return "cf: known system: $System"
}

function Get-KnownShipyardCondition {
    param([string]$Shipyard)
    return "cf: known shipyard: $Shipyard"
}

function Get-ShipAvailableCondition {
    param([string]$Ship)
    return "cf: ship available: $Ship"
}

function Add-ConditionLine {
    param(
        [string]$Command,
        [string]$Condition,
        [string]$Indent = "		"
    )

    Add-Line "$Indent$Command $(Format-ESMissionName $Condition)"
}

function Add-KnownSystemRequirement {
    param(
        [string]$System,
        [string]$Indent = "						"
    )

    Add-ConditionLine "has" (Get-KnownSystemCondition $System) $Indent
}

function Add-KnownPlanetRequirement {
    param(
        [string]$Planet,
        [string]$Indent = "						"
    )

    Add-ConditionLine "has" (Get-KnownPlanetCondition $Planet) $Indent
}

function Get-ShipProcurementName {
    param([object]$Ship)

    if($Ship.PSObject.Properties.Name -contains "Procurement" -and $Ship.Procurement) {
        return $Ship.Procurement
    }
    return $Ship.Name
}

function Add-ShipAvailabilityRequirement {
    param(
        [object]$Ship,
        [string]$Indent = "						"
    )

    Add-ConditionLine "has" (Get-ShipAvailableCondition (Get-ShipProcurementName $Ship)) $Indent
}

function Add-PlanetDiscoveryActions {
    param(
        [object]$Planet,
        [string]$Indent = "		"
    )

    Add-ConditionLine "set" (Get-KnownPlanetCondition $Planet.Name) $Indent
    if($systemsByPlanet.ContainsKey($Planet.Name)) {
        Add-ConditionLine "set" (Get-KnownSystemCondition $systemsByPlanet[$Planet.Name].Name) $Indent
    }

    foreach($shipyard in @($Planet.Shipyards | Sort-Object -Unique)) {
        Add-ConditionLine "set" (Get-KnownShipyardCondition $shipyard) $Indent
        if($shipsByShipyard.ContainsKey($shipyard)) {
            foreach($ship in @($shipsByShipyard[$shipyard] | Sort-Object)) {
                Add-ConditionLine "set" (Get-ShipAvailableCondition $ship) $Indent
            }
        }
    }
}

function Get-PlanetGovernmentName {
    param([object]$Planet)

    if($Planet.Government) {
        return $Planet.Government
    }
    if($systemsByPlanet.ContainsKey($Planet.Name)) {
        return $systemsByPlanet[$Planet.Name].Government
    }
    return ""
}

function Get-HQTaxRate {
    param([object]$Planet)

    $system = if($systemsByPlanet.ContainsKey($Planet.Name) -and $systemsByName.ContainsKey($systemsByPlanet[$Planet.Name].Name)) {
        $systemsByName[$systemsByPlanet[$Planet.Name].Name]
    } else {
        $null
    }
    $attributes = @()
    if($null -ne $system) {
        $attributes += @($system.Attributes)
    }
    $attributes += @($Planet.Attributes)
    $government = Get-PlanetGovernmentName $Planet

    $tax = 300
    if($government -in @("Republic", "Syndicate", "Free Worlds", "Deep Security")) {
        $tax = 350
    }
    if($government -in @("Hai", "Coalition", "Heliarch")) {
        $tax = 450
    }
    if(@($attributes | Where-Object { $_ -in @("rim", "frontier", "dirt belt", "south pirate", "north pirate", "core pirate", "pirate") }).Count -gt 0) {
        $tax -= 150
    }
    if($government -in @("Pirate", "Independent", "Neutral")) {
        $tax = [math]::Min($tax, 250)
    }
    if(@($attributes | Where-Object { $_ -in @("south") }).Count -gt 0) {
        $tax -= 100
    }
    if(@($attributes | Where-Object { $_ -in @("core", "urban", "capital", "paradise") }).Count -gt 0) {
        $tax += 700
    }
    if(@($attributes | Where-Object { $_ -in @("rich", "factory", "military") }).Count -gt 0) {
        $tax += 250
    }
    if(@($attributes | Where-Object { $_ -in @("tourism") }).Count -gt 0) {
        $tax += 150
    }
    if($tax -lt 100) {
        return 100
    }
    if($tax -gt 2000) {
        return 2000
    }
    return $tax
}

function Add-ReputationRequirement {
    param(
        [string]$Government,
        [int]$RequiredReputation,
        [string]$Indent = "		"
    )

    if($Government -and $Government -notin @("Uninhabited", "Derelict", "Wormhole")) {
        Add-Line "$Indent`"reputation: $Government`" >= $RequiredReputation"
    }
}

function Add-ReputationFailureRequirement {
    param(
        [string]$Government,
        [int]$RequiredReputation,
        [string]$Indent = "		"
    )

    if($Government -and $Government -notin @("Uninhabited", "Derelict", "Wormhole")) {
        Add-Line "$Indent`"reputation: $Government`" < $RequiredReputation"
    }
}

function Add-RestartOperationsActions {
    param([string]$Indent = "		")

    Add-Line "${Indent}clear `"cf: manual active`""
    Add-Line "${Indent}clear `"cf: manager active`""
    Add-Line "$Indent`"cf: manual pending`" = 1"
    Add-Line "$Indent`"cf: manager pending`" = 1"
    Add-Line "${Indent}fail `"Company Foundations: Shuttle Manual Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Mining Manual Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Trading Manual Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Security Manual Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Shuttle Managed Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Mining Managed Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Trading Managed Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Security Managed Operations`""
    Add-ClearOperationsMissionStateActions $Indent
}

function Add-ManagerResignationActions {
    param([string]$Indent = "		")

    Add-Line "$Indent`"cf: manager resignations`" ++"
    Add-Line "$Indent`"cf: manager unpaid days`" = 0"
    Add-Line "$Indent`"cf: manager daily cost`" = 0"
    Add-Line "${Indent}clear `"cf: manager salary checked`""
    Add-Line "${Indent}clear `"cf: manager active`""
    Add-Line "${Indent}clear `"cf: manager pending`""
    Add-Line "${Indent}clear `"cf: managed`""
    Add-Line "${Indent}set `"cf: manual`""
    Add-Line "${Indent}set `"cf: manual pending`""
    Add-Line "${Indent}fail `"Company Foundations: Shuttle Managed Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Mining Managed Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Trading Managed Operations`""
    Add-Line "${Indent}fail `"Company Foundations: Security Managed Operations`""
    Add-ClearOperationsMissionStateActions $Indent
}

$operationMissionNames = @(
    "Company Foundations: Shuttle Manual Operations",
    "Company Foundations: Mining Manual Operations",
    "Company Foundations: Trading Manual Operations",
    "Company Foundations: Security Manual Operations",
    "Company Foundations: Shuttle Managed Operations",
    "Company Foundations: Mining Managed Operations",
    "Company Foundations: Trading Managed Operations",
    "Company Foundations: Security Managed Operations"
)

$operationCompanyTypes = @(
    [pscustomobject]@{ Key = "shuttle"; Title = "Shuttle" },
    [pscustomobject]@{ Key = "mining"; Title = "Mining" },
    [pscustomobject]@{ Key = "trading"; Title = "Trading" },
    [pscustomobject]@{ Key = "security"; Title = "Security" }
)

function Add-ClearOperationsMissionStateActions {
    param([string]$Indent = "		")

    foreach($missionName in $operationMissionNames) {
        foreach($suffix in @("failed", "offered", "done", "declined")) {
            Add-Line "${Indent}clear `"$missionName`: $suffix`""
        }
    }
}

function Add-OperationStateRepairMission {
    param(
        [object]$CompanyType,
        [string]$Mode
    )

    $isManaged = $Mode -eq "Managed"
    $modeCondition = if($isManaged) { "cf: managed" } else { "cf: manual" }
    $pendingCondition = if($isManaged) { "cf: manager pending" } else { "cf: manual pending" }
    $activeCondition = if($isManaged) { "cf: manager active" } else { "cf: manual active" }
    $otherPendingCondition = if($isManaged) { "cf: manual pending" } else { "cf: manager pending" }
    $otherActiveCondition = if($isManaged) { "cf: manual active" } else { "cf: manager active" }
    $otherModeCondition = if($isManaged) { "cf: manual" } else { "cf: managed" }
    $failedMission = "Company Foundations: $($CompanyType.Title) $Mode Operations: failed"
    $missionName = Format-ESMissionName "Company Foundations: Repair $($CompanyType.Title) $Mode Operations"
    $logMode = if($isManaged) { "manager-run" } else { "owner-managed" }

    Add-Line "mission $missionName"
    Add-Line "	name `"Company Operations Repair`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		has `"cf: $($CompanyType.Key)`""
    Add-Line "		has `"$modeCondition`""
    Add-Line "		has `"$failedMission`""
    Add-Line "	on offer"
    Add-ClearOperationsMissionStateActions "		"
    Add-Line "		clear `"$otherPendingCondition`""
    Add-Line "		clear `"$otherActiveCondition`""
    Add-Line "		clear `"$otherModeCondition`""
    Add-Line "		clear `"$activeCondition`""
    Add-Line "		set `"$modeCondition`""
    Add-Line "		set `"$pendingCondition`""
    Add-Line "		log `"Company Foundations`" `"Operations Repair`" ``A stale failed $($CompanyType.Key) $($Mode.ToLowerInvariant()) operations state was cleared. The company will restart $logMode daily accounting on the next landing.``"
    Add-Line ""
}

function Add-ClearAllHQConditions {
    param([string]$Indent = "		")

    foreach($candidate in $eligible) {
        Add-ConditionLine "clear" "cf: hq: $($candidate.Name)" $Indent
    }
}

function Add-ClearAllAdmiralLocationConditions {
    param([string]$Indent = "		")

    foreach($candidate in $eligible) {
        Add-ConditionLine "clear" "cf: admiral location: $($candidate.Name)" $Indent
    }
}

function Add-ClearAllAdmiralDestinationConditions {
    param([string]$Indent = "		")

    foreach($candidate in $eligible) {
        Add-ConditionLine "clear" "cf: admiral destination: $($candidate.Name)" $Indent
    }
}

$eligible = $planets |
    Where-Object {
        $system = $systemsByPlanet[$_.Name]
        $_.HasSpaceport -and
        $null -ne $system -and
        $_.Name -notlike "Wormhole*" -and
        $_.Government -notlike "Wormhole*" -and
        $system.Government -notlike "Wormhole*"
    } |
    Sort-Object Name

$eligibleBySystem = @{}
foreach($planet in $eligible) {
    $systemName = $systemsByPlanet[$planet.Name].Name
    if(-not $eligibleBySystem.ContainsKey($systemName)) {
        $eligibleBySystem[$systemName] = New-Object System.Collections.Generic.List[string]
    }
    $eligibleBySystem[$systemName].Add($planet.Name)
}

foreach($systemName in @($eligibleBySystem.Keys)) {
    $eligibleBySystem[$systemName] = @($eligibleBySystem[$systemName] | Sort-Object)
}

$companyStationSystems = @(
    $systemsByName.Values |
        Where-Object {
            $system = $_
            $isHumanRegion = @($system.Attributes | Where-Object { $_ -in $humanSystemAttributes }).Count -gt 0
            $hasExcludedRegion = @($system.Attributes | Where-Object { $_ -in $excludedSystemAttributes }).Count -gt 0
            $landableObjects = @($system.Planets | Where-Object {
                $planetsByName.ContainsKey($_) -and $planetsByName[$_].HasSpaceport
            })

            $isHumanRegion -and
                -not $hasExcludedRegion -and
                $landableObjects.Count -eq 0 -and
                $system.Name -notlike "Wormhole*"
        } |
        Sort-Object Name
)

function Find-RouteTarget {
    param(
        [string]$FromPlanet,
        [int]$DesiredDistance
    )

    $fromSystem = $systemsByPlanet[$FromPlanet].Name
    $visited = @{}
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue([pscustomobject]@{ Name = $fromSystem; Distance = 0 })
    $visited[$fromSystem] = $true
    $candidates = New-Object System.Collections.Generic.List[object]

    while($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if($current.Distance -gt 0 -and $eligibleBySystem.ContainsKey($current.Name)) {
            foreach($planetName in $eligibleBySystem[$current.Name]) {
                if($planetName -ne $FromPlanet) {
                    $candidates.Add([pscustomobject]@{
                        Planet = $planetName
                        System = $current.Name
                        Distance = $current.Distance
                    })
                }
            }
        }

        if($current.Distance -ge 6 -or -not $systemsByName.ContainsKey($current.Name)) {
            continue
        }

        foreach($link in @($systemsByName[$current.Name].Links | Sort-Object)) {
            if(-not $visited.ContainsKey($link) -and $systemsByName.ContainsKey($link)) {
                $visited[$link] = $true
                $queue.Enqueue([pscustomobject]@{ Name = $link; Distance = $current.Distance + 1 })
            }
        }
    }

    $exact = @($candidates | Where-Object { $_.Distance -eq $DesiredDistance } | Sort-Object Planet | Select-Object -First 1)
    if($exact.Count -gt 0) {
        return $exact[0]
    }

    $fallback = @($candidates | Where-Object { $_.Distance -gt 0 } | Sort-Object @{ Expression = { [math]::Abs($_.Distance - $DesiredDistance) } }, Planet | Select-Object -First 1)
    if($fallback.Count -gt 0) {
        return $fallback[0]
    }

    return [pscustomobject]@{
        Planet = "nearby passenger boards"
        System = $fromSystem
        Distance = $DesiredDistance
    }
}

$outputRoot = Split-Path -Parent $OutFile
$outputSections = [ordered]@{}
$currentOutputSection = "company core.txt"

function Set-OutputSection {
    param([string]$Name)

    $script:currentOutputSection = $Name
    if($Name -eq "__discard") {
        return
    }
    if(-not $script:outputSections.Contains($Name)) {
        $script:outputSections[$Name] = New-Object System.Collections.Generic.List[string]
        $script:outputSections[$Name].Add("# Company Foundations")
        $script:outputSections[$Name].Add("")
    }
}

function Add-Line([string]$Line = "") {
    if($script:currentOutputSection -eq "__discard") {
        return
    }
    if(-not $script:outputSections.Contains($script:currentOutputSection)) {
        Set-OutputSection $script:currentOutputSection
    }
    $script:outputSections[$script:currentOutputSection].Add($Line)
}

Set-OutputSection "company core.txt"

$mineralBaseCosts = @{
    aluminum = 1800
    copper = 3000
    gold = 8000
    iron = 1200
    lead = 900
    neodymium = 3800
    platinum = 10000
    silicon = 400
    silver = 6000
    titanium = 2500
    tungsten = 4500
    uranium = 5000
    yottrite = 200000
}

$mineralMarkets = @{
    aluminum = "Metal"
    iron = "Metal"
    silicon = "Metal"
    copper = "Industrial"
    neodymium = "Industrial"
    titanium = "Industrial"
    tungsten = "Heavy Metals"
    lead = "Heavy Metals"
    uranium = "Heavy Metals"
    gold = "Luxury Goods"
    platinum = "Luxury Goods"
    silver = "Luxury Goods"
    yottrite = "Luxury Goods"
}

$marketBaselines = @{
    Metal = 390
    Industrial = 720
    "Heavy Metals" = 960
    "Luxury Goods" = 1220
}

function Get-SystemTradePrice {
    param(
        [object]$System,
        [string]$Commodity,
        [object]$FallbackSystem
    )

    if($null -ne $System -and $System.Trade.ContainsKey($Commodity)) {
        return [double]$System.Trade[$Commodity]
    }
    if($null -ne $FallbackSystem -and $FallbackSystem.Trade.ContainsKey($Commodity)) {
        return [double]$FallbackSystem.Trade[$Commodity]
    }
    return [double]$marketBaselines[$Commodity]
}

function Get-MiningSystemValue {
    param(
        [object]$System,
        [object]$FallbackSystem
    )

    if($null -eq $System -or @($System.Minables).Count -eq 0) {
        return [pscustomobject]@{
            ValuePerCargo = 90
            Quality = 0
            Summary = "low-grade salvage"
        }
    }

    $weightedValue = 0.0
    $weightedMass = 0.0
    $bestMineral = ""
    $bestScore = 0.0

    foreach($minable in @($System.Minables)) {
        $key = $minable.Name.ToLowerInvariant()
        if(-not $mineralBaseCosts.ContainsKey($key)) {
            continue
        }

        $commodity = $mineralMarkets[$key]
        $baseCost = [double]$mineralBaseCosts[$key]
        $marketPrice = Get-SystemTradePrice $System $commodity $FallbackSystem
        $marketMultiplier = $marketPrice / [double]$marketBaselines[$commodity]
        $presence = [double]$minable.Abundance * [double]$minable.Density
        $adjustedValue = $baseCost * $marketMultiplier

        $weightedValue += $adjustedValue * $presence
        $weightedMass += $presence

        $score = $adjustedValue * $presence
        if($score -gt $bestScore) {
            $bestScore = $score
            $bestMineral = $minable.Name
        }
    }

    if($weightedMass -le 0) {
        return [pscustomobject]@{
            ValuePerCargo = 90
            Quality = 0
            Summary = "low-grade salvage"
        }
    }

    $averageValue = $weightedValue / $weightedMass
    $richnessMultiplier = 0.70 + [math]::Min(0.80, $weightedMass / 200.0)
    $valuePerCargo = [math]::Max(90, [math]::Round(($averageValue / 20.0) * $richnessMultiplier))
    return [pscustomobject]@{
        ValuePerCargo = [int]$valuePerCargo
        Quality = [int][math]::Round($weightedMass)
        Summary = "$bestMineral ore field"
    }
}

function Find-MiningClaimTarget {
    param(
        [string]$FromPlanet,
        [int]$DesiredDistance,
        [string[]]$ExcludeSystems = @()
    )

    $fromSystem = $systemsByPlanet[$FromPlanet].Name
    $fallbackSystem = $systemsByName[$fromSystem]
    $visited = @{}
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue([pscustomobject]@{ Name = $fromSystem; Distance = 0 })
    $visited[$fromSystem] = $true
    $candidates = New-Object System.Collections.Generic.List[object]

    while($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if($systemsByName.ContainsKey($current.Name)) {
            $system = $systemsByName[$current.Name]
            $isAllowed =
                -not ($excludedGovernments -contains $system.Government) -and
                $system.Government -notlike "Wormhole*" -and
                -not (@($system.Attributes) | Where-Object { $excludedSystemAttributes -contains $_ }) -and
                -not ($ExcludeSystems -contains $system.Name)

            if($isAllowed -and @($system.Minables).Count -gt 0) {
                $value = Get-MiningSystemValue $system $fallbackSystem
                $candidates.Add([pscustomobject]@{
                    System = $system.Name
                    Distance = $current.Distance
                    ValuePerCargo = $value.ValuePerCargo
                    Quality = $value.Quality
                    Summary = $value.Summary
                })
            }
        }

        if($current.Distance -ge 6 -or -not $systemsByName.ContainsKey($current.Name)) {
            continue
        }

        foreach($link in @($systemsByName[$current.Name].Links | Sort-Object)) {
            if(-not $visited.ContainsKey($link) -and $systemsByName.ContainsKey($link)) {
                $visited[$link] = $true
                $queue.Enqueue([pscustomobject]@{ Name = $link; Distance = $current.Distance + 1 })
            }
        }
    }

    $exact = @($candidates | Where-Object { $_.Distance -eq $DesiredDistance } | Sort-Object @{ Expression = { -$_.ValuePerCargo } }, System | Select-Object -First 1)
    if($exact.Count -gt 0) {
        return $exact[0]
    }

    $fallback = @($candidates | Sort-Object @{ Expression = { [math]::Abs($_.Distance - $DesiredDistance) } }, @{ Expression = { -$_.ValuePerCargo } }, System | Select-Object -First 1)
    if($fallback.Count -gt 0) {
        return $fallback[0]
    }

    return [pscustomobject]@{
        System = $fromSystem
        Distance = $DesiredDistance
        ValuePerCargo = 90
        Quality = 0
        Summary = "low-grade salvage"
    }
}

$tradeCommodities = @(
    "Food", "Clothing", "Metal", "Plastic", "Equipment", "Medical",
    "Industrial", "Electronics", "Heavy Metals", "Luxury Goods"
)

function Get-TradeRouteValue {
    param(
        [object]$FromSystem,
        [object]$ToSystem
    )

    $bestCommodity = "general cargo"
    $bestSpread = 40

    foreach($commodity in $tradeCommodities) {
        if($null -eq $FromSystem -or $null -eq $ToSystem) {
            continue
        }
        if(-not $FromSystem.Trade.ContainsKey($commodity) -or -not $ToSystem.Trade.ContainsKey($commodity)) {
            continue
        }

        $spread = [math]::Abs([int]$ToSystem.Trade[$commodity] - [int]$FromSystem.Trade[$commodity])
        if($spread -gt $bestSpread) {
            $bestSpread = $spread
            $bestCommodity = $commodity
        }
    }

    $baseSpread = [math]::Max(35, [math]::Round($bestSpread * 0.60))
    return [pscustomobject]@{
        Commodity = $bestCommodity
        BaseValue = [int]$baseSpread
        OptimizedValue = [int]$bestSpread
    }
}

function Find-TradeRouteTarget {
    param(
        [string]$FromPlanet,
        [int]$DesiredDistance
    )

    $route = Find-RouteTarget $FromPlanet $DesiredDistance
    $fromSystemName = $systemsByPlanet[$FromPlanet].Name
    $fromSystem = $systemsByName[$fromSystemName]
    $toSystem = if($systemsByName.ContainsKey($route.System)) { $systemsByName[$route.System] } else { $fromSystem }
    $value = Get-TradeRouteValue $fromSystem $toSystem

    return [pscustomobject]@{
        Planet = $route.Planet
        System = $route.System
        Distance = $route.Distance
        Commodity = $value.Commodity
        BaseValue = $value.BaseValue
        OptimizedValue = $value.OptimizedValue
    }
}

function Get-SystemDistance {
    param(
        [string]$FromSystem,
        [string]$ToSystem,
        [int]$MaxDistance = 12
    )

    if($FromSystem -eq $ToSystem) {
        return 0
    }

    $visited = @{}
    $queue = New-Object System.Collections.Generic.Queue[object]
    $queue.Enqueue([pscustomobject]@{ Name = $FromSystem; Distance = 0 })
    $visited[$FromSystem] = $true

    while($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if($current.Distance -ge $MaxDistance -or -not $systemsByName.ContainsKey($current.Name)) {
            continue
        }

        foreach($link in @($systemsByName[$current.Name].Links | Sort-Object)) {
            if($visited.ContainsKey($link) -or -not $systemsByName.ContainsKey($link)) {
                continue
            }

            $distance = $current.Distance + 1
            if($link -eq $ToSystem) {
                return $distance
            }

            $visited[$link] = $true
            $queue.Enqueue([pscustomobject]@{ Name = $link; Distance = $distance })
        }
    }

    return 99
}

$pirateTributePlanets = @($planets |
    Where-Object {
        $_.HasSpaceport -and
        $_.Tribute -gt 0 -and
        (@($_.Attributes) | Where-Object { $_ -eq "pirate" })
    } |
    Sort-Object Name)

function Get-PirateTributeCandidates {
    param([string]$FromPlanet)

    $fromSystem = $systemsByPlanet[$FromPlanet].Name
    $candidates = New-Object System.Collections.Generic.List[object]

    foreach($planet in $pirateTributePlanets) {
        if(-not $systemsByPlanet.ContainsKey($planet.Name)) {
            continue
        }

        $system = $systemsByPlanet[$planet.Name].Name
        $distance = Get-SystemDistance $fromSystem $system 14
        if($distance -eq 99) {
            $distance = 14
        }

        $threshold = if($planet.TributeThreshold -gt 0) { $planet.TributeThreshold } else { [math]::Max(1000, $planet.Tribute * 3) }
        $requiredRating = [math]::Max(3, [int][math]::Ceiling($threshold / 500.0))
        $operationCost = [int]([math]::Ceiling($requiredRating * 20000 / 10000.0) * 10000)
        $candidates.Add([pscustomobject]@{
            Planet = $planet.Name
            System = $system
            Distance = $distance
            Tribute = [int]$planet.Tribute
            Threshold = [int]$threshold
            RequiredRating = [int]$requiredRating
            OperationCost = [int]$operationCost
        })
    }

    return @($candidates | Sort-Object Distance, RequiredRating, Planet)
}

function Select-PirateTributeTarget {
    param(
        [array]$Candidates,
        [int]$MinRating,
        [int]$MaxRating,
        [hashtable]$Used
    )

    $match = @($Candidates |
        Where-Object {
            $null -ne $_ -and
            $_.Planet -and
            $_.RequiredRating -ge $MinRating -and
            $_.RequiredRating -le $MaxRating -and
            -not $Used.ContainsKey($_.Planet)
        } |
        Sort-Object Distance, RequiredRating, Planet |
        Select-Object -First 1)

    if($match.Count -eq 0) {
        $match = @($Candidates |
            Where-Object { $null -ne $_ -and $_.Planet -and -not $Used.ContainsKey($_.Planet) } |
            Sort-Object @{ Expression = { [math]::Abs($_.RequiredRating - (($MinRating + $MaxRating) / 2)) } }, Distance, Planet |
            Select-Object -First 1)
    }

    if($match.Count -gt 0) {
        $Used[$match[0].Planet] = $true
        return $match[0]
    }

    if($MinRating -ge 13) {
        return [pscustomobject]@{ Planet = "Greenrock"; System = "Shaula"; Distance = 14; Tribute = 1800; Threshold = 3500; RequiredRating = 7; OperationCost = 140000 }
    }
    if($MinRating -ge 8) {
        return [pscustomobject]@{ Planet = "New Tortuga"; System = "Misam"; Distance = 14; Tribute = 1400; Threshold = 5000; RequiredRating = 10; OperationCost = 200000 }
    }
    if($MinRating -ge 5) {
        return [pscustomobject]@{ Planet = "Deadman's Cove"; System = "Almach"; Distance = 14; Tribute = 600; Threshold = 2500; RequiredRating = 5; OperationCost = 100000 }
    }
    return [pscustomobject]@{ Planet = "Stormhold"; System = "Alcyone"; Distance = 14; Tribute = 500; Threshold = 2000; RequiredRating = 4; OperationCost = 80000 }
}

function Get-PirateTributeTargets {
    param([string]$FromPlanet)

    $candidates = Get-PirateTributeCandidates $FromPlanet
    $used = @{}
    return @{
        minor = Select-PirateTributeTarget $candidates 3 4 $used
        raider = Select-PirateTributeTarget $candidates 5 7 $used
        cartel = Select-PirateTributeTarget $candidates 8 12 $used
        stronghold = Select-PirateTributeTarget $candidates 13 30 $used
    }
}

$shuttleShipTypes = @(
    [pscustomobject]@{ Key = "shuttle"; Name = "Shuttle"; Cost = 180000; Bunks = 6; Crew = 1; Luxury = $false },
    [pscustomobject]@{ Key = "heavy shuttle"; Name = "Heavy Shuttle"; Cost = 470000; Bunks = 10; Crew = 1; Luxury = $false },
    [pscustomobject]@{ Key = "bounder"; Name = "Bounder"; Cost = 1140000; Bunks = 17; Crew = 1; Luxury = $false },
    [pscustomobject]@{ Key = "blackbird"; Name = "Blackbird"; Cost = 2230000; Bunks = 28; Crew = 3; Luxury = $true },
    [pscustomobject]@{ Key = "hogshead"; Name = "Hogshead"; Cost = 3150000; Bunks = 84; Crew = 18; Luxury = $true },
    [pscustomobject]@{ Key = "star queen"; Name = "Star Queen"; Cost = 4200000; Bunks = 112; Crew = 33; Luxury = $true }
)

$shuttleRouteTypes = @(
    [pscustomobject]@{ Prefix = "local"; Name = "local"; Required = "cf: shuttle"; PaxCap = 48; Threshold = 4; Fare = 700; VipCost = 120000 },
    [pscustomobject]@{ Prefix = "regional"; Name = "regional"; Required = "cf: shuttle route regional"; PaxCap = 80; Threshold = 6; Fare = 1400; VipCost = 180000 },
    [pscustomobject]@{ Prefix = "long"; Name = "long"; Required = "cf: shuttle route long"; PaxCap = 140; Threshold = 8; Fare = 2100; VipCost = 260000 },
    [pscustomobject]@{ Prefix = "frontier"; Name = "frontier"; Required = "cf: shuttle route frontier"; PaxCap = 220; Threshold = 10; Fare = 2800; VipCost = 360000 }
)

$managerRoutePlans = @(
    [pscustomobject]@{ Prefix = "local"; Name = "local"; Required = "cf: shuttle"; Marker = "cf: manager local optimized"; Cost = 3170000; Pax = 48; Ships = 3; DailyCrew = 500; TripPayout = 11200; TripExpenses = 666; Luxury = $true; RequiredShips = @("Blackbird", "Heavy Shuttle"); Description = "1 Blackbird and 2 Heavy Shuttles" },
    [pscustomobject]@{ Prefix = "regional"; Name = "regional"; Required = "cf: shuttle route regional"; Marker = "cf: manager regional optimized"; Cost = 5650000; Pax = 79; Ships = 4; DailyCrew = 600; TripPayout = 27650; TripExpenses = 900; Luxury = $true; RequiredShips = @("Blackbird", "Bounder"); Description = "1 Blackbird and 3 Bounders" },
    [pscustomobject]@{ Prefix = "long"; Name = "long"; Required = "cf: shuttle route long"; Marker = "cf: manager long optimized"; Cost = 7610000; Pax = 140; Ships = 3; DailyCrew = 2400; TripPayout = 98000; TripExpenses = 6400; Luxury = $true; RequiredShips = @("Hogshead", "Blackbird"); Description = "1 Hogshead and 2 Blackbirds" },
    [pscustomobject]@{ Prefix = "frontier"; Name = "frontier"; Required = "cf: shuttle route frontier"; Marker = "cf: manager frontier optimized"; Cost = 9720000; Pax = 219; Ships = 5; DailyCrew = 3900; TripPayout = 122640; TripExpenses = 7800; Luxury = $true; RequiredShips = @("Hogshead", "Bounder"); Description = "2 Hogsheads and 3 Bounders" }
)

function Add-ShuttleShipChoice {
    param(
        [object]$Route,
        [object]$Ship
    )

    if($Ship.Bunks -gt $Route.PaxCap) {
        return
    }

    $luxuryText = if($Ship.Luxury) { " luxury" } else { "" }
    $maxCurrentPax = $Route.PaxCap - $Ship.Bunks
    Add-Line "				``	Buy a $($Ship.Bunks)-berth $($Ship.Name)$luxuryText for the $($Route.Name) route for $($Ship.Cost.ToString('N0')) company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"$($Route.Required)`""
    Add-ShipAvailabilityRequirement $Ship
    Add-Line "						`"cf: reserve`" >= $($Ship.Cost)"
    Add-Line "						`"cf: shuttle $($Route.Prefix) pax`" <= $maxCurrentPax"
    Add-Line "					goto `"confirm buy $($Route.Prefix) $($Ship.Key)`""
}

function Add-ShuttleVipChoice {
    param([object]$Route)

    Add-Line "				``	Open VIP service on the $($Route.Name) route for $($Route.VipCost.ToString('N0')) company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"$($Route.Required)`""
    Add-Line "						has `"cf: shuttle $($Route.Prefix) luxury`""
    Add-Line "						not `"cf: shuttle $($Route.Prefix) vip`""
    Add-Line "						`"cf: reserve`" >= $($Route.VipCost)"
    Add-Line "					goto `"confirm open $($Route.Prefix) vip`""
}

function Add-ShuttleShipLabel {
    param(
        [object]$Route,
        [object]$Ship
    )

    Add-ConfirmationLabel "confirm buy $($Route.Prefix) $($Ship.Key)" "buy $($Route.Prefix) $($Ship.Key)" "Buy this $($Ship.Name) for the $($Route.Name) shuttle route for $($Ship.Cost.ToString('N0')) company credits?" "Buy ship."
    Add-Line "			label `"buy $($Route.Prefix) $($Ship.Key)`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= $($Ship.Cost)"
    Add-Line "				`"cf: shuttle $($Route.Prefix) pax`" += $($Ship.Bunks)"
    Add-Line "				`"cf: shuttle $($Route.Prefix) ships`" ++"
    Add-Line "				`"cf: shuttle $($Route.Prefix) daily crew`" += $($Ship.Crew * 100)"
    Add-Line "				`"cf: shuttle $($Route.Prefix) trip payout`" = `"cf: shuttle $($Route.Prefix) pax`" * $($Route.Fare) / `"cf: shuttle $($Route.Prefix) ships`""
    Add-Line "				`"cf: shuttle $($Route.Prefix) trip expenses`" = `"cf: shuttle $($Route.Prefix) daily crew`" * $($Route.Threshold) / `"cf: shuttle $($Route.Prefix) ships`""
    Add-Line "				`"cf: shuttle fleet`" ++"
    Add-Line "				`"cf: fleet value`" += $($Ship.Cost)"
    if($Ship.Luxury) {
        Add-Line "				set `"cf: shuttle $($Route.Prefix) luxury`""
    }
    Add-Line "			``The company buys a $($Ship.Name) and assigns it to the $($Route.Name) route. The ship counts as one route slot and adds $($Ship.Bunks) passenger berths.``"
    Add-CompanyOutlookReturn
}

function Add-ShuttleVipLabel {
    param([object]$Route)

    Add-ConfirmationLabel "confirm open $($Route.Prefix) vip" "open $($Route.Prefix) vip" "Open VIP service on the $($Route.Name) shuttle route for $($Route.VipCost.ToString('N0')) company credits?" "Open VIP service."
    Add-Line "			label `"open $($Route.Prefix) vip`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= $($Route.VipCost)"
    Add-Line "				set `"cf: shuttle $($Route.Prefix) vip`""
    Add-Line "			``Your staff opens a VIP desk for the $($Route.Name) route. Only one VIP contract can run on a route, adding a premium bonus to each completed passenger cycle.``"
    Add-CompanyOutlookReturn
}

function Add-OwnerPayoutChoice {
    param([int]$Amount)

    Add-Line "				``	Collect $($Amount.ToString('N0')) credits from owner payable.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						has `"cf: manual owner payout controls enabled`""
    Add-Line "						`"cf: owner payable`" >= $Amount"
    Add-Line "					goto `"confirm collect owner $Amount`""
}

function Add-InvestChoice {
    param([int]$Amount)

    $displayAmount = Format-CreditAmount $Amount
    Add-Line "				``	Invest $displayAmount personal credits into the company reserve.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						`"credits`" >= $Amount"
    Add-Line "					goto `"confirm invest $Amount`""
}

function Add-QuickInvestChoice {
    param([int]$Amount)

    $displayAmount = Format-CreditAmount $Amount
    Add-Line "				``	Invest $displayAmount personal credits into the company reserve.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						`"credits`" >= $Amount"
    Add-Line "					goto `"invest $Amount`""
}

function Add-CompanyProjectionActionLines {
    param([string]$Indent = "				")

    Add-Line "$Indent`"cf: worker staff`" = 0"
    foreach($route in $shuttleRouteTypes) {
        Add-Line "$Indent`"cf: worker staff`" += `"cf: shuttle $($route.Prefix) daily crew`" / 100"
    }
    foreach($claim in $miningClaimTypes) {
        Add-Line "$Indent`"cf: worker staff`" += `"cf: mining $($claim.Prefix) daily crew`" / 100"
    }
    foreach($route in $tradingRouteTypes) {
        Add-Line "$Indent`"cf: worker staff`" += `"cf: trading $($route.Prefix) daily crew`" / 100"
    }
    foreach($contract in $securityContractTypes) {
        Add-Line "$Indent`"cf: worker staff`" += `"cf: security $($contract.Prefix) daily crew`" / 100"
    }
    Add-Line "$Indent`"cf: worker staff`" += `"cf: admiral daily crew`" / 100"

    Add-Line "$Indent`"cf: office staff`" = `"cf: worker staff`""
    Add-Line "$Indent`"cf: office staff`" -= 1"
    Add-Line "$Indent`"cf: office staff`" >?= 0"
    Add-Line "$Indent`"cf: office staff`" /= 2"

    Add-Line "$Indent`"cf: specialist staff`" = 0"
    foreach($route in $tradingRouteTypes) {
        Add-Line "$Indent`"cf: specialist staff`" += `"cf: trading $($route.Prefix) trader`""
    }
    Add-Line "$Indent`"cf: specialist staff`" += `"cf: managed`""
    Add-Line "$Indent`"cf: specialist staff`" += `"cf: security admiral`""

    Add-Line "$Indent`"cf: total staff`" = `"cf: worker staff`""
    Add-Line "$Indent`"cf: total staff`" += `"cf: office staff`""
    Add-Line "$Indent`"cf: total staff`" += `"cf: specialist staff`""

    Add-Line "$Indent`"cf: office daily cost`" = `"cf: office staff`" * 100"
    Add-Line "$Indent`"cf: employee tax`" = `"cf: total staff`" * 5"
    Add-Line "$Indent`"cf: employee tax`" += `"cf: total staff`" / 5 * 20"
    Add-Line "$Indent`"cf: employee tax`" += `"cf: total staff`" / 10 * 40"
    Add-Line "$Indent`"cf: employee tax`" += `"cf: total staff`" / 20 * 100"
    Add-Line "$Indent`"cf: employee tax`" += `"cf: total staff`" / 50 * 250"
    Add-Line "$Indent`"cf: employee tax`" += `"cf: total staff`" / 100 * 600"
    Add-Line "$Indent`"cf: employee tax`" += `"cf: total staff`" / 500 * 4000"
    Add-Line "$Indent`"cf: employee tax`" += `"cf: total staff`" / 1000 * 10000"

    Add-Line "$Indent`"cf: hq daily tax`" = `"cf: hq base tax`""
    Add-Line "$Indent`"cf: hq daily tax`" += `"cf: employee tax`""
    Add-Line "$Indent`"cf: hq daily tax`" -= `"cf: hq tax relief`""
    Add-Line "$Indent`"cf: hq daily tax`" >?= 0"

    Add-Line "$Indent`"cf: projected gross`" = 0"
    Add-Line "$Indent`"cf: projected expenses`" = 0"

    foreach($route in $shuttleRouteTypes) {
        Add-Line "$Indent`"cf: projected route income`" = `"cf: shuttle $($route.Prefix) trip payout`""
        Add-Line "$Indent`"cf: projected route income`" += `"cf: shuttle $($route.Prefix) trip payout`" * `"cf: shuttle $($route.Prefix) vip`" * 2"
        Add-Line "$Indent`"cf: projected gross`" += `"cf: projected route income`" * `"cf: shuttle $($route.Prefix) ships`" / $($route.Threshold)"
        Add-Line "$Indent`"cf: projected expenses`" += `"cf: shuttle $($route.Prefix) daily crew`""
    }
    foreach($claim in $miningClaimTypes) {
        Add-Line "$Indent`"cf: projected route income`" = `"cf: mining $($claim.Prefix) trip payout`""
        Add-Line "$Indent`"cf: projected route income`" += `"cf: mining $($claim.Prefix) trip payout`" * `"cf: mining efficiency bonus`" / 100"
        Add-Line "$Indent`"cf: projected gross`" += `"cf: projected route income`" * `"cf: mining $($claim.Prefix) ships`" / $($claim.Threshold)"
        Add-Line "$Indent`"cf: projected expenses`" += `"cf: mining $($claim.Prefix) daily crew`""
    }
    foreach($route in $tradingRouteTypes) {
        Add-Line "$Indent`"cf: projected gross`" += `"cf: trading $($route.Prefix) trip payout`" * `"cf: trading $($route.Prefix) ships`" / $($route.Threshold)"
        Add-Line "$Indent`"cf: projected expenses`" += `"cf: trading $($route.Prefix) daily expenses`""
    }
    foreach($contract in $securityContractTypes) {
        Add-Line "$Indent`"cf: projected gross`" += `"cf: security $($contract.Prefix) trip payout`" * `"cf: security $($contract.Prefix) ships`" / $($contract.Threshold)"
        Add-Line "$Indent`"cf: projected expenses`" += `"cf: security $($contract.Prefix) daily crew`""
    }

    Add-Line "$Indent`"cf: projected gross`" += `"cf: admiral tribute income`""
    Add-Line "$Indent`"cf: projected gross`" += `"cf: station daily income`""
    Add-Line "$Indent`"cf: projected expenses`" += `"cf: admiral daily crew`""
    Add-Line "$Indent`"cf: projected expenses`" += `"cf: security admiral`" * 20000"
    Add-Line "$Indent`"cf: projected expenses`" += `"cf: managed`" * 10000"
    Add-Line "$Indent`"cf: projected expenses`" += `"cf: station daily upkeep`""
    Add-Line "$Indent`"cf: projected expenses`" += `"cf: office daily cost`""
    Add-Line "$Indent`"cf: projected expenses`" += `"cf: hq daily tax`""
    Add-Line "$Indent`"cf: projected net`" = `"cf: projected gross`" - `"cf: projected expenses`""
    Add-Line "$Indent`"cf: projected owner payout`" = `"cf: projected net`" * `"cf: payout share`" / 100"
    Add-Line "$Indent`"cf: projected owner payout`" >?= 0"
    Add-Line "$Indent`"cf: projected retained`" = `"cf: projected net`" - `"cf: projected owner payout`""
    Add-Line "$Indent`"cf: projected autopay net`" = `"cf: projected owner payout`""
}

function Add-DivisionProjectionActionLines {
    param([string]$Indent = "				")

    Add-Line "$Indent`"cf: shuttle projected gross`" = 0"
    Add-Line "$Indent`"cf: shuttle projected expenses`" = 0"
    foreach($route in $shuttleRouteTypes) {
        Add-Line "$Indent`"cf: projected route income`" = `"cf: shuttle $($route.Prefix) trip payout`""
        Add-Line "$Indent`"cf: projected route income`" += `"cf: shuttle $($route.Prefix) trip payout`" * `"cf: shuttle $($route.Prefix) vip`" * 2"
        Add-Line "$Indent`"cf: shuttle projected gross`" += `"cf: projected route income`" * `"cf: shuttle $($route.Prefix) ships`" / $($route.Threshold)"
        Add-Line "$Indent`"cf: shuttle projected expenses`" += `"cf: shuttle $($route.Prefix) daily crew`""
    }
    Add-Line "$Indent`"cf: shuttle projected expenses`" += `"cf: managed`" * 10000"
    Add-Line "$Indent`"cf: shuttle projected net`" = `"cf: shuttle projected gross`" - `"cf: shuttle projected expenses`""

    Add-Line "$Indent`"cf: mining projected gross`" = 0"
    Add-Line "$Indent`"cf: mining projected expenses`" = 0"
    foreach($claim in $miningClaimTypes) {
        Add-Line "$Indent`"cf: projected route income`" = `"cf: mining $($claim.Prefix) trip payout`""
        Add-Line "$Indent`"cf: projected route income`" += `"cf: mining $($claim.Prefix) trip payout`" * `"cf: mining efficiency bonus`" / 100"
        Add-Line "$Indent`"cf: mining projected gross`" += `"cf: projected route income`" * `"cf: mining $($claim.Prefix) ships`" / $($claim.Threshold)"
        Add-Line "$Indent`"cf: mining projected expenses`" += `"cf: mining $($claim.Prefix) daily crew`""
    }
    Add-Line "$Indent`"cf: mining projected expenses`" += `"cf: managed`" * 10000"
    Add-Line "$Indent`"cf: mining projected net`" = `"cf: mining projected gross`" - `"cf: mining projected expenses`""

    Add-Line "$Indent`"cf: trading projected gross`" = 0"
    Add-Line "$Indent`"cf: trading projected expenses`" = 0"
    foreach($route in $tradingRouteTypes) {
        Add-Line "$Indent`"cf: trading projected gross`" += `"cf: trading $($route.Prefix) trip payout`" * `"cf: trading $($route.Prefix) ships`" / $($route.Threshold)"
        Add-Line "$Indent`"cf: trading projected expenses`" += `"cf: trading $($route.Prefix) daily expenses`""
    }
    Add-Line "$Indent`"cf: trading projected expenses`" += `"cf: managed`" * 10000"
    Add-Line "$Indent`"cf: trading projected net`" = `"cf: trading projected gross`" - `"cf: trading projected expenses`""

    Add-Line "$Indent`"cf: security projected gross`" = 0"
    Add-Line "$Indent`"cf: security projected expenses`" = 0"
    foreach($contract in $securityContractTypes) {
        Add-Line "$Indent`"cf: security projected gross`" += `"cf: security $($contract.Prefix) trip payout`" * `"cf: security $($contract.Prefix) ships`" / $($contract.Threshold)"
        Add-Line "$Indent`"cf: security projected expenses`" += `"cf: security $($contract.Prefix) daily crew`""
    }
    Add-Line "$Indent`"cf: security projected gross`" += `"cf: admiral tribute income`""
    Add-Line "$Indent`"cf: security projected expenses`" += `"cf: admiral daily crew`""
    Add-Line "$Indent`"cf: security projected expenses`" += `"cf: security admiral`" * 20000"
    Add-Line "$Indent`"cf: security projected expenses`" += `"cf: managed`" * 10000"
    Add-Line "$Indent`"cf: security projected net`" = `"cf: security projected gross`" - `"cf: security projected expenses`""
}

function Add-CompanyValuationActionLines {
    param([string]$Indent = "				")

    Add-Line "$Indent`"cf: company value`" = `"cf: reserve`""
    Add-Line "$Indent`"cf: company value`" >?= 0"
    Add-Line "$Indent`"cf: company value`" += `"cf: owner payable`""
    Add-Line "$Indent`"cf: company value`" += `"cf: fleet value`""
    Add-Line "$Indent`"cf: company value`" += `"cf: station value`""
    Add-Line "$Indent`"cf: company value`" += `"cf: shuttle route count`" * 120000"
    Add-Line "$Indent`"cf: company value`" += `"cf: mining claim count`" * 220000"
    Add-Line "$Indent`"cf: company value`" += `"cf: trading route count`" * 180000"
    Add-Line "$Indent`"cf: company value`" += `"cf: security contract count`" * 250000"
    Add-Line "$Indent`"cf: company value`" += `"cf: admiral tribute income`" * 180"
    Add-Line "$Indent`"cf: company value`" += `"cf: station daily income`" * 365"
    Add-Line "$Indent`"cf: company value`" >?= 0"
}

function Add-ConfirmationLabel {
    param(
        [string]$ConfirmLabel,
        [string]$TargetLabel,
        [string]$Prompt,
        [string]$ProceedText = "Confirm.",
        [string]$CancelTarget = "company main menu"
    )

    Add-Line "			label `"$ConfirmLabel`""
    Add-Line "			``$Prompt``"
    Add-Line "			choice"
    Add-Line "				``	$ProceedText``"
    Add-Line "					goto `"$TargetLabel`""
    Add-Line "				``	Cancel.``"
    Add-Line "					goto `"$CancelTarget`""
}

function Add-CompanyOutlookReturn {
    Add-Line "				goto `"company transaction summary`""
}

function Add-CompanyTransactionSummaryLabel {
    param([switch]$DetailedReturns)

    Add-Line "			label `"company transaction summary`""
    Add-Line "			action"
    Add-CompanyProjectionActionLines "				"
    Add-Line "			``Transaction confirmed. Your clerks update the company board before you sign the receipt.``"
    Add-Line "			``	Updated outlook: reserve &[credits@cf: reserve], daily taxes &[credits@cf: hq daily tax], expected daily gross &[credits@cf: projected gross], expected daily expenses &[credits@cf: projected expenses], expected daily net &[credits@cf: projected net].``"
    Add-Line "			``	At the current payout share, a positive operating day would queue about &[credits@cf: projected owner payout] for direct AutoPay and leave about &[credits@cf: projected retained] in company reserve.``"
    Add-Line "			``	AutoPay estimate: about &[credits@cf: projected autopay net] would reach your account with no transfer fee or tax deduction.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: autopay`""
    Add-Line "			choice"
    Add-Line "				``	Return to the company board.``"
    Add-Line "					goto `"company main menu`""
    if($DetailedReturns) {
        Add-Line "				``	Return to payout policy.``"
        Add-Line "					goto `"menu payout`""
        Add-Line "				``	Return to licenses.``"
        Add-Line "					goto `"menu licenses`""
        Add-Line "				``	Return to ships.``"
        Add-Line "					goto `"menu ships`""
        Add-Line "				``	Return to manager.``"
        Add-Line "					goto `"menu manager`""
        Add-Line "				``	Return to station construction.``"
        Add-Line "					goto `"menu stations`""
        Add-Line "				``	Return to investment.``"
        Add-Line "					goto `"menu invest`""
    }
}

function Add-OwnerPayoutLabel {
    param([int]$Amount)

    Add-ConfirmationLabel "confirm collect owner $Amount" "collect owner $Amount" "Collect $($Amount.ToString('N0')) credits from owner payable into your personal account?" "Collect payout."
    Add-Line "			label `"collect owner $Amount`""
    Add-Line "			action"
    Add-Line "				payment $Amount"
    Add-Line "				`"cf: owner payable`" -= $Amount"
    Add-Line "				`"cf: total owner payouts`" += $Amount"
    Add-Line "			``You collect $($Amount.ToString('N0')) credits from the company's payable owner balance.``"
    Add-CompanyOutlookReturn
}

function Add-InvestLabel {
    param(
        [int]$Amount,
        [switch]$WithConfirmation
    )

    $displayAmount = Format-CreditAmount $Amount
    if($WithConfirmation) {
        Add-ConfirmationLabel "confirm invest $Amount" "invest $Amount" "Invest $displayAmount personal credits into the company reserve?" "Invest." "menu invest"
    }
    Add-Line "			label `"invest $Amount`""
    Add-Line "			action"
    Add-Line "				payment -$Amount"
    Add-Line "				`"cf: reserve`" += $Amount"
    Add-Line "			``You transfer $displayAmount credits into the company reserve.``"
    Add-CompanyOutlookReturn
}

function Add-AutoPayTransferMission {
    param([int]$Amount)

    $net = $Amount
    $fee = 0
    Add-Line "mission `"Company Foundations: AutoPay Transfer $Amount`""
    Add-Line "	name `"Company AutoPay Transfer`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		has `"cf: autopay`""
    Add-Line "		`"cf: owner payable`" >= $Amount"
    Add-Line "	on offer"
    Add-Line "		payment $net"
    Add-Line "		`"cf: owner payable`" -= $Amount"
    Add-Line "		`"cf: total owner payouts`" += $net"
    Add-Line "		`"cf: autopay gross transfers`" += $Amount"
    Add-Line "		`"cf: autopay net transfers`" += $net"
    Add-Line "		`"cf: autopay fees`" += $fee"
    Add-Line "		`"cf: autopay transfers`" ++"
    Add-Line ""
}

function Add-StationBuildChoices {
    Add-Line "				``	Build a corporate station core for 5M company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						not `"cf: hq suspended`""
    Add-Line "						not `"cf: station orbital office`""
    Add-Line "						`"cf: reserve`" >= 5000000"
    Add-Line "					goto `"menu station sites`""
    Add-Line "				``	Install a station outfitter deck for 15M company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: station orbital office`""
    Add-Line "						not `"cf: hq suspended`""
    Add-Line "						not `"cf: station logistics hub`""
    Add-Line "						`"cf: reserve`" >= 15000000"
    Add-Line "					goto `"confirm build logistics station`""
    Add-Line "				``	Install an industrial shipyard dock for 45M company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: station logistics hub`""
    Add-Line "						not `"cf: hq suspended`""
    Add-Line "						not `"cf: station industrial dock`""
    Add-Line "						`"cf: reserve`" >= 45000000"
    Add-Line "					goto `"confirm build industrial station`""
}

function Add-StationSiteChoices {
    foreach($system in $companyStationSystems) {
        $systemName = $system.Name
        Add-Line "				``	Build in $systemName.``"
        Add-Line "					to display"
        Add-Line "						has `"cf: active`""
        Add-Line "						not `"cf: hq suspended`""
        Add-Line "						not `"cf: station orbital office`""
        Add-Line "						`"cf: reserve`" >= 5000000"
        Add-Line "					goto `"confirm build station in $systemName`""
    }
}

function Add-StationBuildLabels {
    foreach($system in $companyStationSystems) {
        $systemName = $system.Name
        Add-ConfirmationLabel "confirm build station in $systemName" "build station in $systemName" "Build the company headquarters station in the $systemName system for 5,000,000 company credits?" "Build station." "menu station sites"
        Add-Line "			label `"build station in $systemName`""
        Add-Line "			action"
        Add-Line "				`"cf: reserve`" -= 5000000"
        Add-Line "				set `"cf: station orbital office`""
        Add-Line "				set `"cf: hq station built`""
        Add-ConditionLine "set" "cf: hq: $companyStationPlanetName" "				"
        Add-ConditionLine "set" "cf: hq station system: $systemName" "				"
        Add-Line "				set `"cf: at hq`""
        Add-Line "				`"reputation: $companyGovernmentName`" >?= 1000"
        Add-Line "				`"cf: station count`" ++"
        Add-Line "				`"cf: station value`" += 5000000"
        Add-Line "				`"cf: station daily income`" += 1500"
        Add-Line "				`"cf: station daily upkeep`" += 800"
        Add-Line "				`"cf: hq tax relief`" += 500"
        Add-Line "				`"cf: hq daily tax`" -= 500"
        Add-Line "				event `"Company Foundations: Station Site: $systemName`""
        Add-Line "				log `"Company Foundations`" `"Headquarters Station`" ``Built the company headquarters station in the $systemName system.``"
        Add-Line "			``Your company charters a compact headquarters station in the $systemName system. The new station handles customs, berthing contracts, and dispatch traffic, adding 1,500 credits per day in service income, 800 credits per day in upkeep, and reducing local HQ taxes by 500 credits per day.``"
        Add-CompanyOutlookReturn
    }

    Add-ConfirmationLabel "confirm build logistics station" "build logistics station" "Install a station outfitter deck for 15,000,000 company credits?" "Build station."
    Add-Line "			label `"build logistics station`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 15000000"
    Add-Line "				set `"cf: station logistics hub`""
    Add-Line "				`"cf: station count`" ++"
    Add-Line "				`"cf: station value`" += 15000000"
    Add-Line "				`"cf: station daily income`" += 5000"
    Add-Line "				`"cf: station daily upkeep`" += 2000"
    Add-Line "				event `"Company Foundations: Station Stage 2 Outfitter`""
    Add-Line "			``The company expands the headquarters station with an outfitter deck. Cargo handling, shuttle transfers, and crew services add 5,000 credits per day in station income, with 2,000 credits per day in upkeep.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm build industrial station" "build industrial station" "Install an industrial shipyard dock for 45,000,000 company credits?" "Build station."
    Add-Line "			label `"build industrial station`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 45000000"
    Add-Line "				set `"cf: station industrial dock`""
    Add-Line "				`"cf: station count`" ++"
    Add-Line "				`"cf: station value`" += 45000000"
    Add-Line "				`"cf: station daily income`" += 14000"
    Add-Line "				`"cf: station daily upkeep`" += 6500"
    Add-Line "				event `"Company Foundations: Station Stage 3 Shipyard`""
    Add-Line "			``The company builds an industrial shipyard dock with repair berths, warehousing, and contractor shops. It adds 14,000 credits per day in station income, with 6,500 credits per day in upkeep.``"
    Add-CompanyOutlookReturn
}

function Add-CompanySellActions {
    param([string]$Indent = "				")

    Add-Line "$Indent`"cf: last sale proceeds`" = `"cf: sale proceeds`""
    Add-Line "$Indent`"cf: company value`" = 0"
    Add-Line "$Indent`"cf: reserve`" = 0"
    Add-Line "$Indent`"cf: owner payable`" = 0"
    Add-Line "$Indent`"cf: fleet value`" = 0"
    Add-Line "$Indent`"cf: station value`" = 0"
    Add-Line "$Indent`"cf: station count`" = 0"
    Add-Line "$Indent`"cf: station daily income`" = 0"
    Add-Line "$Indent`"cf: station daily upkeep`" = 0"
    Add-Line "$Indent`"cf: payout share`" = 0"
    Add-Line "$Indent`"cf: unallocated net`" = 0"
    Add-Line "$Indent`"cf: last gross`" = 0"
    Add-Line "$Indent`"cf: last expenses`" = 0"
    Add-Line "$Indent`"cf: last net profit`" = 0"
    Add-Line "$Indent`"cf: last owner payout`" = 0"
    Add-Line "$Indent`"cf: last retained earnings`" = 0"
    Add-Line "$Indent`"cf: worker staff`" = 0"
    Add-Line "$Indent`"cf: office staff`" = 0"
    Add-Line "$Indent`"cf: specialist staff`" = 0"
    Add-Line "$Indent`"cf: total staff`" = 0"
    foreach($division in @("shuttle", "mining", "trading", "security")) {
        Add-Line "$Indent`"cf: $division last gross`" = 0"
        Add-Line "$Indent`"cf: $division last expenses`" = 0"
        Add-Line "$Indent`"cf: $division last net`" = 0"
        Add-Line "$Indent`"cf: $division total gross`" = 0"
        Add-Line "$Indent`"cf: $division total expenses`" = 0"
        Add-Line "$Indent`"cf: $division total net`" = 0"
        Add-Line "$Indent`"cf: $division month gross`" = 0"
        Add-Line "$Indent`"cf: $division month expenses`" = 0"
        Add-Line "$Indent`"cf: $division month net`" = 0"
        Add-Line "$Indent`"cf: $division projected gross`" = 0"
        Add-Line "$Indent`"cf: $division projected expenses`" = 0"
        Add-Line "$Indent`"cf: $division projected net`" = 0"
    }
    Add-Line "$Indent`"cf: hq base tax`" = 0"
    Add-Line "$Indent`"cf: hq daily tax`" = 0"
    Add-Line "$Indent`"cf: hq tax relief`" = 0"
    Add-Line "$Indent`"cf: hq required reputation`" = 0"
    Add-Line "$Indent`"cf: shuttle fleet`" = 0"
    Add-Line "$Indent`"cf: shuttle route count`" = 0"
    foreach($route in $shuttleRouteTypes) {
        Add-Line "$Indent`"cf: shuttle $($route.Prefix) ships`" = 0"
        Add-Line "$Indent`"cf: shuttle $($route.Prefix) pax`" = 0"
        Add-Line "$Indent`"cf: shuttle $($route.Prefix) daily crew`" = 0"
        Add-Line "$Indent`"cf: shuttle $($route.Prefix) trip payout`" = 0"
        Add-Line "$Indent`"cf: shuttle $($route.Prefix) trip expenses`" = 0"
        Add-Line "${Indent}clear `"cf: shuttle route $($route.Prefix)`""
        Add-Line "${Indent}clear `"cf: shuttle $($route.Prefix) vip`""
        Add-Line "${Indent}clear `"cf: shuttle $($route.Prefix) luxury`""
    }
    Add-Line "$Indent`"cf: mining fleet`" = 0"
    Add-Line "$Indent`"cf: mining claim count`" = 0"
    Add-Line "$Indent`"cf: mining drones`" = 0"
    Add-Line "$Indent`"cf: mining drone capacity`" = 0"
    Add-Line "$Indent`"cf: mining efficiency bonus`" = 0"
    foreach($claim in $miningClaimTypes) {
        Add-Line "$Indent`"cf: mining $($claim.Prefix) ships`" = 0"
        Add-Line "$Indent`"cf: mining $($claim.Prefix) cargo`" = 0"
        Add-Line "$Indent`"cf: mining $($claim.Prefix) daily crew`" = 0"
        Add-Line "$Indent`"cf: mining $($claim.Prefix) trip payout`" = 0"
        Add-Line "$Indent`"cf: mining $($claim.Prefix) trip expenses`" = 0"
        Add-Line "$Indent`"cf: mining $($claim.Prefix) value`" = 0"
        Add-Line "${Indent}clear `"cf: mining claim $($claim.Prefix)`""
    }
    Add-Line "$Indent`"cf: trading fleet`" = 0"
    Add-Line "$Indent`"cf: trading route count`" = 0"
    foreach($route in $tradingRouteTypes) {
        Add-Line "$Indent`"cf: trading $($route.Prefix) ships`" = 0"
        Add-Line "$Indent`"cf: trading $($route.Prefix) cargo`" = 0"
        Add-Line "$Indent`"cf: trading $($route.Prefix) daily crew`" = 0"
        Add-Line "$Indent`"cf: trading $($route.Prefix) trip payout`" = 0"
        Add-Line "$Indent`"cf: trading $($route.Prefix) trip expenses`" = 0"
        Add-Line "$Indent`"cf: trading $($route.Prefix) value`" = 0"
        Add-Line "$Indent`"cf: trading $($route.Prefix) optimized value`" = 0"
        Add-Line "$Indent`"cf: trading $($route.Prefix) current value`" = 0"
        Add-Line "${Indent}clear `"cf: trading license $($route.Prefix)`""
        Add-Line "${Indent}clear `"cf: trading $($route.Prefix) trader`""
    }
    Add-Line "$Indent`"cf: security fleet`" = 0"
    Add-Line "$Indent`"cf: security contract count`" = 0"
    Add-Line "$Indent`"cf: security combat rating`" = 0"
    foreach($contract in $securityContractTypes) {
        Add-Line "$Indent`"cf: security $($contract.Prefix) ships`" = 0"
        Add-Line "$Indent`"cf: security $($contract.Prefix) rating`" = 0"
        Add-Line "$Indent`"cf: security $($contract.Prefix) daily crew`" = 0"
        Add-Line "$Indent`"cf: security $($contract.Prefix) trip payout`" = 0"
        Add-Line "$Indent`"cf: security $($contract.Prefix) trip expenses`" = 0"
        Add-Line "$Indent`"cf: security $($contract.Prefix) rate`" = 0"
        Add-Line "${Indent}clear `"cf: security license $($contract.Prefix)`""
    }
    Add-Line "$Indent`"cf: admiral fleet`" = 0"
    Add-Line "$Indent`"cf: admiral rating`" = 0"
    Add-Line "$Indent`"cf: admiral daily crew`" = 0"
    Add-Line "$Indent`"cf: admiral tribute income`" = 0"
    Add-Line "$Indent`"cf: admiral tribute count`" = 0"
    foreach($campaign in $admiralCampaignTypes) {
        Add-Line "${Indent}clear `"cf: admiral tribute $($campaign.Prefix)`""
    }
    Add-Line "${Indent}clear `"cf: active`""
    Add-Line "${Indent}clear `"cf: shuttle`""
    Add-Line "${Indent}clear `"cf: mining`""
    Add-Line "${Indent}clear `"cf: trading`""
    Add-Line "${Indent}clear `"cf: security`""
    Add-Line "${Indent}clear `"cf: manual`""
    Add-Line "${Indent}clear `"cf: managed`""
    Add-Line "${Indent}clear `"cf: manual pending`""
    Add-Line "${Indent}clear `"cf: manager pending`""
    Add-Line "${Indent}clear `"cf: manual active`""
    Add-Line "${Indent}clear `"cf: manager active`""
    Add-Line "${Indent}clear `"cf: manager salary checked`""
    Add-Line "${Indent}clear `"cf: autopay`""
    Add-Line "${Indent}clear `"cf: hq suspended`""
    Add-Line "${Indent}clear `"cf: at hq`""
    Add-Line "${Indent}clear `"cf: station orbital office`""
    Add-Line "${Indent}clear `"cf: station logistics hub`""
    Add-Line "${Indent}clear `"cf: station industrial dock`""
    Add-Line "${Indent}clear `"cf: security admiral`""
    Add-Line "${Indent}clear `"cf: admiral in transit`""
    Add-ClearAllHQConditions $Indent
    Add-ClearAllAdmiralLocationConditions $Indent
    Add-ClearAllAdmiralDestinationConditions $Indent
    Add-ClearOperationsMissionStateActions $Indent
}

function Add-CompanySaleLabels {
    Add-ConfirmationLabel "confirm sell company" "start company sale" "Sell the entire company for the currently calculated firm value of &[credits@cf: company value]? This closes every active company division." "Sell company."
    Add-Line "			label `"start company sale`""
    Add-Line "			action"
    Add-CompanyValuationActionLines "				"
    Add-Line "				`"cf: sale proceeds`" = `"cf: company value`""
    Add-Line "				`"cf: sale remaining`" = `"cf: company value`""
    Add-Line "			``The sale contract is signed for &[credits@cf: sale proceeds]. Collect the transfer in fixed batches, then finalize the company closure.``"
    Add-Line "				goto `"company sale payout`""
    Add-Line "			label `"company sale payout`""
    Add-Line "			``Remaining company sale payout: &[credits@cf: sale remaining].``"
    Add-Line "			choice"
    foreach($amount in @(1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1)) {
        Add-Line "				``	Collect $($amount.ToString('N0')) credits.``"
        Add-Line "					to display"
        Add-Line "						`"cf: sale remaining`" >= $amount"
        Add-Line "					goto `"collect sale $amount`""
    }
    Add-Line "				``	Finalize sale and close the company.``"
    Add-Line "					to display"
    Add-Line "						`"cf: sale remaining`" == 0"
    Add-Line "					goto `"finalize company sale`""
    Add-Line "				``	Return to the company board.``"
    Add-Line "					goto `"company main menu`""
    foreach($amount in @(1000000000, 100000000, 10000000, 1000000, 100000, 10000, 1000, 100, 10, 1)) {
        Add-Line "			label `"collect sale $amount`""
        Add-Line "			action"
        Add-Line "				payment $amount"
        Add-Line "				`"cf: sale remaining`" -= $amount"
        Add-Line "			``Transfer received.``"
        Add-Line "				goto `"company sale payout`""
    }
    Add-Line "			label `"finalize company sale`""
    Add-Line "			action"
    Add-CompanySellActions "				"
    Add-Line "			``The sale is complete. The company charter, operating licenses, stations, management contracts, and headquarters record are closed.``"
    Add-Line "				decline"
}

$miningShipTypes = @(
    [pscustomobject]@{ Key = "sunder"; Name = "Sunder"; Cost = 1000000; Cargo = 80; Crew = 3; DroneCapacity = 2 },
    [pscustomobject]@{ Key = "mule"; Name = "Mule mining conversion"; Procurement = "Mule"; Cost = 4080000; Cargo = 170; Crew = 14; DroneCapacity = 0 }
)

$miningClaimTypes = @(
    [pscustomobject]@{ Prefix = "local"; Name = "local"; Required = "cf: mining"; CargoCap = 160; Threshold = 3; Cost = 0 },
    [pscustomobject]@{ Prefix = "regional"; Name = "regional"; Required = "cf: mining claim regional"; CargoCap = 300; Threshold = 5; Cost = 220000 },
    [pscustomobject]@{ Prefix = "deep"; Name = "deep"; Required = "cf: mining claim deep"; CargoCap = 480; Threshold = 7; Cost = 420000 },
    [pscustomobject]@{ Prefix = "frontier"; Name = "frontier"; Required = "cf: mining claim frontier"; CargoCap = 700; Threshold = 9; Cost = 700000 }
)

$tradingShipTypes = @(
    [pscustomobject]@{ Key = "star barge"; Name = "Star Barge"; Cost = 190000; Cargo = 50; Crew = 1 },
    [pscustomobject]@{ Key = "freighter"; Name = "Freighter"; Cost = 730000; Cargo = 150; Crew = 2 },
    [pscustomobject]@{ Key = "clipper"; Name = "Clipper"; Cost = 900000; Cargo = 70; Crew = 3 },
    [pscustomobject]@{ Key = "hauler"; Name = "Hauler"; Cost = 1430000; Cargo = 130; Crew = 3 },
    [pscustomobject]@{ Key = "argosy"; Name = "Argosy"; Cost = 1960000; Cargo = 120; Crew = 4 },
    [pscustomobject]@{ Key = "mule"; Name = "Mule"; Cost = 4080000; Cargo = 170; Crew = 14 },
    [pscustomobject]@{ Key = "behemoth"; Name = "Behemoth"; Cost = 10800000; Cargo = 490; Crew = 12 },
    [pscustomobject]@{ Key = "bulk freighter"; Name = "Bulk Freighter"; Cost = 11100000; Cargo = 640; Crew = 12 }
)

$tradingRouteTypes = @(
    [pscustomobject]@{ Prefix = "local"; Name = "local"; Required = "cf: trading"; CargoCap = 250; Threshold = 4; Cost = 0 },
    [pscustomobject]@{ Prefix = "regional"; Name = "regional"; Required = "cf: trading license regional"; CargoCap = 500; Threshold = 6; Cost = 180000 },
    [pscustomobject]@{ Prefix = "long"; Name = "long"; Required = "cf: trading license long"; CargoCap = 900; Threshold = 8; Cost = 400000 },
    [pscustomobject]@{ Prefix = "frontier"; Name = "frontier"; Required = "cf: trading license frontier"; CargoCap = 1300; Threshold = 10; Cost = 750000 }
)

$securityShipTypes = @(
    [pscustomobject]@{ Key = "hawk"; Name = "Hawk"; Class = "Interceptor"; Cost = 670000; Rating = 1; Crew = 1 },
    [pscustomobject]@{ Key = "splinter"; Name = "Splinter"; Class = "Medium Warship"; Cost = 3100000; Rating = 3; Crew = 7 },
    [pscustomobject]@{ Key = "manta"; Name = "Manta"; Class = "Medium Warship"; Cost = 3400000; Rating = 3; Crew = 6 },
    [pscustomobject]@{ Key = "aerie"; Name = "Aerie"; Class = "Medium Warship"; Cost = 3500000; Rating = 3; Crew = 10 },
    [pscustomobject]@{ Key = "firebird"; Name = "Firebird"; Class = "Medium Warship"; Cost = 3700000; Rating = 3; Crew = 7 },
    [pscustomobject]@{ Key = "bastion"; Name = "Bastion"; Class = "Medium Warship"; Cost = 3860000; Rating = 4; Crew = 17 },
    [pscustomobject]@{ Key = "protector"; Name = "Protector"; Class = "Heavy Warship"; Cost = 5500000; Rating = 5; Crew = 30 },
    [pscustomobject]@{ Key = "vanguard"; Name = "Vanguard"; Class = "Heavy Warship"; Cost = 7200000; Rating = 6; Crew = 23 },
    [pscustomobject]@{ Key = "leviathan"; Name = "Leviathan"; Class = "Heavy Warship"; Cost = 9800000; Rating = 7; Crew = 43 },
    [pscustomobject]@{ Key = "falcon"; Name = "Falcon"; Class = "Heavy Warship"; Cost = 10900000; Rating = 7; Crew = 52 }
)

$securityContractTypes = @(
    [pscustomobject]@{ Prefix = "local"; Name = "local"; Required = "cf: security"; RatingCap = 8; Threshold = 4; Rate = 1000; Cost = 0 },
    [pscustomobject]@{ Prefix = "regional"; Name = "regional"; Required = "cf: security license regional"; RatingCap = 14; Threshold = 6; Rate = 1500; Cost = 250000 },
    [pscustomobject]@{ Prefix = "long"; Name = "long"; Required = "cf: security license long"; RatingCap = 22; Threshold = 8; Rate = 2200; Cost = 550000 },
    [pscustomobject]@{ Prefix = "frontier"; Name = "frontier"; Required = "cf: security license frontier"; RatingCap = 34; Threshold = 10; Rate = 3000; Cost = 950000 }
)

$admiralCampaignTypes = @(
    [pscustomobject]@{ Prefix = "minor"; Name = "minor pirate outpost" },
    [pscustomobject]@{ Prefix = "raider"; Name = "raider base" },
    [pscustomobject]@{ Prefix = "cartel"; Name = "cartel world" },
    [pscustomobject]@{ Prefix = "stronghold"; Name = "pirate stronghold" }
)

function Add-UniqueRoleShip {
    param(
        [array]$Ships,
        [object]$Ship
    )

    $procurement = Get-ShipProcurementName $Ship
    if(@($Ships | Where-Object { (Get-ShipProcurementName $_) -eq $procurement }).Count -gt 0) {
        return @($Ships)
    }
    return @($Ships + $Ship)
}

$autoShuttleShips = @($shipsByName.Values |
    Where-Object {
        $_.Bunks -ge 6 -and
        $_.Crew -ge 0 -and
        @("Transport", "Space Liner") -contains $_.Category
    } |
    Sort-Object Cost, Name |
    ForEach-Object {
        [pscustomobject]@{
            Key = New-CFKey $_.Name
            Name = $_.Name
            Cost = $_.Cost
            Bunks = $_.Bunks
            Crew = $_.Crew
            Luxury = ($_.Category -eq "Space Liner")
        }
    })
foreach($ship in $autoShuttleShips) {
    $shuttleShipTypes = Add-UniqueRoleShip $shuttleShipTypes $ship
}
$shuttleShipTypes = @($shuttleShipTypes | Sort-Object Cost, Name)

$autoMiningShips = @($shipsByName.Values |
    Where-Object {
        $_.Cargo -ge 40 -and
        $_.Crew -ge 0 -and
        $_.Category -eq "Utility"
    } |
    Sort-Object Cost, Name |
    ForEach-Object {
        [pscustomobject]@{
            Key = New-CFKey $_.Name
            Name = $_.Name
            Cost = $_.Cost
            Cargo = $_.Cargo
            Crew = $_.Crew
            DroneCapacity = 0
        }
    })
foreach($ship in $autoMiningShips) {
    $miningShipTypes = Add-UniqueRoleShip $miningShipTypes $ship
}
$miningShipTypes = @($miningShipTypes | Sort-Object Cost, Name)

$autoTradingShips = @($shipsByName.Values |
    Where-Object {
        $_.Cargo -ge 50 -and
        $_.Crew -ge 0 -and
        @("Light Freighter", "Heavy Freighter", "Transport", "Utility", "Space Liner") -contains $_.Category
    } |
    Sort-Object Cost, Name |
    ForEach-Object {
        [pscustomobject]@{
            Key = New-CFKey $_.Name
            Name = $_.Name
            Cost = $_.Cost
            Cargo = $_.Cargo
            Crew = $_.Crew
        }
    })
foreach($ship in $autoTradingShips) {
    $tradingShipTypes = Add-UniqueRoleShip $tradingShipTypes $ship
}
$tradingShipTypes = @($tradingShipTypes | Sort-Object Cost, Name)

$securityRatingByCategory = @{
    "Interceptor" = 1
    "Light Warship" = 2
    "Medium Warship" = 3
    "Heavy Warship" = 6
}
$autoSecurityShips = @($shipsByName.Values |
    Where-Object {
        $_.Crew -ge 0 -and
        $securityRatingByCategory.ContainsKey($_.Category)
    } |
    Sort-Object Cost, Name |
    ForEach-Object {
        [pscustomobject]@{
            Key = New-CFKey $_.Name
            Name = $_.Name
            Class = $_.Category
            Cost = $_.Cost
            Rating = [int]$securityRatingByCategory[$_.Category]
            Crew = $_.Crew
        }
    })
foreach($ship in $autoSecurityShips) {
    $securityShipTypes = Add-UniqueRoleShip $securityShipTypes $ship
}
$securityShipTypes = @($securityShipTypes | Sort-Object Cost, Name)

function Add-MiningClaimAccountingLines {
    param(
        [string]$Prefix,
        [int]$Threshold
    )

    Add-Line "		`"cf: mining $Prefix progress`" += `"cf: mining $Prefix ships`""
    Add-Line "		`"cf: mining $Prefix completed`" = `"cf: mining $Prefix progress`" / $Threshold"
    Add-Line "		`"cf: mining $Prefix bonus payout`" = `"cf: mining $Prefix trip payout`" * `"cf: mining efficiency bonus`" / 100"
    Add-Line "		`"cf: mining $Prefix income`" = `"cf: mining $Prefix trip payout`" + `"cf: mining $Prefix bonus payout`""
    Add-Line "		`"cf: mining $Prefix gross`" = `"cf: mining $Prefix completed`" * `"cf: mining $Prefix income`""
    Add-Line "		`"cf: mining $Prefix expenses`" = `"cf: mining $Prefix completed`" * `"cf: mining $Prefix trip expenses`""
    Add-Line "		`"cf: mining $Prefix profit`" = `"cf: mining $Prefix gross`" - `"cf: mining $Prefix expenses`""
    Add-Line "		`"cf: mining day gross`" += `"cf: mining $Prefix gross`""
    Add-Line "		`"cf: mining day expenses`" += `"cf: mining $Prefix expenses`""
    Add-Line "		`"cf: mining day profit`" += `"cf: mining $Prefix profit`""
    Add-Line "		`"cf: mining revenue`" += `"cf: mining $Prefix gross`""
    Add-Line "		`"cf: mining $Prefix progress`" -= `"cf: mining $Prefix completed`" * $Threshold"
}

function Add-MiningDailyAccountingLines {
    param([int]$ManagerCost = 0)

    Add-Line "		`"cf: mining day gross`" = 0"
    Add-Line "		`"cf: mining day expenses`" = 0"
    Add-Line "		`"cf: mining day profit`" = 0"
    foreach($claim in $miningClaimTypes) {
        Add-MiningClaimAccountingLines $claim.Prefix $claim.Threshold
    }
    Add-Line "		`"cf: last gross`" = `"cf: mining day gross`""
    Add-Line "		`"cf: last expenses`" = `"cf: mining day expenses`""
    Add-Line "		`"cf: last net profit`" = `"cf: mining day profit`""
    Add-Line "		`"cf: manager daily cost`" = 0"
    Add-DivisionPeriodAccountingLines "mining" "cf: mining day gross" "cf: mining day expenses" "cf: mining day profit" $ManagerCost
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: manager daily cost`" = $ManagerCost"
        Add-Line "		`"cf: last expenses`" += $ManagerCost"
        Add-Line "		`"cf: last net profit`" -= $ManagerCost"
        Add-Line "		`"cf: total manager costs`" += $ManagerCost"
    }
    Add-StaffAndTaxCalculationLines
    Add-OfficeStaffCostAccountingLines
    Add-StationDailyAccountingLines
    Add-Line "		`"cf: last expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: month tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last owner payout`" = 0"
    Add-Line "		`"cf: last retained earnings`" = `"cf: last net profit`""
    Add-Line "		`"cf: reserve`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: unallocated net`" += `"cf: last net profit`""
    Add-Line "		`"cf: total gross`" += `"cf: mining day gross`""
    Add-Line "		`"cf: total operating expenses`" += `"cf: mining day expenses`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total operating expenses`" += $ManagerCost"
    }
    Add-Line "		`"cf: total operating expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: total net profit`" += `"cf: mining day profit`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total net profit`" -= $ManagerCost"
    }
    Add-Line "		`"cf: total net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total retained earnings`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: month gross`" += `"cf: mining day gross`""
    Add-Line "		`"cf: month expenses`" += `"cf: last expenses`""
    Add-Line "		`"cf: month net profit`" += `"cf: last net profit`""
    Add-Line "		`"cf: month retained earnings`" += `"cf: last retained earnings`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: month manager costs`" += $ManagerCost"
    }
}

function Add-MiningShipChoice {
    param(
        [object]$Claim,
        [object]$Ship
    )

    if($Ship.Cargo -gt $Claim.CargoCap) {
        return
    }

    $maxCurrentCargo = $Claim.CargoCap - $Ship.Cargo
    Add-Line "				``	Buy a $($Ship.Name) with $($Ship.Cargo) mining cargo for the $($Claim.Name) claim for $($Ship.Cost.ToString('N0')) company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"$($Claim.Required)`""
    Add-ShipAvailabilityRequirement $Ship
    Add-Line "						`"cf: reserve`" >= $($Ship.Cost)"
    Add-Line "						`"cf: mining $($Claim.Prefix) cargo`" <= $maxCurrentCargo"
    Add-Line "					goto `"confirm buy mining $($Claim.Prefix) $($Ship.Key)`""
}

function Add-MiningShipLabel {
    param(
        [object]$Claim,
        [object]$Ship,
        [int]$ValuePerCargo
    )

    Add-ConfirmationLabel "confirm buy mining $($Claim.Prefix) $($Ship.Key)" "buy mining $($Claim.Prefix) $($Ship.Key)" "Buy this $($Ship.Name) for the $($Claim.Name) mining claim for $($Ship.Cost.ToString('N0')) company credits?" "Buy ship."
    Add-Line "			label `"buy mining $($Claim.Prefix) $($Ship.Key)`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= $($Ship.Cost)"
    Add-Line "				`"cf: mining $($Claim.Prefix) cargo`" += $($Ship.Cargo)"
    Add-Line "				`"cf: mining $($Claim.Prefix) ships`" ++"
    Add-Line "				`"cf: mining $($Claim.Prefix) daily crew`" += $($Ship.Crew * 100)"
    if($ValuePerCargo -lt 0) {
        Add-Line "				`"cf: mining $($Claim.Prefix) trip payout`" = `"cf: mining $($Claim.Prefix) cargo`" * `"cf: mining $($Claim.Prefix) value`" / `"cf: mining $($Claim.Prefix) ships`""
    } else {
        Add-Line "				`"cf: mining $($Claim.Prefix) trip payout`" = `"cf: mining $($Claim.Prefix) cargo`" * $ValuePerCargo / `"cf: mining $($Claim.Prefix) ships`""
    }
    Add-Line "				`"cf: mining $($Claim.Prefix) trip expenses`" = `"cf: mining $($Claim.Prefix) daily crew`" * $($Claim.Threshold) / `"cf: mining $($Claim.Prefix) ships`""
    Add-Line "				`"cf: mining fleet`" ++"
    Add-Line "				`"cf: mining drone capacity`" += $($Ship.DroneCapacity)"
    Add-Line "				`"cf: fleet value`" += $($Ship.Cost)"
    Add-Line "			``The company buys a $($Ship.Name) and assigns it to the $($Claim.Name) mining claim. Claim output is capped by licensed cargo throughput, not just by ship count.``"
    Add-CompanyOutlookReturn
}

function Add-MiningDroneChoice {
    Add-Line "				``	Buy a Mining Drone for 58,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining`""
    Add-ConditionLine "has" (Get-ShipAvailableCondition "Mining Drone") "						"
    Add-Line "						`"cf: reserve`" >= 58000"
    Add-Line "						`"cf: mining drones`" < `"cf: mining drone capacity`""
    Add-Line "					goto `"confirm buy mining drone`""
}

function Add-MiningDroneLabel {
    Add-ConfirmationLabel "confirm buy mining drone" "buy mining drone" "Buy a Mining Drone for 58,000 company credits?" "Buy drone."
    Add-Line "			label `"buy mining drone`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 58000"
    Add-Line "				`"cf: mining drones`" ++"
    Add-Line "				`"cf: mining efficiency bonus`" += 15"
    Add-Line "				`"cf: fleet value`" += 58000"
    Add-Line "			``Your mechanics add a Mining Drone to the company fleet. Each drone adds 15% simulated extraction efficiency, limited by drone bays on the company's Sunders.``"
    Add-CompanyOutlookReturn
}

function Add-TradingRouteAccountingLines {
    param(
        [string]$Prefix,
        [int]$Threshold
    )

    Add-Line "		`"cf: trading $Prefix progress`" += `"cf: trading $Prefix ships`""
    Add-Line "		`"cf: trading $Prefix completed`" = `"cf: trading $Prefix progress`" / $Threshold"
    Add-Line "		`"cf: trading $Prefix gross`" = `"cf: trading $Prefix completed`" * `"cf: trading $Prefix trip payout`""
    Add-Line "		`"cf: trading $Prefix expenses`" = `"cf: trading $Prefix completed`" * `"cf: trading $Prefix trip expenses`""
    Add-Line "		`"cf: trading $Prefix profit`" = `"cf: trading $Prefix gross`" - `"cf: trading $Prefix expenses`""
    Add-Line "		`"cf: trading day gross`" += `"cf: trading $Prefix gross`""
    Add-Line "		`"cf: trading day expenses`" += `"cf: trading $Prefix expenses`""
    Add-Line "		`"cf: trading day profit`" += `"cf: trading $Prefix profit`""
    Add-Line "		`"cf: trading revenue`" += `"cf: trading $Prefix gross`""
    Add-Line "		`"cf: trading $Prefix progress`" -= `"cf: trading $Prefix completed`" * $Threshold"
}

function Add-TradingDailyAccountingLines {
    param([int]$ManagerCost = 0)

    Add-Line "		`"cf: trading day gross`" = 0"
    Add-Line "		`"cf: trading day expenses`" = 0"
    Add-Line "		`"cf: trading day profit`" = 0"
    foreach($route in $tradingRouteTypes) {
        Add-TradingRouteAccountingLines $route.Prefix $route.Threshold
    }
    Add-Line "		`"cf: last gross`" = `"cf: trading day gross`""
    Add-Line "		`"cf: last expenses`" = `"cf: trading day expenses`""
    Add-Line "		`"cf: last net profit`" = `"cf: trading day profit`""
    Add-Line "		`"cf: manager daily cost`" = 0"
    Add-DivisionPeriodAccountingLines "trading" "cf: trading day gross" "cf: trading day expenses" "cf: trading day profit" $ManagerCost
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: manager daily cost`" = $ManagerCost"
        Add-Line "		`"cf: last expenses`" += $ManagerCost"
        Add-Line "		`"cf: last net profit`" -= $ManagerCost"
        Add-Line "		`"cf: total manager costs`" += $ManagerCost"
    }
    Add-StaffAndTaxCalculationLines
    Add-OfficeStaffCostAccountingLines
    Add-StationDailyAccountingLines
    Add-Line "		`"cf: last expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: month tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last owner payout`" = 0"
    Add-Line "		`"cf: last retained earnings`" = `"cf: last net profit`""
    Add-Line "		`"cf: reserve`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: unallocated net`" += `"cf: last net profit`""
    Add-Line "		`"cf: total gross`" += `"cf: trading day gross`""
    Add-Line "		`"cf: total operating expenses`" += `"cf: trading day expenses`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total operating expenses`" += $ManagerCost"
    }
    Add-Line "		`"cf: total operating expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: total net profit`" += `"cf: trading day profit`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total net profit`" -= $ManagerCost"
    }
    Add-Line "		`"cf: total net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total retained earnings`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: month gross`" += `"cf: trading day gross`""
    Add-Line "		`"cf: month expenses`" += `"cf: last expenses`""
    Add-Line "		`"cf: month net profit`" += `"cf: last net profit`""
    Add-Line "		`"cf: month retained earnings`" += `"cf: last retained earnings`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: month manager costs`" += $ManagerCost"
    }
}

function Add-TradingShipChoice {
    param(
        [object]$Route,
        [object]$Ship
    )

    if($Ship.Cargo -gt $Route.CargoCap) {
        return
    }

    $maxCurrentCargo = $Route.CargoCap - $Ship.Cargo
    Add-Line "				``	Buy a $($Ship.Name) with $($Ship.Cargo) cargo for the $($Route.Name) trade route for $($Ship.Cost.ToString('N0')) company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"$($Route.Required)`""
    Add-ShipAvailabilityRequirement $Ship
    Add-Line "						`"cf: reserve`" >= $($Ship.Cost)"
    Add-Line "						`"cf: trading $($Route.Prefix) cargo`" <= $maxCurrentCargo"
    Add-Line "					goto `"confirm buy trading $($Route.Prefix) $($Ship.Key)`""
}

function Add-TradingShipLabel {
    param(
        [object]$Route,
        [object]$Ship,
        [int]$BaseValue,
        [int]$OptimizedValue
    )

    Add-ConfirmationLabel "confirm buy trading $($Route.Prefix) $($Ship.Key)" "buy trading $($Route.Prefix) $($Ship.Key)" "Buy this $($Ship.Name) for the $($Route.Name) trade route for $($Ship.Cost.ToString('N0')) company credits?" "Buy ship."
    Add-Line "			label `"buy trading $($Route.Prefix) $($Ship.Key)`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= $($Ship.Cost)"
    Add-Line "				`"cf: trading $($Route.Prefix) cargo`" += $($Ship.Cargo)"
    Add-Line "				`"cf: trading $($Route.Prefix) ships`" ++"
    Add-Line "				`"cf: trading $($Route.Prefix) daily crew`" += $($Ship.Crew * 100)"
    Add-Line "				`"cf: trading $($Route.Prefix) trip payout`" = `"cf: trading $($Route.Prefix) cargo`" * `"cf: trading $($Route.Prefix) current value`" / `"cf: trading $($Route.Prefix) ships`""
    Add-Line "				`"cf: trading $($Route.Prefix) daily expenses`" = `"cf: trading $($Route.Prefix) daily crew`""
    Add-Line "				`"cf: trading $($Route.Prefix) daily expenses`" += `"cf: trading $($Route.Prefix) daily trader`""
    Add-Line "				`"cf: trading $($Route.Prefix) trip expenses`" = `"cf: trading $($Route.Prefix) daily expenses`" * $($Route.Threshold) / `"cf: trading $($Route.Prefix) ships`""
    Add-Line "				`"cf: trading fleet`" ++"
    Add-Line "				`"cf: fleet value`" += $($Ship.Cost)"
    Add-Line "			``The company buys a $($Ship.Name) and assigns it to the $($Route.Name) trade route.``"
    Add-CompanyOutlookReturn
}

function Add-TradingMerchantChoice {
    param([object]$Route)

    Add-Line "				``	Assign a specialist trader to the $($Route.Name) trade route for 10,000 credits per day.``"
    Add-Line "					to display"
    Add-Line "						has `"$($Route.Required)`""
    Add-Line "						not `"cf: trading $($Route.Prefix) trader`""
    Add-Line "						`"cf: trading $($Route.Prefix) ships`" > 0"
    Add-Line "					goto `"confirm assign trading $($Route.Prefix) trader`""
}

function Add-TradingMerchantLabel {
    param(
        [object]$Route,
        [int]$OptimizedValue,
        [string]$Commodity
    )

    Add-ConfirmationLabel "confirm assign trading $($Route.Prefix) trader" "assign trading $($Route.Prefix) trader" "Assign a specialist trader to the $($Route.Name) trade route for 10,000 credits per day?" "Assign trader."
    Add-Line "			label `"assign trading $($Route.Prefix) trader`""
    Add-Line "			action"
    Add-Line "				set `"cf: trading $($Route.Prefix) trader`""
    Add-Line "				`"cf: trading $($Route.Prefix) daily trader`" = 10000"
    if($OptimizedValue -lt 0) {
        Add-Line "				`"cf: trading $($Route.Prefix) current value`" = `"cf: trading $($Route.Prefix) optimized value`""
    } else {
        Add-Line "				`"cf: trading $($Route.Prefix) current value`" = $OptimizedValue"
    }
    Add-Line "				`"cf: trading $($Route.Prefix) trip payout`" = `"cf: trading $($Route.Prefix) cargo`" * `"cf: trading $($Route.Prefix) current value`" / `"cf: trading $($Route.Prefix) ships`""
    Add-Line "				`"cf: trading $($Route.Prefix) daily expenses`" = `"cf: trading $($Route.Prefix) daily crew`""
    Add-Line "				`"cf: trading $($Route.Prefix) daily expenses`" += `"cf: trading $($Route.Prefix) daily trader`""
    Add-Line "				`"cf: trading $($Route.Prefix) trip expenses`" = `"cf: trading $($Route.Prefix) daily expenses`" * $($Route.Threshold) / `"cf: trading $($Route.Prefix) ships`""
    Add-Line "			``The trader takes over market selection on the $($Route.Name) route and focuses on $Commodity, the strongest known price spread on that license.``"
    Add-CompanyOutlookReturn
}

function Add-SecurityContractAccountingLines {
    param(
        [string]$Prefix,
        [int]$Threshold
    )

    Add-Line "		`"cf: security $Prefix progress`" += `"cf: security $Prefix ships`""
    Add-Line "		`"cf: security $Prefix completed`" = `"cf: security $Prefix progress`" / $Threshold"
    Add-Line "		`"cf: security $Prefix gross`" = `"cf: security $Prefix completed`" * `"cf: security $Prefix trip payout`""
    Add-Line "		`"cf: security $Prefix expenses`" = `"cf: security $Prefix completed`" * `"cf: security $Prefix trip expenses`""
    Add-Line "		`"cf: security $Prefix profit`" = `"cf: security $Prefix gross`" - `"cf: security $Prefix expenses`""
    Add-Line "		`"cf: security day gross`" += `"cf: security $Prefix gross`""
    Add-Line "		`"cf: security day expenses`" += `"cf: security $Prefix expenses`""
    Add-Line "		`"cf: security day profit`" += `"cf: security $Prefix profit`""
    Add-Line "		`"cf: security contract revenue`" += `"cf: security $Prefix gross`""
    Add-Line "		`"cf: security $Prefix progress`" -= `"cf: security $Prefix completed`" * $Threshold"
}

function Add-SecurityDailyAccountingLines {
    param([int]$ManagerCost = 0)

    Add-Line "		`"cf: security day gross`" = 0"
    Add-Line "		`"cf: security day expenses`" = 0"
    Add-Line "		`"cf: security day profit`" = 0"
    foreach($contract in $securityContractTypes) {
        Add-SecurityContractAccountingLines $contract.Prefix $contract.Threshold
    }
    Add-Line "		`"cf: security admiral cost`" = `"cf: security admiral`" * 20000"
    Add-Line "		`"cf: admiral travel days`" --"
    Add-Line "		`"cf: admiral travel days`" >?= 0"
    Add-Line "		`"cf: security day gross`" += `"cf: admiral tribute income`""
    Add-Line "		`"cf: admiral tribute revenue`" += `"cf: admiral tribute income`""
    Add-Line "		`"cf: security day expenses`" += `"cf: admiral daily crew`""
    Add-Line "		`"cf: security day expenses`" += `"cf: security admiral cost`""
    Add-Line "		`"cf: security day profit`" += `"cf: admiral tribute income`""
    Add-Line "		`"cf: security day profit`" -= `"cf: admiral daily crew`""
    Add-Line "		`"cf: security day profit`" -= `"cf: security admiral cost`""
    Add-Line "		`"cf: last gross`" = `"cf: security day gross`""
    Add-Line "		`"cf: last expenses`" = `"cf: security day expenses`""
    Add-Line "		`"cf: last net profit`" = `"cf: security day profit`""
    Add-Line "		`"cf: manager daily cost`" = 0"
    Add-DivisionPeriodAccountingLines "security" "cf: security day gross" "cf: security day expenses" "cf: security day profit" $ManagerCost
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: manager daily cost`" = $ManagerCost"
        Add-Line "		`"cf: last expenses`" += $ManagerCost"
        Add-Line "		`"cf: last net profit`" -= $ManagerCost"
        Add-Line "		`"cf: total manager costs`" += $ManagerCost"
    }
    Add-Line "		`"cf: security admiral costs`" += `"cf: security admiral cost`""
    Add-StaffAndTaxCalculationLines
    Add-OfficeStaffCostAccountingLines
    Add-StationDailyAccountingLines
    Add-Line "		`"cf: last expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: month tax paid`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: last owner payout`" = 0"
    Add-Line "		`"cf: last retained earnings`" = `"cf: last net profit`""
    Add-Line "		`"cf: reserve`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: unallocated net`" += `"cf: last net profit`""
    Add-Line "		`"cf: total gross`" += `"cf: security day gross`""
    Add-Line "		`"cf: total operating expenses`" += `"cf: security day expenses`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total operating expenses`" += $ManagerCost"
    }
    Add-Line "		`"cf: total operating expenses`" += `"cf: hq daily tax`""
    Add-Line "		`"cf: total net profit`" += `"cf: security day profit`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: total net profit`" -= $ManagerCost"
    }
    Add-Line "		`"cf: total net profit`" -= `"cf: hq daily tax`""
    Add-Line "		`"cf: total retained earnings`" += `"cf: last retained earnings`""
    Add-Line "		`"cf: month gross`" += `"cf: security day gross`""
    Add-Line "		`"cf: month expenses`" += `"cf: last expenses`""
    Add-Line "		`"cf: month net profit`" += `"cf: last net profit`""
    Add-Line "		`"cf: month retained earnings`" += `"cf: last retained earnings`""
    if($ManagerCost -gt 0) {
        Add-Line "		`"cf: month manager costs`" += $ManagerCost"
    }
}

function Add-SecurityShipChoice {
    param(
        [object]$Contract,
        [object]$Ship
    )

    if($Ship.Rating -gt $Contract.RatingCap) {
        return
    }

    $maxCurrentRating = $Contract.RatingCap - $Ship.Rating
    Add-Line "				``	Buy a $($Ship.Name) $($Ship.Class) with escort rating $($Ship.Rating) for the $($Contract.Name) security contract for $($Ship.Cost.ToString('N0')) company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"$($Contract.Required)`""
    Add-ShipAvailabilityRequirement $Ship
    Add-Line "						`"cf: reserve`" >= $($Ship.Cost)"
    Add-Line "						`"cf: security $($Contract.Prefix) rating`" <= $maxCurrentRating"
    Add-Line "					goto `"confirm buy security $($Contract.Prefix) $($Ship.Key)`""
}

function Add-SecurityShipLabel {
    param(
        [object]$Contract,
        [object]$Ship
    )

    Add-ConfirmationLabel "confirm buy security $($Contract.Prefix) $($Ship.Key)" "buy security $($Contract.Prefix) $($Ship.Key)" "Buy this $($Ship.Name) for the $($Contract.Name) security contract for $($Ship.Cost.ToString('N0')) company credits?" "Buy ship."
    Add-Line "			label `"buy security $($Contract.Prefix) $($Ship.Key)`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= $($Ship.Cost)"
    Add-Line "				`"cf: security $($Contract.Prefix) rating`" += $($Ship.Rating)"
    Add-Line "				`"cf: security $($Contract.Prefix) ships`" ++"
    Add-Line "				`"cf: security $($Contract.Prefix) daily crew`" += $($Ship.Crew * 100)"
    Add-Line "				`"cf: security $($Contract.Prefix) trip payout`" = `"cf: security $($Contract.Prefix) rating`" * $($Contract.Rate) * $($Contract.Threshold) / `"cf: security $($Contract.Prefix) ships`""
    Add-Line "				`"cf: security $($Contract.Prefix) trip expenses`" = `"cf: security $($Contract.Prefix) daily crew`" * $($Contract.Threshold) / `"cf: security $($Contract.Prefix) ships`""
    Add-Line "				`"cf: security fleet`" ++"
    Add-Line "				`"cf: security combat rating`" += $($Ship.Rating)"
    Add-Line "				`"cf: fleet value`" += $($Ship.Cost)"
    Add-Line "			``The company buys a $($Ship.Name) and assigns it to the $($Contract.Name) security contract. Each combat ship covers one escort slot, while stronger ships can take higher-risk protection work.``"
    Add-CompanyOutlookReturn
}

function Add-SecurityAdmiralChoice {
    Add-Line "				``	Hire a fleet admiral for 300,000 company credits plus 20,000 credits per day.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security`""
    Add-Line "						not `"cf: security admiral`""
    Add-Line "						`"cf: reserve`" >= 300000"
    Add-Line "					goto `"confirm hire security admiral`""
}

function Add-SecurityAdmiralLabel {
    param([string]$BasePlanet = "")

    Add-ConfirmationLabel "confirm hire security admiral" "hire security admiral" "Hire a fleet admiral for 300,000 company credits plus 20,000 credits per day?" "Hire admiral."
    Add-Line "			label `"hire security admiral`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 300000"
    Add-Line "				set `"cf: security admiral`""
    if($BasePlanet -ne "") {
        Add-ClearAllAdmiralLocationConditions "				"
        Add-ClearAllAdmiralDestinationConditions "				"
        Add-ConditionLine "set" "cf: admiral location: $BasePlanet" "				"
    }
    Add-Line "				clear `"cf: admiral in transit`""
    Add-Line "				`"cf: admiral travel days`" = 0"
    Add-Line "			``You hire a fleet admiral to command an independent strike fleet. The admiral keeps their office at headquarters, but the strike fleet's current operating location starts here. They cost 20,000 credits per day, and escort-route ships do not count toward the admiral's fleet rating.``"
    Add-CompanyOutlookReturn
}

function Add-AdmiralShipChoice {
    param([object]$Ship)

    Add-Line "				``	Buy a $($Ship.Name) $($Ship.Class) for the admiral fleet for $($Ship.Cost.ToString('N0')) company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security admiral`""
    Add-Line "						not `"cf: admiral in transit`""
    Add-Line "						`"cf: admiral travel days`" == 0"
    Add-ShipAvailabilityRequirement $Ship
    Add-Line "						`"cf: reserve`" >= $($Ship.Cost)"
    Add-Line "					goto `"confirm buy admiral $($Ship.Key)`""
}

function Add-AdmiralShipLabel {
    param([object]$Ship)

    Add-ConfirmationLabel "confirm buy admiral $($Ship.Key)" "buy admiral $($Ship.Key)" "Buy this $($Ship.Name) for the admiral fleet for $($Ship.Cost.ToString('N0')) company credits?" "Buy ship."
    Add-Line "			label `"buy admiral $($Ship.Key)`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= $($Ship.Cost)"
    Add-Line "				`"cf: admiral fleet`" ++"
    Add-Line "				`"cf: admiral rating`" += $($Ship.Rating)"
    Add-Line "				`"cf: admiral daily crew`" += $($Ship.Crew * 100)"
    Add-Line "				`"cf: fleet value`" += $($Ship.Cost)"
    Add-Line "			``The admiral commissions a $($Ship.Name) for the independent strike fleet. It does not protect escort routes; it only raises the admiral fleet rating used for pirate tribute campaigns.``"
    Add-CompanyOutlookReturn
}

function Add-AdmiralTributeChoice {
    param(
        [object]$Campaign,
        [object]$Target
    )

    Add-Line "				``	Force $($Target.Planet) in $($Target.System) to pay $($Target.Tribute.ToString('N0')) credits per day in tribute. Requires admiral fleet rating $($Target.RequiredRating) and $($Target.OperationCost.ToString('N0')) operation reserve.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security admiral`""
    Add-Line "						not `"cf: admiral tribute $($Campaign.Prefix)`""
    Add-Line "						not `"cf: admiral in transit`""
    Add-Line "						`"cf: admiral travel days`" == 0"
    Add-KnownPlanetRequirement $Target.Planet
    Add-ConditionLine "has" "cf: admiral location: $($Target.Planet)" "						"
    Add-Line "						`"cf: admiral rating`" >= $($Target.RequiredRating)"
    Add-Line "						`"cf: reserve`" >= $($Target.OperationCost)"
    Add-Line "					goto `"confirm force tribute $($Campaign.Prefix)`""
}

function Add-AdmiralTributeLabel {
    param(
        [object]$Campaign,
        [object]$Target
    )

    Add-ConfirmationLabel "confirm force tribute $($Campaign.Prefix)" "force tribute $($Campaign.Prefix)" "Start the $($Campaign.Name) tribute operation against $($Target.Planet) for $($Target.OperationCost.ToString('N0')) company credits?" "Start operation."
    Add-Line "			label `"force tribute $($Campaign.Prefix)`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= $($Target.OperationCost)"
    Add-Line "				set `"cf: admiral tribute $($Campaign.Prefix)`""
    Add-Line "				`"cf: admiral tribute count`" ++"
    Add-Line "				`"cf: admiral tribute income`" += $($Target.Tribute)"
    Add-Line "			``The admiral's strike fleet coerces $($Target.Planet) from its current operating location into a standing tribute contract. The base-game tribute threshold there is $($Target.Threshold.ToString('N0')), mapped to company fleet rating $($Target.RequiredRating).``"
    Add-CompanyOutlookReturn
}

function Add-ManagerRoutePurchaseMission {
    param(
        [string]$Prefix,
        [string]$DisplayName,
        [string]$RequiredCondition,
        [string]$NewCondition,
        [int]$Cost,
        [string]$HqCondition = "",
        [string]$TargetSystem = "",
        [string]$HqName = ""
    )

    $reserveNeeded = $Cost * 2
    $missionSuffix = if($HqName -ne "") { ": $HqName" } else { "" }
    Add-Line "mission `"Company Foundations: Manager Buy $DisplayName Shuttle Route$missionSuffix`""
    Add-Line "	name `"Manager Route Purchase`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: shuttle`""
    Add-Line "		has `"cf: managed`""
    if($HqCondition -ne "") {
        Add-Line "		has $HqCondition"
        Add-Line "		not `"cf: hq suspended`""
    }
    if($RequiredCondition -ne "") {
        Add-Line "		has `"$RequiredCondition`""
    }
    Add-Line "		not `"$NewCondition`""
    if($TargetSystem -ne "") {
        Add-KnownSystemRequirement $TargetSystem "		"
    }
    Add-Line "		`"cf: reserve`" >= $reserveNeeded"
    Add-Line "	on offer"
    Add-Line "		`"cf: reserve`" -= $Cost"
    Add-Line "		set `"$NewCondition`""
    Add-Line "		`"cf: shuttle route count`" ++"
    Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought the $DisplayName shuttle route for $($Cost.ToString('N0')) company credits after keeping at least double the purchase cost in reserve.``"
    Add-Line ""
}

function Add-ManagerRouteOptimizationMission {
    param([object]$Plan)

    $reserveNeeded = $Plan.Cost * 2
    Add-Line "mission `"Company Foundations: Manager Optimize $($Plan.Name) Shuttle Route`""
    Add-Line "	name `"Manager Fleet Optimization`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: shuttle`""
    Add-Line "		has `"cf: managed`""
    Add-Line "		not `"cf: hq suspended`""
    Add-Line "		has `"$($Plan.Required)`""
    Add-Line "		not `"$($Plan.Marker)`""
    foreach($ship in @($Plan.RequiredShips)) {
        Add-ConditionLine "has" (Get-ShipAvailableCondition $ship) "		"
    }
    Add-Line "		`"cf: reserve`" >= $reserveNeeded"
    Add-Line "	on offer"
    Add-Line "		`"cf: reserve`" -= $($Plan.Cost)"
    Add-Line "		set `"$($Plan.Marker)`""
    Add-Line "		`"cf: shuttle fleet`" -= `"cf: shuttle $($Plan.Prefix) ships`""
    Add-Line "		`"cf: shuttle $($Plan.Prefix) pax`" = $($Plan.Pax)"
    Add-Line "		`"cf: shuttle $($Plan.Prefix) ships`" = $($Plan.Ships)"
    Add-Line "		`"cf: shuttle $($Plan.Prefix) daily crew`" = $($Plan.DailyCrew)"
    Add-Line "		`"cf: shuttle $($Plan.Prefix) trip payout`" = $($Plan.TripPayout)"
    Add-Line "		`"cf: shuttle $($Plan.Prefix) trip expenses`" = $($Plan.TripExpenses)"
    Add-Line "		`"cf: shuttle fleet`" += $($Plan.Ships)"
    Add-Line "		`"cf: fleet value`" += $($Plan.Cost)"
    if($Plan.Luxury) {
        Add-Line "		set `"cf: shuttle $($Plan.Prefix) luxury`""
    }
    Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager optimized the $($Plan.Name) route with $($Plan.Description) for $($Plan.Cost.ToString('N0')) company credits after keeping at least double the package cost in reserve.``"
    Add-Line ""
}

function Add-ManagerShuttleShipPurchaseMission {
    param(
        [object]$Route,
        [object]$Ship,
        [string]$HqCondition,
        [string]$HqName
    )

    if($Ship.Bunks -gt $Route.PaxCap) {
        return
    }

    $neededReserve = $Ship.Cost * 2
    $maxCurrentPax = $Route.PaxCap - $Ship.Bunks
    $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($Ship.Name) for $($Route.Name) Shuttle: $HqName"
    Add-Line "mission $missionName"
    Add-Line "	name `"Manager Shuttle Fleet Purchase`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: shuttle`""
    Add-Line "		has `"cf: managed`""
    Add-Line "		has $HqCondition"
    Add-Line "		not `"cf: hq suspended`""
    Add-Line "		has `"$($Route.Required)`""
    Add-ShipAvailabilityRequirement $Ship "		"
    Add-Line "		`"cf: reserve`" >= $neededReserve"
    Add-Line "		`"cf: shuttle $($Route.Prefix) pax`" <= $maxCurrentPax"
    Add-Line "	on offer"
    Add-Line "		`"cf: reserve`" -= $($Ship.Cost)"
    Add-Line "		`"cf: shuttle $($Route.Prefix) pax`" += $($Ship.Bunks)"
    Add-Line "		`"cf: shuttle $($Route.Prefix) ships`" ++"
    Add-Line "		`"cf: shuttle $($Route.Prefix) daily crew`" += $($Ship.Crew * 100)"
    Add-Line "		`"cf: shuttle $($Route.Prefix) trip payout`" = `"cf: shuttle $($Route.Prefix) pax`" * $($Route.Fare) / `"cf: shuttle $($Route.Prefix) ships`""
    Add-Line "		`"cf: shuttle $($Route.Prefix) trip expenses`" = `"cf: shuttle $($Route.Prefix) daily crew`" * $($Route.Threshold) / `"cf: shuttle $($Route.Prefix) ships`""
    Add-Line "		`"cf: shuttle fleet`" ++"
    Add-Line "		`"cf: fleet value`" += $($Ship.Cost)"
    if($Ship.Luxury) {
        Add-Line "		set `"cf: shuttle $($Route.Prefix) luxury`""
    }
    Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought a $($Ship.Name) for the $($Route.Name) shuttle route for $($Ship.Cost.ToString('N0')) company credits after keeping at least double the ship cost in reserve.``"
    Add-Line ""
}

function Add-ShuttleDivisionMenus {
    Add-Line "			label `"menu shuttle`""
    Add-Line "			action"
    Add-DivisionProjectionActionLines "				"
    Add-Line "			``Shuttle division: routes &[number@cf: shuttle route count], ships &[number@cf: shuttle fleet], last gross &[credits@cf: shuttle last gross], last expenses &[credits@cf: shuttle last expenses], last net &[credits@cf: shuttle last net].``"
    Add-Line "			``Shuttle average: daily gross &[credits@cf: shuttle projected gross], daily expenses &[credits@cf: shuttle projected expenses], daily net &[credits@cf: shuttle projected net]. Lifetime net &[credits@cf: shuttle total net].``"
    Add-Line "			choice"
    Add-Line "				``	Buy shuttle licenses.``"
    Add-Line "					goto `"menu shuttle licenses`""
    Add-Line "				``	Buy shuttle ships.``"
    Add-Line "					goto `"menu shuttle ships`""
    Add-Line "				``	Back to division selection.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu shuttle licenses`""
    Add-Line "			``Shuttle routes and passenger rights.``"
    Add-Line "			choice"
    Add-Line "				``	Buy the regional shuttle route for 120,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle`""
    Add-Line "						not `"cf: shuttle route regional`""
    Add-Line "						`"cf: reserve`" >= 120000"
    Add-Line "					goto `"confirm buy regional route`""
    Add-Line "				``	Buy the long shuttle route for 275,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle route regional`""
    Add-Line "						not `"cf: shuttle route long`""
    Add-Line "						`"cf: reserve`" >= 275000"
    Add-Line "					goto `"confirm buy long route`""
    Add-Line "				``	Buy the frontier shuttle route for 475,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle route long`""
    Add-Line "						not `"cf: shuttle route frontier`""
    Add-Line "						`"cf: reserve`" >= 475000"
    Add-Line "					goto `"confirm buy frontier route`""
    Add-Line "				``	Back to shuttle.``"
    Add-Line "					goto `"menu shuttle`""
    Add-Line "			label `"menu shuttle ships`""
    Add-Line "			``Shuttle fleet procurement.``"
    Add-Line "			choice"
    foreach($route in $shuttleRouteTypes) {
        foreach($ship in $shuttleShipTypes) {
            Add-ShuttleShipChoice $route $ship
        }
        Add-ShuttleVipChoice $route
    }
    Add-Line "				``	Back to shuttle.``"
    Add-Line "					goto `"menu shuttle`""
}

function Add-MiningDivisionMenus {
    Add-Line "			label `"menu mining`""
    Add-Line "			action"
    Add-DivisionProjectionActionLines "				"
    Add-Line "			``Mining division: claims &[number@cf: mining claim count], ships &[number@cf: mining fleet], drones &[number@cf: mining drones]/&[number@cf: mining drone capacity], last gross &[credits@cf: mining last gross], last expenses &[credits@cf: mining last expenses], last net &[credits@cf: mining last net].``"
    Add-Line "			``Mining average: daily gross &[credits@cf: mining projected gross], daily expenses &[credits@cf: mining projected expenses], daily net &[credits@cf: mining projected net]. Lifetime net &[credits@cf: mining total net].``"
    Add-Line "			choice"
    Add-Line "				``	Buy mining licenses.``"
    Add-Line "					goto `"menu mining licenses`""
    Add-Line "				``	Buy mining ships.``"
    Add-Line "					goto `"menu mining ships`""
    Add-Line "				``	Back to division selection.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu mining licenses`""
    Add-Line "			``Mining claims and rights.``"
    Add-Line "			choice"
    Add-Line "				``	Buy the regional mining rights for 220,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining`""
    Add-Line "						not `"cf: mining claim regional`""
    Add-Line "						`"cf: reserve`" >= 220000"
    Add-Line "					goto `"confirm buy regional mining claim`""
    Add-Line "				``	Buy the deep mining rights for 420,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining claim regional`""
    Add-Line "						not `"cf: mining claim deep`""
    Add-Line "						`"cf: reserve`" >= 420000"
    Add-Line "					goto `"confirm buy deep mining claim`""
    Add-Line "				``	Buy the frontier mining rights for 700,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining claim deep`""
    Add-Line "						not `"cf: mining claim frontier`""
    Add-Line "						`"cf: reserve`" >= 700000"
    Add-Line "					goto `"confirm buy frontier mining claim`""
    Add-Line "				``	Back to mining.``"
    Add-Line "					goto `"menu mining`""
    Add-Line "			label `"menu mining ships`""
    Add-Line "			``Mining fleet procurement.``"
    Add-Line "			choice"
    foreach($claim in $miningClaimTypes) {
        foreach($ship in $miningShipTypes) {
            Add-MiningShipChoice $claim $ship
        }
    }
    Add-MiningDroneChoice
    Add-Line "				``	Back to mining.``"
    Add-Line "					goto `"menu mining`""
}

function Add-TradingDivisionMenus {
    Add-Line "			label `"menu trading`""
    Add-Line "			action"
    Add-DivisionProjectionActionLines "				"
    Add-Line "			``Trading division: licenses &[number@cf: trading route count], ships &[number@cf: trading fleet], last gross &[credits@cf: trading last gross], last expenses &[credits@cf: trading last expenses], last net &[credits@cf: trading last net].``"
    Add-Line "			``Trading average: daily gross &[credits@cf: trading projected gross], daily expenses &[credits@cf: trading projected expenses], daily net &[credits@cf: trading projected net]. Lifetime net &[credits@cf: trading total net].``"
    Add-Line "			choice"
    Add-Line "				``	Buy trading licenses.``"
    Add-Line "					goto `"menu trading licenses`""
    Add-Line "				``	Buy trading ships.``"
    Add-Line "					goto `"menu trading ships`""
    Add-Line "				``	Back to division selection.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu trading licenses`""
    Add-Line "			``Trading licenses and route rights.``"
    Add-Line "			choice"
    Add-Line "				``	Buy the regional trading license for 180,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading`""
    Add-Line "						not `"cf: trading license regional`""
    Add-Line "						`"cf: reserve`" >= 180000"
    Add-Line "					goto `"confirm buy regional trading license`""
    Add-Line "				``	Buy the long trading license for 400,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading license regional`""
    Add-Line "						not `"cf: trading license long`""
    Add-Line "						`"cf: reserve`" >= 400000"
    Add-Line "					goto `"confirm buy long trading license`""
    Add-Line "				``	Buy the frontier trading license for 750,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading license long`""
    Add-Line "						not `"cf: trading license frontier`""
    Add-Line "						`"cf: reserve`" >= 750000"
    Add-Line "					goto `"confirm buy frontier trading license`""
    Add-Line "				``	Back to trading.``"
    Add-Line "					goto `"menu trading`""
    Add-Line "			label `"menu trading ships`""
    Add-Line "			``Trading fleet procurement and specialist traders.``"
    Add-Line "			choice"
    foreach($route in $tradingRouteTypes) {
        foreach($ship in $tradingShipTypes) {
            Add-TradingShipChoice $route $ship
        }
        Add-TradingMerchantChoice $route
    }
    Add-Line "				``	Back to trading.``"
    Add-Line "					goto `"menu trading`""
}

function Add-SecurityDivisionMenus {
    Add-Line "			label `"menu security`""
    Add-Line "			action"
    Add-DivisionProjectionActionLines "				"
    Add-Line "			``Security division: licenses &[number@cf: security contract count], escort ships &[number@cf: security fleet], escort rating &[number@cf: security combat rating], last gross &[credits@cf: security last gross], last expenses &[credits@cf: security last expenses], last net &[credits@cf: security last net].``"
    Add-Line "			``Security average: daily gross &[credits@cf: security projected gross], daily expenses &[credits@cf: security projected expenses], daily net &[credits@cf: security projected net]. Lifetime net &[credits@cf: security total net].``"
    Add-Line "			choice"
    Add-Line "				``	Buy security licenses.``"
    Add-Line "					goto `"menu security licenses`""
    Add-Line "				``	Buy security ships.``"
    Add-Line "					goto `"menu security ships`""
    Add-Line "				``	Manage admiral.``"
    Add-Line "					goto `"menu manager`""
    Add-Line "				``	Back to division selection.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu security licenses`""
    Add-Line "			``Escort licenses and protection contracts.``"
    Add-Line "			choice"
    Add-Line "				``	Buy the regional security license for 250,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security`""
    Add-Line "						not `"cf: security license regional`""
    Add-Line "						`"cf: reserve`" >= 250000"
    Add-Line "					goto `"confirm buy regional security license`""
    Add-Line "				``	Buy the long security license for 550,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security license regional`""
    Add-Line "						not `"cf: security license long`""
    Add-Line "						`"cf: reserve`" >= 550000"
    Add-Line "					goto `"confirm buy long security license`""
    Add-Line "				``	Buy the frontier security license for 950,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security license long`""
    Add-Line "						not `"cf: security license frontier`""
    Add-Line "						`"cf: reserve`" >= 950000"
    Add-Line "					goto `"confirm buy frontier security license`""
    Add-Line "				``	Back to security.``"
    Add-Line "					goto `"menu security`""
    Add-Line "			label `"menu security ships`""
    Add-Line "			``Security fleet procurement.``"
    Add-Line "			choice"
    foreach($contract in $securityContractTypes) {
        foreach($ship in $securityShipTypes) {
            Add-SecurityShipChoice $contract $ship
        }
    }
    foreach($ship in $securityShipTypes) {
        Add-AdmiralShipChoice $ship
    }
    Add-Line "				``	Back to security.``"
    Add-Line "					goto `"menu security`""
}

function Add-GenericCompanyBoardMission {
    Add-Line "mission `"Company Foundations: Company Board`""
    Add-Line "	name `"Company Headquarters`""
    Add-Line "	description `"Review your active company and change how it is managed.`""
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		has `"cf: at hq`""
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			label `"company main menu`""
    Add-Line "			action"
    Add-CompanyProjectionActionLines "				"
    Add-DivisionProjectionActionLines "				"
    Add-CompanyValuationActionLines "				"
    Add-Line "			``Your company terminal opens the current balance board. The detailed registration lives at your headquarters, but the operating ledger can be reviewed from any relay office.``"
    Add-Line "			``	COMPANY BOARD``"
    Add-Line "			``	Firm value: &[credits@cf: company value].``"
    Add-Line "			``	Reserve: &[credits@cf: reserve].``"
    Add-Line "			``	Daily gross (average): &[credits@cf: projected gross].``"
    Add-Line "			``	Daily net income (average): &[credits@cf: projected net].``"
    Add-Line "			``	Cash: company reserve &[credits@cf: reserve], AutoPay queue &[credits@cf: owner payable], lifetime owner cash received &[credits@cf: total owner payouts].``"
    Add-Line "			``	Last period: gross &[credits@cf: last gross], expenses &[credits@cf: last expenses], net &[credits@cf: last net profit], owner allocation &[credits@cf: last owner payout], retained &[credits@cf: last retained earnings].``"
    Add-Line "			``	Policy: payout share &[number@cf: payout share]%. AutoPay is always on; owner payouts are transferred automatically with no tax or transaction deduction.``"
    Add-Line "			``	Staff and taxes: &[number@cf: worker staff] workers, &[number@cf: office staff] office staff, &[number@cf: specialist staff] specialist(s), &[number@cf: total staff] total. Office payroll &[credits@cf: office daily cost]/day, employee tax &[credits@cf: employee tax]/day, HQ tax &[credits@cf: hq daily tax]/day.``"
    Add-Line "			``	Management: owner-managed. You keep direct control, but expansion only happens when you personally fund it.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: manual`""
    Add-Line "			``	Management: manager-run. Manager salary is 10,000 credits/day before owner payout. If salary cannot be covered for two checked operating days in a row, the manager resigns.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: managed`""
    Add-Line "			``	Manager salary warning: &[number@cf: manager unpaid days] unpaid checked day(s) in the current streak. At 2, the manager will quit.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: managed`""
    Add-Line "					`"cf: manager unpaid days`" > 0"
    Add-Line "			``	OPERATIONS``"
    Add-Line "			``	Shuttle network: &[number@cf: shuttle route count] route(s), &[number@cf: shuttle fleet] simulated ship(s), completed route revenue &[credits@cf: shuttle route revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: shuttle`""
    Add-Line "			``	Mining operation: &[number@cf: mining claim count] claim(s), &[number@cf: mining fleet] simulated ship(s), &[number@cf: mining drones]/&[number@cf: mining drone capacity] Mining Drones, extraction bonus &[number@cf: mining efficiency bonus]%. Completed ore revenue: &[credits@cf: mining revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: mining`""
    Add-Line "			``	Trading network: &[number@cf: trading route count] license(s), &[number@cf: trading fleet] simulated ship(s), completed trade revenue &[credits@cf: trading revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: trading`""
    Add-Line "			``	Security bureau: &[number@cf: security contract count] escort license(s), &[number@cf: security fleet] simulated escort ship(s), escort rating &[number@cf: security combat rating], escort revenue &[credits@cf: security contract revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security`""
    Add-Line "			``	Admiral command: &[number@cf: admiral fleet] strike ship(s), fleet rating &[number@cf: admiral rating], tribute contracts &[number@cf: admiral tribute count], daily tribute &[credits@cf: admiral tribute income], lifetime tribute &[credits@cf: admiral tribute revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security admiral`""
    Add-Line "			``	Company stations: &[number@cf: station count] orbital asset(s), station value &[credits@cf: station value], daily station income &[credits@cf: station daily income], upkeep &[credits@cf: station daily upkeep], lifetime station revenue &[credits@cf: total station revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: station orbital office`""
    Add-Line "			``	AUTOPAY``"
    Add-Line "				to display"
    Add-Line "					has `"cf: autopay`""
    Add-Line "			``	Automatic transfers: gross &[credits@cf: autopay gross transfers], net received &[credits@cf: autopay net transfers], fees &[credits@cf: autopay fees], transfer batches &[number@cf: autopay transfers].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: autopay`""
    Add-Line "			``	Open issue: the company has reported an operating loss. Stabilize the reserve, then close the distress file here.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: distress open`""
    Add-Line "			``	HISTORY``"
    Add-Line "			``	HQ history: relocations &[number@cf: hq relocation count], relocation costs &[credits@cf: total relocation costs], access suspensions &[number@cf: hq suspension count].``"
    Add-Line "			``	Lifetime: gross &[credits@cf: total gross], operating expenses &[credits@cf: total operating expenses], manager costs &[credits@cf: total manager costs], taxes &[credits@cf: total tax paid], net profit &[credits@cf: total net profit], owner allocations &[credits@cf: total owner allocations], retained earnings &[credits@cf: total retained earnings].``"
    Add-Line "			choice"
    Add-Line "				``	Manage company / holding.``"
    Add-Line "					goto `"menu total`""
    Add-Line "				``	Manage shuttle division.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle`""
    Add-Line "					goto `"menu shuttle`""
    Add-Line "				``	Manage mining division.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining`""
    Add-Line "					goto `"menu mining`""
    Add-Line "				``	Manage trading division.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading`""
    Add-Line "					goto `"menu trading`""
    Add-Line "				``	Manage security division.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security`""
    Add-Line "					goto `"menu security`""
    Add-Line "				``	File the report and leave.``"
    Add-Line "					decline"
    Add-Line "			label `"menu total`""
    Add-Line "			``Holding administration.``"
    Add-Line "			choice"
    Add-Line "				``	Adjust payout.``"
    Add-Line "					goto `"menu payout`""
    Add-Line "				``	Buy licenses.``"
    Add-Line "					goto `"menu licenses`""
    Add-Line "				``	Buy ships.``"
    Add-Line "					goto `"menu ships`""
    Add-Line "				``	Hire/manage manager.``"
    Add-Line "					goto `"menu manager`""
    Add-Line "				``	Detailed balance.``"
    Add-Line "					goto `"menu balance`""
    Add-Line "				``	Manage HQ.``"
    Add-Line "					goto `"menu hq`""
    Add-Line "				``	Build stations.``"
    Add-Line "					goto `"menu stations`""
    Add-Line "				``	Invest.``"
    Add-Line "					goto `"menu invest`""
    Add-Line "				``	Back to division selection.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu payout`""
    Add-Line "			``Payout policy and owner transfers.``"
    Add-Line "			choice"
    foreach($share in @(0, 10, 25, 50, 75, 100)) {
        Add-Line "				``	Set owner payout share to $share%.``"
        Add-Line "					to display"
        Add-Line "						has `"cf: active`""
        Add-Line "					goto `"confirm set payout $share`""
    }
    Add-Line "				``	Enable AutoPay for owner payouts. Automatic transfers pay the full amount to you.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						not `"cf: autopay`""
    Add-Line "					goto `"confirm enable autopay`""
    Add-Line "				``	Disable AutoPay. Future owner payouts will wait in owner payable until collected manually.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						has `"cf: autopay`""
    Add-Line "						has `"cf: manual autopay controls enabled`""
    Add-Line "					goto `"confirm disable autopay`""
    foreach($amount in @(1000, 5000, 10000, 50000, 250000)) {
        Add-OwnerPayoutChoice $amount
    }
    Add-Line "				``	Back.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu licenses`""
    Add-Line "			``Licenses, routes, claims, and additional company divisions.``"
    Add-Line "			choice"
    Add-Line "				``	Add shuttle division for 650,000 credits.``"
    Add-Line "					to display"
    Add-Line "						not `"cf: shuttle`""
    Add-Line "						`"credits`" >= 650000"
    Add-Line "					goto `"confirm add shuttle division`""
    Add-Line "				``	Add mining division for 900,000 credits.``"
    Add-Line "					to display"
    Add-Line "						not `"cf: mining`""
    Add-Line "						`"credits`" >= 900000"
    Add-Line "					goto `"confirm add mining division`""
    Add-Line "				``	Add trading division for 1.25M credits.``"
    Add-Line "					to display"
    Add-Line "						not `"cf: trading`""
    Add-Line "						`"credits`" >= 1250000"
    Add-Line "					goto `"confirm add trading division`""
    Add-Line "				``	Add security division for 3.5M credits.``"
    Add-Line "					to display"
    Add-Line "						not `"cf: security`""
    Add-Line "						`"credits`" >= 3500000"
    Add-Line "						`"combat rating`" >= 50"
    Add-Line "					goto `"confirm add security division`""
    Add-Line "				``	Buy the regional shuttle route for 120,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle`""
    Add-Line "						not `"cf: shuttle route regional`""
    Add-Line "						`"cf: reserve`" >= 120000"
    Add-Line "					goto `"confirm buy regional route`""
    Add-Line "				``	Buy the long shuttle route for 275,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle route regional`""
    Add-Line "						not `"cf: shuttle route long`""
    Add-Line "						`"cf: reserve`" >= 275000"
    Add-Line "					goto `"confirm buy long route`""
    Add-Line "				``	Buy the frontier shuttle route for 475,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle route long`""
    Add-Line "						not `"cf: shuttle route frontier`""
    Add-Line "						`"cf: reserve`" >= 475000"
    Add-Line "					goto `"confirm buy frontier route`""
    Add-Line "				``	Buy the regional mining rights for 220,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining`""
    Add-Line "						not `"cf: mining claim regional`""
    Add-Line "						`"cf: reserve`" >= 220000"
    Add-Line "					goto `"confirm buy regional mining claim`""
    Add-Line "				``	Buy the deep mining rights for 420,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining claim regional`""
    Add-Line "						not `"cf: mining claim deep`""
    Add-Line "						`"cf: reserve`" >= 420000"
    Add-Line "					goto `"confirm buy deep mining claim`""
    Add-Line "				``	Buy the frontier mining rights for 700,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining claim deep`""
    Add-Line "						not `"cf: mining claim frontier`""
    Add-Line "						`"cf: reserve`" >= 700000"
    Add-Line "					goto `"confirm buy frontier mining claim`""
    Add-Line "				``	Buy the regional trading license for 180,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading`""
    Add-Line "						not `"cf: trading license regional`""
    Add-Line "						`"cf: reserve`" >= 180000"
    Add-Line "					goto `"confirm buy regional trading license`""
    Add-Line "				``	Buy the long trading license for 400,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading license regional`""
    Add-Line "						not `"cf: trading license long`""
    Add-Line "						`"cf: reserve`" >= 400000"
    Add-Line "					goto `"confirm buy long trading license`""
    Add-Line "				``	Buy the frontier trading license for 750,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading license long`""
    Add-Line "						not `"cf: trading license frontier`""
    Add-Line "						`"cf: reserve`" >= 750000"
    Add-Line "					goto `"confirm buy frontier trading license`""
    Add-Line "				``	Buy the regional security license for 250,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security`""
    Add-Line "						not `"cf: security license regional`""
    Add-Line "						`"cf: reserve`" >= 250000"
    Add-Line "					goto `"confirm buy regional security license`""
    Add-Line "				``	Buy the long security license for 550,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security license regional`""
    Add-Line "						not `"cf: security license long`""
    Add-Line "						`"cf: reserve`" >= 550000"
    Add-Line "					goto `"confirm buy long security license`""
    Add-Line "				``	Buy the frontier security license for 950,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security license long`""
    Add-Line "						not `"cf: security license frontier`""
    Add-Line "						`"cf: reserve`" >= 950000"
    Add-Line "					goto `"confirm buy frontier security license`""
    foreach($route in $shuttleRouteTypes) {
        foreach($ship in $shuttleShipTypes) {
            Add-ShuttleShipChoice $route $ship
        }
        Add-ShuttleVipChoice $route
    }
    foreach($claim in $miningClaimTypes) {
        foreach($ship in $miningShipTypes) {
            Add-MiningShipChoice $claim $ship
        }
    }
    Add-MiningDroneChoice
    foreach($route in $tradingRouteTypes) {
        foreach($ship in $tradingShipTypes) {
            Add-TradingShipChoice $route $ship
        }
        Add-TradingMerchantChoice $route
    }
    foreach($contract in $securityContractTypes) {
        foreach($ship in $securityShipTypes) {
            Add-SecurityShipChoice $contract $ship
        }
    }
    foreach($ship in $securityShipTypes) {
        Add-AdmiralShipChoice $ship
    }
    foreach($share in @(0, 10, 25, 50, 75, 100)) {
        Add-Line "				``	Set owner payout share to $share%.``"
        Add-Line "					to display"
        Add-Line "						has `"cf: active`""
        Add-Line "					goto `"set payout $share`""
    }
    Add-Line "				``	Enable AutoPay for owner payouts. Automatic transfers pay the full amount to you with no deductions.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						not `"cf: autopay`""
    Add-Line "					goto `"enable autopay`""
    Add-Line "				``	Disable AutoPay. Future owner payouts will wait in owner payable until collected manually.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						has `"cf: autopay`""
    Add-Line "						has `"cf: manual autopay controls enabled`""
    Add-Line "					goto `"disable autopay`""
    foreach($amount in @(1000, 5000, 10000, 50000, 250000)) {
        Add-OwnerPayoutChoice $amount
    }
    Add-StationBuildChoices
    foreach($amount in @(1000, 10000, 100000, 1000000, 10000000, 100000000)) {
        Add-QuickInvestChoice $amount
    }
    Add-Line "				``	Close the operating-loss file.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: distress open`""
    Add-Line "						`"cf: reserve`" >= 0"
    Add-Line "					goto `"close distress file`""
    Add-Line "				``	Hire an operations manager for 250,000 credits plus 10,000 credits per day.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: manual`""
    Add-Line "						`"credits`" >= 250000"
    Add-Line "					goto `"hire manager`""
    Add-Line "				``	Dismiss the operations manager and return to owner-managed operations.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: managed`""
    Add-Line "					goto `"dismiss manager`""
    Add-Line "				``	File the report and leave.``"
    Add-Line "					decline"
    Add-Line "			label `"menu ships`""
    Add-Line "			``Company fleet procurement.``"
    Add-Line "			choice"
    foreach($route in $shuttleRouteTypes) {
        foreach($ship in $shuttleShipTypes) {
            Add-ShuttleShipChoice $route $ship
        }
        Add-ShuttleVipChoice $route
    }
    foreach($claim in $miningClaimTypes) {
        foreach($ship in $miningShipTypes) {
            Add-MiningShipChoice $claim $ship
        }
    }
    Add-MiningDroneChoice
    foreach($route in $tradingRouteTypes) {
        foreach($ship in $tradingShipTypes) {
            Add-TradingShipChoice $route $ship
        }
        Add-TradingMerchantChoice $route
    }
    foreach($contract in $securityContractTypes) {
        foreach($ship in $securityShipTypes) {
            Add-SecurityShipChoice $contract $ship
        }
    }
    foreach($ship in $securityShipTypes) {
        Add-AdmiralShipChoice $ship
    }
    Add-Line "				``	Back.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu manager`""
    Add-Line "			``Manager contracts and command staff.``"
    Add-Line "			choice"
    Add-Line "				``	Hire an operations manager for 250,000 credits plus 10,000 credits per day.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: manual`""
    Add-Line "						`"credits`" >= 250000"
    Add-Line "					goto `"confirm hire manager`""
    Add-Line "				``	Dismiss the operations manager and return to owner-managed operations.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: managed`""
    Add-Line "					goto `"confirm dismiss manager`""
    Add-SecurityAdmiralChoice
    Add-Line "				``	Back.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu balance`""
    Add-Line "			action"
    Add-CompanyProjectionActionLines "				"
    Add-CompanyValuationActionLines "				"
    Add-Line "			``Detailed balance: firm value &[credits@cf: company value], reserve &[credits@cf: reserve], AutoPay queue &[credits@cf: owner payable], fleet value &[credits@cf: fleet value], station value &[credits@cf: station value].``"
    Add-Line "			``Daily average: gross &[credits@cf: projected gross], expenses &[credits@cf: projected expenses], net &[credits@cf: projected net], owner payout &[credits@cf: projected owner payout], retained &[credits@cf: projected retained].``"
    Add-Line "			``Lifetime: gross &[credits@cf: total gross], operating expenses &[credits@cf: total operating expenses], manager costs &[credits@cf: total manager costs], taxes &[credits@cf: total tax paid], net profit &[credits@cf: total net profit].``"
    Add-Line "			choice"
    Add-Line "				``	Back.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu hq`""
    Add-Line "			``Headquarters administration and company closure.``"
    Add-Line "			choice"
    Add-Line "				``	Sell the company for &[credits@cf: company value].``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "					goto `"confirm sell company`""
    Add-Line "				``	Close the operating-loss file.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: distress open`""
    Add-Line "						`"cf: reserve`" >= 0"
    Add-Line "					goto `"confirm close distress file`""
    Add-Line "				``	Back.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu stations`""
    Add-Line "			``Station construction.``"
    Add-Line "			choice"
    Add-StationBuildChoices
    Add-Line "				``	Back.``"
    Add-Line "					goto `"company main menu`""
    Add-Line "			label `"menu station sites`""
    Add-Line "			``Choose a human-space system with no landable planet for the company headquarters station.``"
    Add-Line "			choice"
    Add-StationSiteChoices
    Add-Line "				``	Back.``"
    Add-Line "					goto `"menu stations`""
    Add-Line "			label `"menu invest`""
    Add-Line "			``Move money between your personal account and the company reserve.``"
    Add-Line "			choice"
    foreach($amount in @(1000, 10000, 100000, 1000000, 10000000, 100000000)) {
        Add-InvestChoice $amount
    }
    Add-Line "				``	Back.``"
    Add-Line "					goto `"company main menu`""
    Add-ShuttleDivisionMenus
    Add-MiningDivisionMenus
    Add-TradingDivisionMenus
    Add-SecurityDivisionMenus
    Add-CompanyTransactionSummaryLabel -DetailedReturns
    Add-CompanySaleLabels
    Add-ConfirmationLabel "confirm add shuttle division" "add shuttle division" "Add a shuttle division for 650,000 personal credits?" "Add division."
    Add-ConfirmationLabel "confirm add mining division" "add mining division" "Add a mining division for 900,000 personal credits?" "Add division."
    Add-ConfirmationLabel "confirm add trading division" "add trading division" "Add a trading division for 1,250,000 personal credits?" "Add division."
    Add-ConfirmationLabel "confirm add security division" "add security division" "Add a security division for 3,500,000 personal credits?" "Add division."
    Add-Line "			label `"add shuttle division`""
    Add-Line "			action"
    Add-Line "				payment -650000"
    Add-Line "				set `"cf: shuttle`""
    Add-Line "				set `"cf: ship available: Shuttle`""
    Add-Line "				`"cf: reserve`" += 50000"
    Add-Line "				`"cf: fleet value`" += 650000"
    Add-Line "				`"cf: shuttle fleet`" = 1"
    Add-Line "				`"cf: shuttle route count`" = 1"
    Add-Line "				set `"cf: shuttle route local`""
    Add-Line "				`"cf: shuttle local ships`" = 1"
    Add-Line "				`"cf: shuttle local pax`" = 6"
    Add-Line "				`"cf: shuttle local daily crew`" = 100"
    Add-Line "				`"cf: shuttle local trip payout`" = 4200"
    Add-Line "				`"cf: shuttle local trip expenses`" = 400"
    Add-RestartOperationsActions "				"
    Add-Line "			``A shuttle division is added to the company with one Shuttle and one local passenger route.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"add mining division`""
    Add-Line "			action"
    Add-Line "				payment -900000"
    Add-Line "				set `"cf: mining`""
    Add-Line "				set `"cf: ship available: Sunder`""
    Add-Line "				`"cf: reserve`" += 50000"
    Add-Line "				`"cf: fleet value`" += 1000000"
    Add-Line "				`"cf: mining fleet`" = 1"
    Add-Line "				`"cf: mining claim count`" = 1"
    Add-Line "				set `"cf: mining claim local`""
    Add-Line "				`"cf: mining local value`" = 3500"
    Add-Line "				`"cf: mining local ships`" = 1"
    Add-Line "				`"cf: mining local cargo`" = 80"
    Add-Line "				`"cf: mining local daily crew`" = 300"
    Add-Line "				`"cf: mining local trip payout`" = 280000"
    Add-Line "				`"cf: mining local trip expenses`" = 900"
    Add-Line "				`"cf: mining drone capacity`" = 2"
    Add-RestartOperationsActions "				"
    Add-Line "			``A mining division is added to the company with one Sunder and one local claim.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"add trading division`""
    Add-Line "			action"
    Add-Line "				payment -1250000"
    Add-Line "				set `"cf: trading`""
    Add-Line "				set `"cf: ship available: Star Barge`""
    Add-Line "				`"cf: reserve`" += 50000"
    Add-Line "				`"cf: fleet value`" += 1250000"
    Add-Line "				`"cf: trading fleet`" = 1"
    Add-Line "				`"cf: trading route count`" = 1"
    Add-Line "				set `"cf: trading license local`""
    Add-Line "				`"cf: trading local value`" = 450"
    Add-Line "				`"cf: trading local optimized value`" = 650"
    Add-Line "				`"cf: trading local current value`" = 450"
    Add-Line "				`"cf: trading local ships`" = 1"
    Add-Line "				`"cf: trading local cargo`" = 50"
    Add-Line "				`"cf: trading local daily crew`" = 100"
    Add-Line "				`"cf: trading local daily expenses`" = 100"
    Add-Line "				`"cf: trading local trip payout`" = 22500"
    Add-Line "				`"cf: trading local trip expenses`" = 400"
    Add-RestartOperationsActions "				"
    Add-Line "			``A trading division is added to the company with one Star Barge and one local trade license.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"add security division`""
    Add-Line "			action"
    Add-Line "				payment -3500000"
    Add-Line "				set `"cf: security`""
    Add-Line "				set `"cf: ship available: Manta`""
    Add-Line "				`"cf: reserve`" += 100000"
    Add-Line "				`"cf: fleet value`" += 3400000"
    Add-Line "				`"cf: security fleet`" = 1"
    Add-Line "				`"cf: security contract count`" = 1"
    Add-Line "				`"cf: security combat rating`" = 3"
    Add-Line "				set `"cf: security license local`""
    Add-Line "				`"cf: security local rate`" = 1000"
    Add-Line "				`"cf: security local ships`" = 1"
    Add-Line "				`"cf: security local rating`" = 3"
    Add-Line "				`"cf: security local daily crew`" = 600"
    Add-Line "				`"cf: security local trip payout`" = 12000"
    Add-Line "				`"cf: security local trip expenses`" = 2400"
    Add-RestartOperationsActions "				"
    Add-Line "			``A security division is added to the company with one Manta and one local escort license.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy regional route" "buy regional route" "Buy the regional shuttle route for 120,000 company credits?" "Buy license."
    Add-Line "			label `"buy regional route`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 120000"
    Add-Line "				set `"cf: shuttle route regional`""
    Add-Line "				`"cf: shuttle route count`" ++"
    Add-Line "			``Your dispatcher buys a regional passenger contract. It is ready for ships as soon as you assign capacity to it.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy long route" "buy long route" "Buy the long shuttle route for 275,000 company credits?" "Buy license."
    Add-Line "			label `"buy long route`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 275000"
    Add-Line "				set `"cf: shuttle route long`""
    Add-Line "				`"cf: shuttle route count`" ++"
    Add-Line "			``Your dispatcher secures a long passenger corridor. It will pay better, but it needs more berth-days to complete each round trip.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy frontier route" "buy frontier route" "Buy the frontier shuttle route for 475,000 company credits?" "Buy license."
    Add-Line "			label `"buy frontier route`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 475000"
    Add-Line "				set `"cf: shuttle route frontier`""
    Add-Line "				`"cf: shuttle route count`" ++"
    Add-Line "			``Your company signs frontier passenger rights. The route is slower, expensive to open, and finally worth running with larger ships.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy regional mining claim" "buy regional mining claim" "Buy the regional mining rights for 220,000 company credits?" "Buy rights."
    Add-Line "			label `"buy regional mining claim`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 220000"
    Add-Line "				set `"cf: mining claim regional`""
    Add-Line "				`"cf: mining claim count`" ++"
    Add-Line "				`"cf: mining regional value`" = 3500"
    Add-Line "			``Your staff files regional mineral rights. The generic company valuation is 3,500 credits per cargo before fleet efficiency.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy deep mining claim" "buy deep mining claim" "Buy the deep mining rights for 420,000 company credits?" "Buy rights."
    Add-Line "			label `"buy deep mining claim`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 420000"
    Add-Line "				set `"cf: mining claim deep`""
    Add-Line "				`"cf: mining claim count`" ++"
    Add-Line "				`"cf: mining deep value`" = 5000"
    Add-Line "			``Your staff files deep mineral rights. The generic company valuation is 5,000 credits per cargo before fleet efficiency.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy frontier mining claim" "buy frontier mining claim" "Buy the frontier mining rights for 700,000 company credits?" "Buy rights."
    Add-Line "			label `"buy frontier mining claim`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 700000"
    Add-Line "				set `"cf: mining claim frontier`""
    Add-Line "				`"cf: mining claim count`" ++"
    Add-Line "				`"cf: mining frontier value`" = 7000"
    Add-Line "			``Your staff files frontier mineral rights. The generic company valuation is 7,000 credits per cargo before fleet efficiency.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy regional trading license" "buy regional trading license" "Buy the regional trading license for 180,000 company credits?" "Buy license."
    Add-Line "			label `"buy regional trading license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 180000"
    Add-Line "				set `"cf: trading license regional`""
    Add-Line "				`"cf: trading route count`" ++"
    Add-Line "				`"cf: trading regional value`" = 450"
    Add-Line "				`"cf: trading regional optimized value`" = 650"
    Add-Line "				`"cf: trading regional current value`" = 450"
    Add-Line "			``Your office buys a regional trading license. Generic price tables start at 450 credits per cargo, or 650 with a specialist trader.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy long trading license" "buy long trading license" "Buy the long trading license for 400,000 company credits?" "Buy license."
    Add-Line "			label `"buy long trading license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 400000"
    Add-Line "				set `"cf: trading license long`""
    Add-Line "				`"cf: trading route count`" ++"
    Add-Line "				`"cf: trading long value`" = 650"
    Add-Line "				`"cf: trading long optimized value`" = 950"
    Add-Line "				`"cf: trading long current value`" = 650"
    Add-Line "			``Your office buys a long trading license. Generic price tables start at 650 credits per cargo, or 950 with a specialist trader.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy frontier trading license" "buy frontier trading license" "Buy the frontier trading license for 750,000 company credits?" "Buy license."
    Add-Line "			label `"buy frontier trading license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 750000"
    Add-Line "				set `"cf: trading license frontier`""
    Add-Line "				`"cf: trading route count`" ++"
    Add-Line "				`"cf: trading frontier value`" = 850"
    Add-Line "				`"cf: trading frontier optimized value`" = 1250"
    Add-Line "				`"cf: trading frontier current value`" = 850"
    Add-Line "			``Your office buys a frontier trading license. Generic price tables start at 850 credits per cargo, or 1,250 with a specialist trader.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy regional security license" "buy regional security license" "Buy the regional security license for 250,000 company credits?" "Buy license."
    Add-Line "			label `"buy regional security license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 250000"
    Add-Line "				set `"cf: security license regional`""
    Add-Line "				`"cf: security contract count`" ++"
    Add-Line "				`"cf: security regional rate`" = 1500"
    Add-Line "			``Your bureau secures a regional escort license. Empty systems along the way do not need separate paperwork; only the protected endpoint matters.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy long security license" "buy long security license" "Buy the long security license for 550,000 company credits?" "Buy license."
    Add-Line "			label `"buy long security license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 550000"
    Add-Line "				set `"cf: security license long`""
    Add-Line "				`"cf: security contract count`" ++"
    Add-Line "				`"cf: security long rate`" = 2200"
    Add-Line "			``Your bureau secures a long-range escort license. Longer contracts pay more because clients are paying for more exposed flight time.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm buy frontier security license" "buy frontier security license" "Buy the frontier security license for 950,000 company credits?" "Buy license."
    Add-Line "			label `"buy frontier security license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 950000"
    Add-Line "				set `"cf: security license frontier`""
    Add-Line "				`"cf: security contract count`" ++"
    Add-Line "				`"cf: security frontier rate`" = 3000"
    Add-Line "			``Your bureau secures a frontier escort license. These contracts are slow, expensive, and attractive to serious warship fleets.``"
    Add-CompanyOutlookReturn
    foreach($route in $shuttleRouteTypes) {
        foreach($ship in $shuttleShipTypes) {
            Add-ShuttleShipLabel $route $ship
        }
        Add-ShuttleVipLabel $route
    }
    foreach($claim in $miningClaimTypes) {
        foreach($ship in $miningShipTypes) {
            Add-MiningShipLabel $claim $ship -1
        }
    }
    Add-MiningDroneLabel
    foreach($route in $tradingRouteTypes) {
        foreach($ship in $tradingShipTypes) {
            Add-TradingShipLabel $route $ship 0 0
        }
        Add-TradingMerchantLabel $route -1 "the best available spread"
    }
    foreach($contract in $securityContractTypes) {
        foreach($ship in $securityShipTypes) {
            Add-SecurityShipLabel $contract $ship
        }
    }
    Add-SecurityAdmiralLabel
    foreach($ship in $securityShipTypes) {
        Add-AdmiralShipLabel $ship
    }
    foreach($share in @(0, 10, 25, 50, 75, 100)) {
        Add-ConfirmationLabel "confirm set payout $share" "set payout $share" "Set owner payout share to $share%?" "Set payout."
        Add-Line "			label `"set payout $share`""
        Add-Line "			action"
        Add-Line "				`"cf: payout share`" = $share"
        Add-Line "			``The company payout policy is now $share% to you and $((100 - $share))% retained for company growth.``"
        Add-CompanyOutlookReturn
    }
    Add-ConfirmationLabel "confirm enable autopay" "enable autopay" "Enable AutoPay with full direct payout and no deductions?" "Enable AutoPay."
    Add-Line "			label `"enable autopay`""
    Add-Line "			action"
    Add-Line "				set `"cf: autopay`""
    Add-Line "			``AutoPay is now enabled. Future owner-payable balances will be transferred to your account automatically with no tax or transaction deduction.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm disable autopay" "disable autopay" "Disable AutoPay and leave future payouts in owner payable?" "Disable AutoPay."
    Add-Line "			label `"disable autopay`""
    Add-Line "			action"
    Add-Line "				clear `"cf: autopay`""
    Add-Line "			``AutoPay is now disabled. Future owner allocations will accumulate in owner payable until you collect them manually at headquarters.``"
    Add-CompanyOutlookReturn
    foreach($amount in @(1000, 5000, 10000, 50000, 250000)) {
        Add-OwnerPayoutLabel $amount
    }
    Add-StationBuildLabels
    foreach($amount in @(1000, 10000, 100000, 1000000, 10000000, 100000000)) {
        Add-InvestLabel $amount -WithConfirmation
    }
    Add-ConfirmationLabel "confirm close distress file" "close distress file" "Close the current operating-loss file?" "Close file."
    Add-Line "			label `"close distress file`""
    Add-Line "			action"
    Add-Line "				clear `"cf: distress open`""
    Add-Line "			``Your staff marks the operating-loss file as handled.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm hire manager" "hire manager" "Hire an operations manager for 250,000 personal credits plus 10,000 company credits per day?" "Hire manager."
    Add-Line "			label `"hire manager`""
    Add-Line "			action"
    Add-Line "				payment -250000"
    Add-Line "				clear `"cf: manual`""
    Add-Line "				clear `"cf: manual pending`""
    Add-Line "				clear `"cf: manual active`""
    Add-Line "				set `"cf: managed`""
    Add-Line "				set `"cf: manager pending`""
    Add-Line "				`"cf: manager unpaid days`" = 0"
    Add-Line "				`"cf: manager daily cost`" = 0"
    Add-Line "				clear `"cf: manager salary checked`""
    Add-Line "				fail `"Company Foundations: Shuttle Manual Operations`""
    Add-Line "				fail `"Company Foundations: Mining Manual Operations`""
    Add-Line "				fail `"Company Foundations: Trading Manual Operations`""
    Add-Line "				fail `"Company Foundations: Security Manual Operations`""
    Add-ClearOperationsMissionStateActions "				"
    Add-Line "			``You sign the management contract. The manager will cost 10,000 credits per day, follow your payout policy, keep a conservative reserve, and reinvest company funds into appropriate routes, claims, ships, and upgrades when the balance allows it.``"
    Add-CompanyOutlookReturn
    Add-ConfirmationLabel "confirm dismiss manager" "dismiss manager" "Dismiss the operations manager and return to owner-managed operations?" "Dismiss manager."
    Add-Line "			label `"dismiss manager`""
    Add-Line "			action"
    Add-Line "				`"cf: manager unpaid days`" = 0"
    Add-Line "				`"cf: manager daily cost`" = 0"
    Add-Line "				clear `"cf: manager salary checked`""
    Add-Line "				clear `"cf: manager active`""
    Add-Line "				clear `"cf: manager pending`""
    Add-Line "				clear `"cf: managed`""
    Add-Line "				set `"cf: manual`""
    Add-Line "				set `"cf: manual pending`""
    Add-Line "				fail `"Company Foundations: Shuttle Managed Operations`""
    Add-Line "				fail `"Company Foundations: Mining Managed Operations`""
    Add-Line "				fail `"Company Foundations: Trading Managed Operations`""
    Add-Line "				fail `"Company Foundations: Security Managed Operations`""
    Add-ClearOperationsMissionStateActions "				"
    Add-Line "			``You dismiss the operations manager. The company returns to owner-managed operations; no further 10,000 credit manager salary will be charged.``"
    Add-CompanyOutlookReturn
    Add-Line ""
}

Add-Line "# Company Foundations"
Add-Line "# Built from Endless Sky map planet data for normal fresh pilots."
Add-Line "# Eligible headquarters: $($eligible.Count) accessible visitable spaceports."
Add-Line ""

Set-OutputSection "company stations.txt"
Add-Line "government `"$companyGovernmentName`""
Add-Line "	`"display name`" `"Your Company`""
Add-Line "	`"player reputation`" 1000"
Add-Line "	`"default attitude`" 1"
Add-Line "	`"friendly hail`" `"friendly civilian`""
Add-Line "	`"friendly disabled hail`" `"friendly disabled`""
Add-Line "	`"penalty for`""
Add-Line "		assist 0"
Add-Line "		disable 0"
Add-Line "		board 0"
Add-Line "		capture 0"
Add-Line "		destroy 0"
Add-Line "		atrocity 0"
Add-Line ""
Add-Line "outfitter `"$companyStationOutfitterName`""
foreach($outfit in @(
    "Hyperdrive",
    "Ramscoop",
    "Fuel Pod",
    "Cargo Expansion",
    "Bunk Room",
    "LP036a Battery Pack",
    "Cooling Ducts",
    "Laser Rifle",
    "Local Map"
)) {
    Add-Line "	`"$outfit`""
}
Add-Line ""
Add-Line "shipyard `"$companyStationShipyardName`""
foreach($ship in @(
    "Shuttle",
    "Heavy Shuttle",
    "Star Barge",
    "Freighter",
    "Scout",
    "Sparrow",
    "Sunder",
    "Mining Drone"
)) {
    Add-Line "	`"$ship`""
}
Add-Line ""
foreach($system in $companyStationSystems) {
    $systemName = $system.Name
    $systemToken = Format-ESToken $systemName
    $stationToken = Format-ESToken $companyStationPlanetName
    $orbitDistance = 260 + (($systemName.Length * 17) % 180)
    $orbitPeriod = 70 + (($systemName.Length * 11) % 80)

    Add-Line "event `"Company Foundations: Station Site: $systemName`""
    Add-Line "	system $systemToken"
    Add-Line "		object $stationToken"
    Add-Line "			sprite planet/station5"
    Add-Line "			distance $orbitDistance"
    Add-Line "			period $orbitPeriod"
    Add-Line "	planet $stationToken"
    Add-Line "		government `"$companyGovernmentName`""
    Add-Line "		attributes `"cf station`" `"cf company hq`" spaceport"
    Add-Line "		landscape land/space4"
    Add-Line "		description ``This compact corporate station is the registered headquarters of your company. Its first ring contains administration offices, traffic control, crew services, reserve storage, and enough docking arms to support a growing private operation.``"
    Add-Line "		spaceport ``The station concourse is still new enough that the walls look unfinished in places. Company clerks, independent contractors, and shuttle crews move between temporary counters and sealed work bays while your name sits above the central operations terminal.``"
    Add-Line ""
}
Add-Line "event `"Company Foundations: Station Stage 2 Outfitter`""
Add-Line "	planet `"$companyStationPlanetName`""
Add-Line "		outfitter `"$companyStationOutfitterName`""
Add-Line ""
Add-Line "event `"Company Foundations: Station Stage 3 Shipyard`""
Add-Line "	planet `"$companyStationPlanetName`""
Add-Line "		shipyard `"$companyStationShipyardName`""
Add-Line ""

Set-OutputSection "company discovery.txt"
foreach($planet in @($planets | Where-Object { $_.HasSpaceport -and $systemsByPlanet.ContainsKey($_.Name) } | Sort-Object Name)) {
    $planetToken = Format-ESToken $planet.Name
    $missionName = Format-ESMissionName "Company Foundations: Discover Port: $($planet.Name)"
    Add-Line "mission $missionName"
    Add-Line "	name `"Company Port Discovery`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-ConditionLine "not" (Get-KnownPlanetCondition $planet.Name) "		"
    Add-Line "	on offer"
    Add-PlanetDiscoveryActions $planet "		"
    Add-Line ""
}

Set-OutputSection "company core.txt"
foreach($starter in @(
    [pscustomobject]@{ Type = "cf: shuttle"; Ship = "Shuttle" },
    [pscustomobject]@{ Type = "cf: mining"; Ship = "Sunder" },
    [pscustomobject]@{ Type = "cf: trading"; Ship = "Star Barge" },
    [pscustomobject]@{ Type = "cf: security"; Ship = "Manta" }
)) {
    $starterMission = Format-ESMissionName "Company Foundations: Starter Supplier Backfill: $($starter.Ship)"
    Add-Line "mission $starterMission"
    Add-Line "	name `"Company Starter Supplier Backfill`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		has `"$($starter.Type)`""
    Add-Line "		not `"$(Get-ShipAvailableCondition $starter.Ship)`""
    Add-Line "	on offer"
    Add-Line "		set `"$(Get-ShipAvailableCondition $starter.Ship)`""
    Add-Line "		log `"Company Foundations`" `"Procurement Backfill`" ``The company records its starter $($starter.Ship) procurement channel as an available supplier for future simulated purchases.``"
    Add-Line ""
}

Set-OutputSection "company founding.txt"
foreach($planet in $eligible) {
    $name = $planet.Name
    $hqGovernment = Get-PlanetGovernmentName $planet
    $hqRequiredReputation = [int]$planet.RequiredReputation
    $hqDailyTax = Get-HQTaxRate $planet
    $routeLocal = Find-RouteTarget $name 1
    $miningLocal = Find-MiningClaimTarget $name 0
    $miningLocalTripPayout = 80 * $miningLocal.ValuePerCargo
    $miningLocalTripExpenses = 300 * 3
    $tradingLocal = Find-TradeRouteTarget $name 1
    $tradingLocalTripPayout = 50 * $tradingLocal.BaseValue
    $tradingLocalTripExpenses = 100 * 4
    $planetToken = Format-ESToken $name
    $missionName = Format-ESMissionName "Company Foundations: Registrar: $name"
    $hqCondition = Format-ESMissionName "cf: hq: $name"

    Add-Line "mission $missionName"
    Add-Line "	name `"Found Company`""
    Add-Line "	description `"Found a small company headquartered on $name. The cheapest charter costs 650,000 credits.`""
    Add-Line "	minor"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		not `"cf: active`""
    Add-ReputationRequirement $hqGovernment $hqRequiredReputation "		"
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			``A local registrar offers compact company charters for independent captains with enough capital to move beyond one ship. The headquarters would be registered here on $name, and the initial staff would work out of rented port offices.``"
    Add-Line "			``	The cheapest charter is a shuttle company for 650,000 credits. Your account is not ready for registration yet, but the clerk can still explain the paperwork.``"
    Add-Line "				to display"
    Add-Line "					`"credits`" < 650000"
    Add-Line "			choice"
    Add-Line "				``	Found a shuttle company for 650,000 credits.``"
    Add-Line "					to display"
    Add-Line "						`"credits`" >= 650000"
    Add-Line "					goto `"found shuttle`""
    Add-Line "				``	Found a mining company for 900,000 credits.``"
    Add-Line "					to display"
    Add-Line "						`"credits`" >= 900000"
    Add-Line "					goto `"found mining`""
    Add-Line "				``	Found a trading company for 1.25M credits.``"
    Add-Line "					to display"
    Add-Line "						`"credits`" >= 1250000"
    Add-Line "					goto `"found trading`""
    Add-Line "				``	Found a security company for 3.5M credits.``"
    Add-Line "					to display"
    Add-Line "						`"credits`" >= 3500000"
    Add-Line "						`"combat rating`" >= 50"
    Add-Line "					goto `"found security`""
    Add-Line "				``	Leave the paperwork for another day.``"
    Add-Line "					decline"
    Add-Line "			label `"found shuttle`""
    Add-Line "			action"
    Add-Line "				payment -650000"
    Add-Line "				set `"cf: active`""
    Add-Line "				set `"cf: autopay`""
    Add-Line "				set `"cf: tax model v2`""
    Add-Line "				set `"cf: shuttle`""
    Add-Line "				set `"cf: ship available: Shuttle`""
    Add-Line "				set `"cf: manual`""
    Add-Line "				set `"cf: manual pending`""
    Add-Line "				set $hqCondition"
    Add-Line "				set `"cf: at hq`""
    Add-PlanetDiscoveryActions $planet "				"
    Add-Line "				`"cf: hq base tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq daily tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq required reputation`" = $hqRequiredReputation"
    Add-Line "				`"cf: next report day`" = 30"
    Add-Line "				`"cf: fleet value`" = 650000"
    Add-Line "				`"cf: reserve`" = 50000"
    Add-Line "				`"cf: payout share`" = 25"
    Add-Line "				`"cf: shuttle fleet`" = 1"
    Add-Line "				`"cf: shuttle route count`" = 1"
    Add-Line "				set `"cf: shuttle route local`""
    Add-Line "				`"cf: shuttle local ships`" = 1"
    Add-Line "				`"cf: shuttle local pax`" = 6"
    Add-Line "				`"cf: shuttle local daily crew`" = 100"
    Add-Line "				`"cf: shuttle local trip payout`" = 4200"
    Add-Line "				`"cf: shuttle local trip expenses`" = 400"
    Add-Line "				log `"Company Foundations`" `"$name Shuttle Company`" ``Founded a shuttle company headquartered on $name. Startup capital, berth leases, scheduling systems, crew contracts, one Shuttle, and the first passenger route to $($routeLocal.Planet) cost 650,000 credits.``"
    Add-Line "			``The registrar stamps the charter and connects your dispatcher to the passenger boards. The first route is $name to $($routeLocal.Planet) in $($routeLocal.Distance) jump(s), worked by one Shuttle with 6 passenger berths.``"
    Add-Line "				decline"
    Add-Line "			label `"found mining`""
    Add-Line "			action"
    Add-Line "				payment -900000"
    Add-Line "				set `"cf: active`""
    Add-Line "				set `"cf: autopay`""
    Add-Line "				set `"cf: tax model v2`""
    Add-Line "				set `"cf: mining`""
    Add-Line "				set `"cf: ship available: Sunder`""
    Add-Line "				set `"cf: manual`""
    Add-Line "				set `"cf: manual pending`""
    Add-Line "				set $hqCondition"
    Add-Line "				set `"cf: at hq`""
    Add-PlanetDiscoveryActions $planet "				"
    Add-Line "				`"cf: hq base tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq daily tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq required reputation`" = $hqRequiredReputation"
    Add-Line "				`"cf: next report day`" = 30"
    Add-Line "				`"cf: fleet value`" = 1000000"
    Add-Line "				`"cf: reserve`" = 50000"
    Add-Line "				`"cf: payout share`" = 25"
    Add-Line "				`"cf: mining fleet`" = 1"
    Add-Line "				`"cf: mining claim count`" = 1"
    Add-Line "				set `"cf: mining claim local`""
    Add-Line "				`"cf: mining local value`" = $($miningLocal.ValuePerCargo)"
    Add-Line "				`"cf: mining local ships`" = 1"
    Add-Line "				`"cf: mining local cargo`" = 80"
    Add-Line "				`"cf: mining local daily crew`" = 300"
    Add-Line "				`"cf: mining local trip payout`" = $miningLocalTripPayout"
    Add-Line "				`"cf: mining local trip expenses`" = $miningLocalTripExpenses"
    Add-Line "				`"cf: mining drone capacity`" = 2"
    Add-Line "				log `"Company Foundations`" `"$name Mining Company`" ``Founded a mining company headquartered on $name. Startup capital, a used Sunder, local mineral rights in $($miningLocal.System), basic equipment, and crew contracts cost 900,000 credits.``"
    Add-Line "			``The registrar stamps the charter and records your first mining claim in $($miningLocal.System), a $($miningLocal.Summary) $($miningLocal.Distance) jump(s) from headquarters. One Sunder will run the claim with 80 cargo throughput and room for two Mining Drones.``"
    Add-Line "				decline"
    Add-Line "			label `"found trading`""
    Add-Line "			action"
    Add-Line "				payment -1250000"
    Add-Line "				set `"cf: active`""
    Add-Line "				set `"cf: autopay`""
    Add-Line "				set `"cf: tax model v2`""
    Add-Line "				set `"cf: trading`""
    Add-Line "				set `"cf: ship available: Star Barge`""
    Add-Line "				set `"cf: manual`""
    Add-Line "				set `"cf: manual pending`""
    Add-Line "				set $hqCondition"
    Add-Line "				set `"cf: at hq`""
    Add-PlanetDiscoveryActions $planet "				"
    Add-Line "				`"cf: hq base tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq daily tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq required reputation`" = $hqRequiredReputation"
    Add-Line "				`"cf: next report day`" = 30"
    Add-Line "				`"cf: fleet value`" = 1250000"
    Add-Line "				`"cf: reserve`" = 50000"
    Add-Line "				`"cf: payout share`" = 25"
    Add-Line "				`"cf: trading fleet`" = 1"
    Add-Line "				`"cf: trading route count`" = 1"
    Add-Line "				set `"cf: trading license local`""
    Add-Line "				`"cf: trading local value`" = $($tradingLocal.BaseValue)"
    Add-Line "				`"cf: trading local optimized value`" = $($tradingLocal.OptimizedValue)"
    Add-Line "				`"cf: trading local current value`" = $($tradingLocal.BaseValue)"
    Add-Line "				`"cf: trading local ships`" = 1"
    Add-Line "				`"cf: trading local cargo`" = 50"
    Add-Line "				`"cf: trading local daily crew`" = 100"
    Add-Line "				`"cf: trading local daily expenses`" = 100"
    Add-Line "				`"cf: trading local trip payout`" = $tradingLocalTripPayout"
    Add-Line "				`"cf: trading local trip expenses`" = $tradingLocalTripExpenses"
    Add-Line "				log `"Company Foundations`" `"$name Trading Company`" ``Founded a trading company headquartered on $name. Startup capital, dock contracts, cargo insurance, one Star Barge, and the first trade license to $($tradingLocal.Planet) cost 1.25M credits.``"
    Add-Line "			``The registrar stamps the charter and records your first trade license from $name to $($tradingLocal.Planet). Your Star Barge will run general cargo while the route office tracks $($tradingLocal.Commodity) as the strongest known spread.``"
    Add-Line "				decline"
    Add-Line "			label `"found security`""
    Add-Line "			action"
    Add-Line "				payment -3500000"
    Add-Line "				set `"cf: active`""
    Add-Line "				set `"cf: autopay`""
    Add-Line "				set `"cf: tax model v2`""
    Add-Line "				set `"cf: security`""
    Add-Line "				set `"cf: ship available: Manta`""
    Add-Line "				set `"cf: manual`""
    Add-Line "				set `"cf: manual pending`""
    Add-Line "				set $hqCondition"
    Add-Line "				set `"cf: at hq`""
    Add-PlanetDiscoveryActions $planet "				"
    Add-Line "				`"cf: hq base tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq daily tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq required reputation`" = $hqRequiredReputation"
    Add-Line "				`"cf: next report day`" = 30"
    Add-Line "				`"cf: fleet value`" = 3400000"
    Add-Line "				`"cf: reserve`" = 100000"
    Add-Line "				`"cf: payout share`" = 25"
    Add-Line "				`"cf: security fleet`" = 1"
    Add-Line "				`"cf: security contract count`" = 1"
    Add-Line "				`"cf: security combat rating`" = 3"
    Add-Line "				set `"cf: security license local`""
    Add-Line "				`"cf: security local rate`" = 1000"
    Add-Line "				`"cf: security local ships`" = 1"
    Add-Line "				`"cf: security local rating`" = 3"
    Add-Line "				`"cf: security local daily crew`" = 600"
    Add-Line "				`"cf: security local trip payout`" = 12000"
    Add-Line "				`"cf: security local trip expenses`" = 2400"
    Add-Line "				log `"Company Foundations`" `"$name Security Company`" ``Founded a security company headquartered on $name. Startup capital, weapons permits, liability coverage, one Manta, and the first escort license to $($routeLocal.Planet) cost 3.5M credits.``"
    Add-Line "			``The registrar stamps the charter after one last look at your combat record. The first security license covers escort work from $name to $($routeLocal.Planet), and your Manta is strong enough for medium-risk protection contracts without starting as a tiny interceptor.``"
    Add-Line "				decline"
    Add-Line ""
}

Set-OutputSection "company admiral locations.txt"
foreach($planet in $eligible) {
    $name = $planet.Name
    $planetToken = Format-ESToken $name
    $admiralLocationCondition = Format-ESMissionName "cf: admiral location: $name"
    $admiralDestinationCondition = Format-ESMissionName "cf: admiral destination: $name"

    $admiralStatusName = Format-ESMissionName "Company Foundations: Admiral Fleet Status: $name"
    Add-Line "mission $admiralStatusName"
    Add-Line "	name `"Admiral Fleet Status`""
    Add-Line "	description `"Review the fleet admiral's current strike fleet position at $name.`""
    Add-Line "	minor"
    Add-Line "	repeat"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		has `"cf: security admiral`""
    Add-Line "		has $admiralLocationCondition"
    Add-Line "		`"cf: admiral travel days`" == 0"
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			``The fleet admiral's strike fleet is currently operating out of the $name system. Headquarters remains wherever your company is based; this is only the fleet's current physical deployment point.``"
    Add-Line "			``	Strike ships: &[number@cf: admiral fleet]. Fleet rating: &[number@cf: admiral rating]. Daily admiral salary: 20,000 credits. Fleet crew costs: &[credits@cf: admiral daily crew]/day.``"
    Add-Line "			choice"
    Add-Line "				``	File the command report.``"
    Add-Line "					decline"
    Add-Line ""

    $admiralHireName = Format-ESMissionName "Company Foundations: Hire Fleet Admiral: $name"
    Add-Line "mission $admiralHireName"
    Add-Line "	name `"Hire Fleet Admiral`""
    Add-Line "	description `"Hire a fleet admiral at the company headquarters on $name.`""
    Add-Line "	minor"
    Add-Line "	repeat"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		has `"cf: security`""
    Add-Line "		has `"cf: hq: $name`""
    Add-Line "		not `"cf: security admiral`""
    Add-Line "		`"cf: reserve`" >= 300000"
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			``A retired fleet officer is available to establish an independent strike command from your headquarters on $name. The office contract costs 300,000 company credits, and the admiral salary is 20,000 credits per day before owner payout.``"
    Add-Line "			choice"
    Add-Line "				``	Hire the fleet admiral.``"
    Add-Line "					goto `"confirm hire security admiral`""
    Add-Line "				``	Leave the command contract unsigned.``"
    Add-Line "					decline"
    Add-ConfirmationLabel "confirm hire security admiral" "hire security admiral" "Hire a fleet admiral for 300,000 company credits plus 20,000 credits per day?" "Hire admiral." "cancel hire security admiral"
    Add-Line "			label `"cancel hire security admiral`""
    Add-Line "				decline"
    Add-Line "			label `"hire security admiral`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 300000"
    Add-Line "				set `"cf: security admiral`""
    Add-ClearAllAdmiralLocationConditions "				"
    Add-ClearAllAdmiralDestinationConditions "				"
    Add-ConditionLine "set" "cf: admiral location: $name" "				"
    Add-Line "				clear `"cf: admiral in transit`""
    Add-Line "				`"cf: admiral travel days`" = 0"
    Add-Line "			``The fleet admiral signs on and establishes the strike fleet's starting location at $name. Escort-route ships still do not count toward admiral fleet rating.``"
    Add-Line "				decline"
    Add-Line ""

    $admiralRelocationName = Format-ESMissionName "Company Foundations: Deploy Admiral Fleet: $name"
    Add-Line "mission $admiralRelocationName"
    Add-Line "	name `"Relocate Admiral Fleet`""
    Add-Line "	description `"Order the fleet admiral's strike fleet to deploy to $name for 200,000 company credits.`""
    Add-Line "	minor"
    Add-Line "	repeat"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		has `"cf: security admiral`""
    Add-Line "		not $admiralLocationCondition"
    Add-Line "		not $admiralDestinationCondition"
    Add-Line "		not `"cf: admiral in transit`""
    Add-Line "		`"cf: admiral travel days`" == 0"
    Add-Line "		`"cf: reserve`" >= 200000"
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			``You can order the fleet admiral to move the independent strike fleet to $name. The headquarters office stays where it is; the ships, crews, ammunition stores, and command traffic need five operating days to reach the new deployment point. Until arrival, the old location remains the fleet's last confirmed position.``"
    Add-Line "			choice"
    Add-Line "				``	Deploy the admiral fleet here for 200,000 company credits.``"
    Add-Line "					goto `"deploy admiral fleet`""
    Add-Line "				``	Leave the admiral where they are.``"
    Add-Line "					decline"
    Add-Line "			label `"deploy admiral fleet`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 200000"
    Add-Line "				`"cf: admiral relocation count`" ++"
    Add-Line "				`"cf: total admiral relocation costs`" += 200000"
    Add-ClearAllAdmiralDestinationConditions "				"
    Add-ConditionLine "set" "cf: admiral destination: $name" "				"
    Add-Line "				set `"cf: admiral in transit`""
    Add-Line "				`"cf: admiral travel days`" = 5"
    Add-Line "			``The admiral confirms the deployment order. The strike fleet does not count as present at $name until the transit timer has finished.``"
    Add-Line "				decline"
    Add-Line ""

    $admiralArrivalName = Format-ESMissionName "Company Foundations: Admiral Fleet Arrival: $name"
    Add-Line "mission $admiralArrivalName"
    Add-Line "	name `"Admiral Fleet Arrived`""
    Add-Line "	description `"Finalize the fleet admiral's arrival at $name.`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: security admiral`""
    Add-Line "		has $admiralDestinationCondition"
    Add-Line "		`"cf: admiral travel days`" == 0"
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			action"
    Add-ClearAllAdmiralLocationConditions "				"
    Add-ClearAllAdmiralDestinationConditions "				"
    Add-ConditionLine "set" "cf: admiral location: $name" "				"
    Add-Line "				clear `"cf: admiral in transit`""
    Add-Line "				log `"Company Foundations`" `"Admiral Fleet`" ``The fleet admiral's strike fleet arrived at $name and is now available for local operations.``"
    Add-Line "			``Your fleet admiral reports arrival at $name. The independent strike fleet is now operating from that deployment point.``"
    Add-Line "				accept"
    Add-Line ""
}

Set-OutputSection "company hq.txt"
Add-GenericCompanyBoardMission
Set-OutputSection "company hq presence.txt"
$stationAtHqName = Format-ESMissionName "Company Foundations: Mark At Headquarters: $companyStationPlanetName"
Add-Line "mission $stationAtHqName"
Add-Line "	name `"At Company Headquarters`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	source `"$companyStationPlanetName`""
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		has `"cf: hq station built`""
Add-Line "		not `"cf: at hq`""
Add-Line "	on offer"
Add-Line "		set `"cf: at hq`""
Add-Line "		`"reputation: $companyGovernmentName`" >?= 1000"
Add-Line ""
foreach($planet in $eligible) {
    $name = $planet.Name
    $planetToken = Format-ESToken $name
    $hqCondition = Format-ESMissionName "cf: hq: $name"
    $atHqName = Format-ESMissionName "Company Foundations: Mark At Headquarters: $name"

    Add-Line "mission $atHqName"
    Add-Line "	name `"At Company Headquarters`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		not `"cf: hq station built`""
    Add-Line "		has $hqCondition"
    Add-Line "		not `"cf: at hq`""
    Add-Line "	on offer"
    Add-Line "		set `"cf: at hq`""
    Add-Line ""
}

foreach($planet in @($planets | Where-Object { $_.HasSpaceport -and $systemsByPlanet.ContainsKey($_.Name) } | Sort-Object Name)) {
    $name = $planet.Name
    $planetToken = Format-ESToken $name
    $hqCondition = Format-ESMissionName "cf: hq: $name"
    $awayName = Format-ESMissionName "Company Foundations: Mark Away From Headquarters: $name"

    Add-Line "mission $awayName"
    Add-Line "	name `"Away From Company Headquarters`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		not $hqCondition"
    Add-Line "		has `"cf: at hq`""
    Add-Line "	on offer"
    Add-Line "		clear `"cf: at hq`""
    Add-Line ""
}
Set-OutputSection "__discard"
foreach($planet in $eligible) {
    Set-OutputSection "__discard"
    $name = $planet.Name
    $hqGovernment = Get-PlanetGovernmentName $planet
    $hqRequiredReputation = [int]$planet.RequiredReputation
    $hqDailyTax = Get-HQTaxRate $planet
    $routeLocal = Find-RouteTarget $name 1
    $routeRegional = Find-RouteTarget $name 2
    $routeLong = Find-RouteTarget $name 3
    $routeFrontier = Find-RouteTarget $name 4
    $tradingLocal = Find-TradeRouteTarget $name 1
    $tradingRegional = Find-TradeRouteTarget $name 2
    $tradingLong = Find-TradeRouteTarget $name 3
    $tradingFrontier = Find-TradeRouteTarget $name 4
    $tradingTargets = @{
        local = $tradingLocal
        regional = $tradingRegional
        long = $tradingLong
        frontier = $tradingFrontier
    }
    $admiralTargets = Get-PirateTributeTargets $name
    $miningLocal = Find-MiningClaimTarget $name 0
    $miningRegional = Find-MiningClaimTarget $name 1 @($miningLocal.System)
    $miningDeep = Find-MiningClaimTarget $name 2 @($miningLocal.System, $miningRegional.System)
    $miningFrontier = Find-MiningClaimTarget $name 3 @($miningLocal.System, $miningRegional.System, $miningDeep.System)
    $miningTargets = @{
        local = $miningLocal
        regional = $miningRegional
        deep = $miningDeep
        frontier = $miningFrontier
    }
    $planetToken = Format-ESToken $name
    $missionName = Format-ESMissionName "Company Foundations: Headquarters: $name"
    $hqCondition = Format-ESMissionName "cf: hq: $name"

    Add-Line "mission $missionName"
    Add-Line "	name `"Company Headquarters`""
    Add-Line "	description `"Review the company headquartered on $name and change how it is managed.`""
    Add-Line "	repeat"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		has $hqCondition"
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			label `"company main menu`""
    Add-Line "			``Your company office on $name is still more rented rooms and filed contracts than corporate tower, but the clerk has your balance board ready.``"
    Add-Line "			``	BALANCE BOARD - SUMMARY``"
    Add-Line "			``	HQ: $name, $hqGovernment jurisdiction. Required local reputation: $hqRequiredReputation. Daily local tax: &[credits@cf: hq daily tax].``"
    Add-Line "			``	Cash: company reserve &[credits@cf: reserve], owner payable &[credits@cf: owner payable], lifetime owner cash received &[credits@cf: total owner payouts].``"
    Add-Line "			``	Last period: gross &[credits@cf: last gross], expenses &[credits@cf: last expenses], net &[credits@cf: last net profit], owner allocation &[credits@cf: last owner payout], retained &[credits@cf: last retained earnings].``"
    Add-Line "			``	Policy: payout share &[number@cf: payout share]%. AutoPay is off; owner allocations stay in owner payable until collected manually.``"
    Add-Line "				to display"
    Add-Line "					not `"cf: autopay`""
    Add-Line "			``	Policy: payout share &[number@cf: payout share]%. AutoPay is on; owner allocations are transferred automatically at 90% net after a 10% transaction fee.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: autopay`""
    Add-Line "			``	Staff and taxes: &[number@cf: worker staff] workers, &[number@cf: office staff] office staff, &[number@cf: specialist staff] specialist(s), &[number@cf: total staff] total. Office payroll &[credits@cf: office daily cost]/day, employee tax &[credits@cf: employee tax]/day.``"
    Add-Line "			``	Management: owner-managed. You keep direct control, but expansion only happens when you personally fund it.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: manual`""
    Add-Line "			``	Management: manager-run. Manager salary is 10,000 credits/day before owner payout; retained reserve may be reinvested when it is at least double the investment cost. If salary cannot be covered for two checked operating days in a row, the manager resigns.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: managed`""
    Add-Line "			``	Manager salary warning: &[number@cf: manager unpaid days] unpaid checked day(s) in the current streak. At 2, the manager will quit.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: managed`""
    Add-Line "					`"cf: manager unpaid days`" > 0"
    Add-Line "			``	OPERATIONS``"
    Add-Line "			``	Shuttle network: &[number@cf: shuttle route count] route(s), &[number@cf: shuttle fleet] simulated ship(s), completed route revenue &[credits@cf: shuttle route revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: shuttle`""
    Add-Line "			``	Mining operation: &[number@cf: mining claim count] claim(s), &[number@cf: mining fleet] simulated ship(s), &[number@cf: mining drones]/&[number@cf: mining drone capacity] Mining Drones, extraction bonus &[number@cf: mining efficiency bonus]%. Completed ore revenue: &[credits@cf: mining revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: mining`""
    Add-Line "			``	Trading network: &[number@cf: trading route count] license(s), &[number@cf: trading fleet] simulated ship(s), completed trade revenue &[credits@cf: trading revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: trading`""
    Add-Line "			``	Security bureau: &[number@cf: security contract count] escort license(s), &[number@cf: security fleet] simulated escort ship(s), escort rating &[number@cf: security combat rating], escort revenue &[credits@cf: security contract revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security`""
    Add-Line "			``	Admiral command: &[number@cf: admiral fleet] strike ship(s), fleet rating &[number@cf: admiral rating], tribute contracts &[number@cf: admiral tribute count], daily tribute &[credits@cf: admiral tribute income], lifetime tribute &[credits@cf: admiral tribute revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security admiral`""
    Add-Line "			``	Admiral fleet location: currently operating in this headquarters system.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security admiral`""
    Add-Line "					has `"cf: admiral location: $name`""
    Add-Line "			``	Admiral fleet location: deployed away from this headquarters. Visit the desired deployment point to order the strike fleet there, or wait for any active transit to finish.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security admiral`""
    Add-Line "					not `"cf: admiral location: $name`""
    Add-Line "			``	Admiral transit: &[number@cf: admiral travel days] day(s) until the strike fleet reaches its ordered destination.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security admiral`""
    Add-Line "					`"cf: admiral travel days`" > 0"
    Add-Line "			``	Company stations: &[number@cf: station count] orbital asset(s), station value &[credits@cf: station value], daily station income &[credits@cf: station daily income], upkeep &[credits@cf: station daily upkeep], lifetime station revenue &[credits@cf: total station revenue].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: station orbital office`""
    Add-Line "			``	Fleet admiral retained: independent pirate-tribute command costs 20,000 credits per day before owner payout, plus crew costs for admiral fleet ships.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: security admiral`""
    Add-Line "			``	AUTOPAY``"
    Add-Line "				to display"
    Add-Line "					has `"cf: autopay`""
    Add-Line "			``	Automatic transfers: gross &[credits@cf: autopay gross transfers], net received &[credits@cf: autopay net transfers], transaction fees &[credits@cf: autopay fees], transfer batches &[number@cf: autopay transfers].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: autopay`""
    Add-Line "			``	Open issue: the company has reported an operating loss. Stabilize the reserve, then close the distress file here.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: distress open`""
    Add-Line "			``	HISTORY``"
    Add-Line "			``	HQ history: relocations &[number@cf: hq relocation count], relocation costs &[credits@cf: total relocation costs], access suspensions &[number@cf: hq suspension count].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: active`""
    Add-Line "			``	Lifetime: gross &[credits@cf: total gross], operating expenses &[credits@cf: total operating expenses], manager costs &[credits@cf: total manager costs], taxes &[credits@cf: total tax paid], net profit &[credits@cf: total net profit], owner allocations &[credits@cf: total owner allocations], retained earnings &[credits@cf: total retained earnings].``"
    Add-Line "				to display"
    Add-Line "					has `"cf: active`""
    Add-Line "			``	ROUTES, CLAIMS, LICENSES, AND TARGETS``"
    Add-Line "			``	Local route: $name to $($routeLocal.Planet), cycle 4 ship-days, 700 credits per passenger, ships &[number@cf: shuttle local ships], berths &[number@cf: shuttle local pax]/48, average trip payout &[credits@cf: shuttle local trip payout], VIP &[number@cf: shuttle local vip]/1.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: shuttle`""
    Add-Line "			``	Regional route: $name to $($routeRegional.Planet), cycle 6 ship-days, 1,400 credits per passenger, ships &[number@cf: shuttle regional ships], berths &[number@cf: shuttle regional pax]/80, average trip payout &[credits@cf: shuttle regional trip payout], VIP &[number@cf: shuttle regional vip]/1.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: shuttle route regional`""
    Add-Line "			``	Long route: $name to $($routeLong.Planet), cycle 8 ship-days, 2,100 credits per passenger, ships &[number@cf: shuttle long ships], berths &[number@cf: shuttle long pax]/140, average trip payout &[credits@cf: shuttle long trip payout], VIP &[number@cf: shuttle long vip]/1.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: shuttle route long`""
    Add-Line "			``	Frontier route: $name to $($routeFrontier.Planet), cycle 10 ship-days, 2,800 credits per passenger, ships &[number@cf: shuttle frontier ships], berths &[number@cf: shuttle frontier pax]/220, average trip payout &[credits@cf: shuttle frontier trip payout], VIP &[number@cf: shuttle frontier vip]/1.``"
    Add-Line "				to display"
    Add-Line "					has `"cf: shuttle route frontier`""
    foreach($claim in $miningClaimTypes) {
        $target = $miningTargets[$claim.Prefix]
        Add-Line "			``	$($claim.Name.Substring(0,1).ToUpper() + $claim.Name.Substring(1)) mining claim: $($target.System), $($target.Distance) jump(s), $($target.Summary), value &[credits@cf: mining $($claim.Prefix) value]/cargo, cycle $($claim.Threshold) ship-days, ships &[number@cf: mining $($claim.Prefix) ships], cargo &[number@cf: mining $($claim.Prefix) cargo]/$($claim.CargoCap), average trip payout &[credits@cf: mining $($claim.Prefix) trip payout].``"
        Add-Line "				to display"
        Add-Line "					has `"$($claim.Required)`""
    }
    foreach($route in $tradingRouteTypes) {
        $target = $tradingTargets[$route.Prefix]
        Add-Line "			``	$($route.Name.Substring(0,1).ToUpper() + $route.Name.Substring(1)) trade route: $name to $($target.Planet), $($target.Distance) jump(s), best spread $($target.Commodity), value &[credits@cf: trading $($route.Prefix) value]/cargo or &[credits@cf: trading $($route.Prefix) optimized value] with trader, cycle $($route.Threshold) ship-days, ships &[number@cf: trading $($route.Prefix) ships], cargo &[number@cf: trading $($route.Prefix) cargo]/$($route.CargoCap), trader &[number@cf: trading $($route.Prefix) trader]/1.``"
        Add-Line "				to display"
        Add-Line "					has `"$($route.Required)`""
    }
    foreach($contract in $securityContractTypes) {
        $target = switch($contract.Prefix) {
            "local" { $routeLocal }
            "regional" { $routeRegional }
            "long" { $routeLong }
            default { $routeFrontier }
        }
        Add-Line "			``	$($contract.Name.Substring(0,1).ToUpper() + $contract.Name.Substring(1)) escort license: $name to $($target.Planet), $($target.Distance) jump(s), $($contract.Rate.ToString('N0')) credits per escort rating per day, cycle $($contract.Threshold) ship-days, ships &[number@cf: security $($contract.Prefix) ships], escort rating &[number@cf: security $($contract.Prefix) rating]/$($contract.RatingCap), average contract payout &[credits@cf: security $($contract.Prefix) trip payout].``"
        Add-Line "				to display"
        Add-Line "					has `"$($contract.Required)`""
    }
    foreach($campaign in $admiralCampaignTypes) {
        $target = $admiralTargets[$campaign.Prefix]
        Add-Line "			``	Admiral target, $($campaign.Name): $($target.Planet) in $($target.System), $($target.Distance) jump(s), vanilla threshold $($target.Threshold.ToString('N0')), required fleet rating $($target.RequiredRating), tribute $($target.Tribute.ToString('N0')) credits/day.``"
        Add-Line "				to display"
        Add-Line "					has `"cf: security admiral`""
        Add-Line "					not `"cf: admiral tribute $($campaign.Prefix)`""
    }
    Add-Line "			choice"
    Add-Line "				``	Buy the regional shuttle route to $($routeRegional.Planet) for 120,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle`""
    Add-Line "						not `"cf: shuttle route regional`""
    Add-Line "						`"cf: reserve`" >= 120000"
    Add-Line "					goto `"buy regional route`""
    Add-Line "				``	Buy the long shuttle route to $($routeLong.Planet) for 275,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle route regional`""
    Add-Line "						not `"cf: shuttle route long`""
    Add-KnownSystemRequirement $routeLong.System
    Add-Line "						`"cf: reserve`" >= 275000"
    Add-Line "					goto `"buy long route`""
    Add-Line "				``	Buy the frontier shuttle route to $($routeFrontier.Planet) for 475,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: shuttle route long`""
    Add-Line "						not `"cf: shuttle route frontier`""
    Add-KnownSystemRequirement $routeFrontier.System
    Add-Line "						`"cf: reserve`" >= 475000"
    Add-Line "					goto `"buy frontier route`""
    Add-Line "				``	Buy the regional mining rights in $($miningRegional.System) for 220,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining`""
    Add-Line "						not `"cf: mining claim regional`""
    Add-Line "						`"cf: reserve`" >= 220000"
    Add-Line "					goto `"buy regional mining claim`""
    Add-Line "				``	Buy the deep mining rights in $($miningDeep.System) for 420,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining claim regional`""
    Add-Line "						not `"cf: mining claim deep`""
    Add-KnownSystemRequirement $miningDeep.System
    Add-Line "						`"cf: reserve`" >= 420000"
    Add-Line "					goto `"buy deep mining claim`""
    Add-Line "				``	Buy the frontier mining rights in $($miningFrontier.System) for 700,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: mining claim deep`""
    Add-Line "						not `"cf: mining claim frontier`""
    Add-KnownSystemRequirement $miningFrontier.System
    Add-Line "						`"cf: reserve`" >= 700000"
    Add-Line "					goto `"buy frontier mining claim`""
    Add-Line "				``	Buy the regional trading license to $($tradingRegional.Planet) for 180,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading`""
    Add-Line "						not `"cf: trading license regional`""
    Add-Line "						`"cf: reserve`" >= 180000"
    Add-Line "					goto `"buy regional trading license`""
    Add-Line "				``	Buy the long trading license to $($tradingLong.Planet) for 400,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading license regional`""
    Add-Line "						not `"cf: trading license long`""
    Add-KnownSystemRequirement $tradingLong.System
    Add-Line "						`"cf: reserve`" >= 400000"
    Add-Line "					goto `"buy long trading license`""
    Add-Line "				``	Buy the frontier trading license to $($tradingFrontier.Planet) for 750,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: trading license long`""
    Add-Line "						not `"cf: trading license frontier`""
    Add-KnownSystemRequirement $tradingFrontier.System
    Add-Line "						`"cf: reserve`" >= 750000"
    Add-Line "					goto `"buy frontier trading license`""
    Add-Line "				``	Buy the regional security license to $($routeRegional.Planet) for 250,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security`""
    Add-Line "						not `"cf: security license regional`""
    Add-Line "						`"cf: reserve`" >= 250000"
    Add-Line "					goto `"buy regional security license`""
    Add-Line "				``	Buy the long security license to $($routeLong.Planet) for 550,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security license regional`""
    Add-Line "						not `"cf: security license long`""
    Add-KnownSystemRequirement $routeLong.System
    Add-Line "						`"cf: reserve`" >= 550000"
    Add-Line "					goto `"buy long security license`""
    Add-Line "				``	Buy the frontier security license to $($routeFrontier.Planet) for 950,000 company credits.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: security license long`""
    Add-Line "						not `"cf: security license frontier`""
    Add-KnownSystemRequirement $routeFrontier.System
    Add-Line "						`"cf: reserve`" >= 950000"
    Add-Line "					goto `"buy frontier security license`""
    foreach($route in $shuttleRouteTypes) {
        foreach($ship in $shuttleShipTypes) {
            Add-ShuttleShipChoice $route $ship
        }
        Add-ShuttleVipChoice $route
    }
    foreach($claim in $miningClaimTypes) {
        foreach($ship in $miningShipTypes) {
            Add-MiningShipChoice $claim $ship
        }
    }
    Add-MiningDroneChoice
    foreach($route in $tradingRouteTypes) {
        foreach($ship in $tradingShipTypes) {
            Add-TradingShipChoice $route $ship
        }
        Add-TradingMerchantChoice $route
    }
    foreach($contract in $securityContractTypes) {
        foreach($ship in $securityShipTypes) {
            Add-SecurityShipChoice $contract $ship
        }
    }
    Add-SecurityAdmiralChoice
    foreach($ship in $securityShipTypes) {
        Add-AdmiralShipChoice $ship
    }
    foreach($campaign in $admiralCampaignTypes) {
        Add-AdmiralTributeChoice $campaign ($admiralTargets[$campaign.Prefix])
    }
    foreach($share in @(0, 10, 25, 50, 75, 100)) {
        Add-Line "				``	Set owner payout share to $share%.``"
        Add-Line "					to display"
        Add-Line "						has `"cf: active`""
        Add-Line "					goto `"set payout $share`""
    }
    Add-Line "				``	Enable AutoPay for owner payouts. Automatic transfers pay 90% to you and charge 10% as transaction fees.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						not `"cf: autopay`""
    Add-Line "					goto `"enable autopay`""
    Add-Line "				``	Disable AutoPay. Future owner payouts will wait in owner payable until collected manually.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: active`""
    Add-Line "						has `"cf: autopay`""
    Add-Line "					goto `"disable autopay`""
    foreach($amount in @(1000, 5000, 10000, 50000, 250000)) {
        Add-OwnerPayoutChoice $amount
    }
    Add-StationBuildChoices
    foreach($amount in @(1000, 10000, 100000, 1000000, 10000000, 100000000)) {
        Add-QuickInvestChoice $amount
    }
    Add-Line "				``	Close the operating-loss file.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: distress open`""
    Add-Line "						`"cf: reserve`" >= 0"
    Add-Line "					goto `"close distress file`""
    Add-Line "				``	Hire an operations manager for 250,000 credits plus 10,000 credits per day.``"
    Add-Line "					to display"
    Add-Line "						has `"cf: manual`""
    Add-Line "						`"credits`" >= 250000"
    Add-Line "					goto `"hire manager`""
    Add-Line "				``	File the report and leave.``"
    Add-Line "					decline"
    Add-CompanyTransactionSummaryLabel
    Add-Line "			label `"buy regional route`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 120000"
    Add-Line "				set `"cf: shuttle route regional`""
    Add-Line "				`"cf: shuttle route count`" ++"
    Add-Line "			``Your dispatcher buys the regional passenger contract to $($routeRegional.Planet). It is ready for ships as soon as you assign capacity to it.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy long route`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 275000"
    Add-Line "				set `"cf: shuttle route long`""
    Add-Line "				`"cf: shuttle route count`" ++"
    Add-Line "			``Your dispatcher secures the longer passenger corridor to $($routeLong.Planet). It will pay better, but it needs more berth-days to complete each round trip.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy frontier route`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 475000"
    Add-Line "				set `"cf: shuttle route frontier`""
    Add-Line "				`"cf: shuttle route count`" ++"
    Add-Line "			``Your company signs the frontier passenger rights to $($routeFrontier.Planet). The route is slower, expensive to open, and finally worth running with larger ships.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy regional mining claim`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 220000"
    Add-Line "				set `"cf: mining claim regional`""
    Add-Line "				`"cf: mining claim count`" ++"
    Add-Line "				`"cf: mining regional value`" = $($miningRegional.ValuePerCargo)"
    Add-Line "			``Your staff files the regional mineral rights in $($miningRegional.System). The claim is a $($miningRegional.Summary), valued at about $($miningRegional.ValuePerCargo) credits per cargo before fleet efficiency.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy deep mining claim`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 420000"
    Add-Line "				set `"cf: mining claim deep`""
    Add-Line "				`"cf: mining claim count`" ++"
    Add-Line "				`"cf: mining deep value`" = $($miningDeep.ValuePerCargo)"
    Add-Line "			``Your staff files the deep mineral rights in $($miningDeep.System). The longer cycle is offset by a $($miningDeep.Summary), valued at about $($miningDeep.ValuePerCargo) credits per cargo before fleet efficiency.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy frontier mining claim`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 700000"
    Add-Line "				set `"cf: mining claim frontier`""
    Add-Line "				`"cf: mining claim count`" ++"
    Add-Line "				`"cf: mining frontier value`" = $($miningFrontier.ValuePerCargo)"
    Add-Line "			``Your staff files the frontier mineral rights in $($miningFrontier.System). It is slow and costly to service, but its $($miningFrontier.Summary) is valued at about $($miningFrontier.ValuePerCargo) credits per cargo before fleet efficiency.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy regional trading license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 180000"
    Add-Line "				set `"cf: trading license regional`""
    Add-Line "				`"cf: trading route count`" ++"
    Add-Line "				`"cf: trading regional value`" = $($tradingRegional.BaseValue)"
    Add-Line "				`"cf: trading regional optimized value`" = $($tradingRegional.OptimizedValue)"
    Add-Line "				`"cf: trading regional current value`" = $($tradingRegional.BaseValue)"
    Add-Line "			``Your office buys the regional trading license to $($tradingRegional.Planet). Current price tables point to $($tradingRegional.Commodity) as the strongest known spread.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy long trading license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 400000"
    Add-Line "				set `"cf: trading license long`""
    Add-Line "				`"cf: trading route count`" ++"
    Add-Line "				`"cf: trading long value`" = $($tradingLong.BaseValue)"
    Add-Line "				`"cf: trading long optimized value`" = $($tradingLong.OptimizedValue)"
    Add-Line "				`"cf: trading long current value`" = $($tradingLong.BaseValue)"
    Add-Line "			``Your office buys the long trading license to $($tradingLong.Planet). Current price tables point to $($tradingLong.Commodity) as the strongest known spread.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy frontier trading license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 750000"
    Add-Line "				set `"cf: trading license frontier`""
    Add-Line "				`"cf: trading route count`" ++"
    Add-Line "				`"cf: trading frontier value`" = $($tradingFrontier.BaseValue)"
    Add-Line "				`"cf: trading frontier optimized value`" = $($tradingFrontier.OptimizedValue)"
    Add-Line "				`"cf: trading frontier current value`" = $($tradingFrontier.BaseValue)"
    Add-Line "			``Your office buys the frontier trading license to $($tradingFrontier.Planet). Current price tables point to $($tradingFrontier.Commodity) as the strongest known spread.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy regional security license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 250000"
    Add-Line "				set `"cf: security license regional`""
    Add-Line "				`"cf: security contract count`" ++"
    Add-Line "				`"cf: security regional rate`" = 1500"
    Add-Line "			``Your bureau secures the regional escort license to $($routeRegional.Planet). Empty systems along the way do not need separate paperwork; only the protected endpoint matters.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy long security license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 550000"
    Add-Line "				set `"cf: security license long`""
    Add-Line "				`"cf: security contract count`" ++"
    Add-Line "				`"cf: security long rate`" = 2200"
    Add-Line "			``Your bureau secures the long-range escort license to $($routeLong.Planet). Longer contracts pay more because clients are paying for more exposed flight time.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"buy frontier security license`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 950000"
    Add-Line "				set `"cf: security license frontier`""
    Add-Line "				`"cf: security contract count`" ++"
    Add-Line "				`"cf: security frontier rate`" = 3000"
    Add-Line "			``Your bureau secures the frontier escort license to $($routeFrontier.Planet). These contracts are slow, expensive, and attractive to serious warship fleets.``"
    Add-CompanyOutlookReturn
    foreach($route in $shuttleRouteTypes) {
        foreach($ship in $shuttleShipTypes) {
            Add-ShuttleShipLabel $route $ship
        }
        Add-ShuttleVipLabel $route
    }
    foreach($claim in $miningClaimTypes) {
        foreach($ship in $miningShipTypes) {
            Add-MiningShipLabel $claim $ship ($miningTargets[$claim.Prefix].ValuePerCargo)
        }
    }
    Add-MiningDroneLabel
    foreach($route in $tradingRouteTypes) {
        foreach($ship in $tradingShipTypes) {
            Add-TradingShipLabel $route $ship ($tradingTargets[$route.Prefix].BaseValue) ($tradingTargets[$route.Prefix].OptimizedValue)
        }
        Add-TradingMerchantLabel $route ($tradingTargets[$route.Prefix].OptimizedValue) ($tradingTargets[$route.Prefix].Commodity)
    }
    foreach($contract in $securityContractTypes) {
        foreach($ship in $securityShipTypes) {
            Add-SecurityShipLabel $contract $ship
        }
    }
    Add-SecurityAdmiralLabel $name
    foreach($ship in $securityShipTypes) {
        Add-AdmiralShipLabel $ship
    }
    foreach($campaign in $admiralCampaignTypes) {
        Add-AdmiralTributeLabel $campaign ($admiralTargets[$campaign.Prefix])
    }
    foreach($share in @(0, 10, 25, 50, 75, 100)) {
        Add-Line "			label `"set payout $share`""
    Add-Line "			action"
    Add-Line "				`"cf: payout share`" = $share"
    Add-Line "			``The company payout policy is now $share% to you and $((100 - $share))% retained for company growth.``"
    Add-CompanyOutlookReturn
    }
    Add-Line "			label `"enable autopay`""
    Add-Line "			action"
    Add-Line "				set `"cf: autopay`""
    Add-Line "			``AutoPay is now enabled. Future owner-payable balances will be transferred to your account automatically in batches, with a 10% transaction fee deducted from each batch.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"disable autopay`""
    Add-Line "			action"
    Add-Line "				clear `"cf: autopay`""
    Add-Line "			``AutoPay is now disabled. Future owner allocations will accumulate in owner payable until you collect them manually at headquarters.``"
    Add-CompanyOutlookReturn
    foreach($amount in @(1000, 5000, 10000, 50000, 250000)) {
        Add-OwnerPayoutLabel $amount
    }
    Add-StationBuildLabels
    foreach($amount in @(1000, 10000, 100000, 1000000, 10000000, 100000000)) {
        Add-InvestLabel $amount
    }
    Add-Line "			label `"close distress file`""
    Add-Line "			action"
    Add-Line "				clear `"cf: distress open`""
    Add-Line "			``Your staff marks the operating-loss file as handled.``"
    Add-CompanyOutlookReturn
    Add-Line "			label `"hire manager`""
    Add-Line "			action"
    Add-Line "				payment -250000"
    Add-Line "				clear `"cf: manual`""
    Add-Line "				clear `"cf: manual pending`""
    Add-Line "				clear `"cf: manual active`""
    Add-Line "				set `"cf: managed`""
    Add-Line "				set `"cf: manager pending`""
    Add-Line "				`"cf: manager unpaid days`" = 0"
    Add-Line "				`"cf: manager daily cost`" = 0"
    Add-Line "				clear `"cf: manager salary checked`""
    Add-Line "				fail `"Company Foundations: Shuttle Manual Operations`""
    Add-Line "				fail `"Company Foundations: Mining Manual Operations`""
    Add-Line "				fail `"Company Foundations: Trading Manual Operations`""
    Add-Line "				fail `"Company Foundations: Security Manual Operations`""
    Add-ClearOperationsMissionStateActions "				"
    Add-Line "			``You sign the management contract. The manager will cost 10,000 credits per day, follow your payout policy, keep a conservative reserve, and reinvest company funds into appropriate routes, claims, ships, and upgrades when the balance allows it.``"
    Add-CompanyOutlookReturn
    Add-Line ""

    Set-OutputSection "company manager investments.txt"
    Add-ManagerRoutePurchaseMission "regional" "Regional" "" "cf: shuttle route regional" 120000 $hqCondition "" $name
    Add-ManagerRoutePurchaseMission "long" "Long" "cf: shuttle route regional" "cf: shuttle route long" 275000 $hqCondition $routeLong.System $name
    Add-ManagerRoutePurchaseMission "frontier" "Frontier" "cf: shuttle route long" "cf: shuttle route frontier" 475000 $hqCondition $routeFrontier.System $name

    $managerShuttleShips = @($shuttleShipTypes | Where-Object { $_.Key -in @("shuttle", "heavy shuttle", "bounder", "blackbird") })
    foreach($route in $shuttleRouteTypes) {
        foreach($ship in $managerShuttleShips) {
            Add-ManagerShuttleShipPurchaseMission $route $ship $hqCondition $name
        }
    }

    foreach($claim in @($miningClaimTypes | Where-Object { $_.Prefix -ne "local" })) {
        $target = $miningTargets[$claim.Prefix]
        $neededReserve = $claim.Cost * 2
        $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($claim.Name) Mining Claim: $name"
        Add-Line "mission $missionName"
        Add-Line "	name `"Manager Mining Claim Purchase`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: mining`""
        Add-Line "		has `"cf: managed`""
        Add-Line "		has $hqCondition"
        Add-Line "		not `"cf: hq suspended`""
        Add-Line "		not `"$($claim.Required)`""
        if($claim.Prefix -eq "deep") {
            Add-Line "		has `"cf: mining claim regional`""
        } elseif($claim.Prefix -eq "frontier") {
            Add-Line "		has `"cf: mining claim deep`""
        }
        Add-KnownSystemRequirement $target.System "		"
        Add-Line "		`"cf: reserve`" >= $neededReserve"
        Add-Line "	on offer"
        Add-Line "		`"cf: reserve`" -= $($claim.Cost)"
        Add-Line "		set `"$($claim.Required)`""
        Add-Line "		`"cf: mining claim count`" ++"
        Add-Line "		`"cf: mining $($claim.Prefix) value`" = $($target.ValuePerCargo)"
        Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought the $($claim.Name) mining rights in $($target.System) for $($claim.Cost.ToString('N0')) company credits after keeping at least double the purchase cost in reserve.``"
        Add-Line ""
    }

    foreach($claim in $miningClaimTypes) {
        $target = $miningTargets[$claim.Prefix]
        $neededReserve = 2000000
        $maxCargoBeforePurchase = $claim.CargoCap - 80
        $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($claim.Name) Sunder: $name"
        Add-Line "mission $missionName"
        Add-Line "	name `"Manager Mining Fleet Purchase`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: mining`""
        Add-Line "		has `"cf: managed`""
        Add-Line "		has $hqCondition"
        Add-Line "		not `"cf: hq suspended`""
        Add-Line "		has `"$($claim.Required)`""
        Add-ConditionLine "has" (Get-ShipAvailableCondition "Sunder") "		"
        Add-Line "		`"cf: reserve`" >= $neededReserve"
        Add-Line "		`"cf: mining $($claim.Prefix) cargo`" <= $maxCargoBeforePurchase"
        Add-Line "	on offer"
        Add-Line "		`"cf: reserve`" -= 1000000"
        Add-Line "		`"cf: mining $($claim.Prefix) cargo`" += 80"
        Add-Line "		`"cf: mining $($claim.Prefix) ships`" ++"
        Add-Line "		`"cf: mining $($claim.Prefix) daily crew`" += 300"
        Add-Line "		`"cf: mining $($claim.Prefix) trip payout`" = `"cf: mining $($claim.Prefix) cargo`" * $($target.ValuePerCargo) / `"cf: mining $($claim.Prefix) ships`""
        Add-Line "		`"cf: mining $($claim.Prefix) trip expenses`" = `"cf: mining $($claim.Prefix) daily crew`" * $($claim.Threshold) / `"cf: mining $($claim.Prefix) ships`""
        Add-Line "		`"cf: mining fleet`" ++"
        Add-Line "		`"cf: mining drone capacity`" += 2"
        Add-Line "		`"cf: fleet value`" += 1000000"
        Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought a Sunder for the $($claim.Name) mining claim for 1,000,000 company credits after keeping at least double the purchase cost in reserve.``"
        Add-Line ""
    }

    $droneMissionName = Format-ESMissionName "Company Foundations: Manager Buy Mining Drone: $name"
    Add-Line "mission $droneMissionName"
    Add-Line "	name `"Manager Mining Drone Purchase`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: mining`""
    Add-Line "		has `"cf: managed`""
    Add-Line "		has $hqCondition"
    Add-Line "		not `"cf: hq suspended`""
    Add-ConditionLine "has" (Get-ShipAvailableCondition "Mining Drone") "		"
    Add-Line "		`"cf: reserve`" >= 116000"
    Add-Line "		`"cf: mining drones`" < `"cf: mining drone capacity`""
    Add-Line "	on offer"
    Add-Line "		`"cf: reserve`" -= 58000"
    Add-Line "		`"cf: mining drones`" ++"
    Add-Line "		`"cf: mining efficiency bonus`" += 15"
    Add-Line "		`"cf: fleet value`" += 58000"
    Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought a Mining Drone for 58,000 company credits after keeping at least double the purchase cost in reserve.``"
    Add-Line ""

    foreach($route in @($tradingRouteTypes | Where-Object { $_.Prefix -ne "local" })) {
        $target = $tradingTargets[$route.Prefix]
        $neededReserve = $route.Cost * 2
        $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($route.Name) Trading License: $name"
        Add-Line "mission $missionName"
        Add-Line "	name `"Manager Trading License Purchase`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: trading`""
        Add-Line "		has `"cf: managed`""
        Add-Line "		has $hqCondition"
        Add-Line "		not `"cf: hq suspended`""
        Add-Line "		not `"$($route.Required)`""
        if($route.Prefix -eq "long") {
            Add-Line "		has `"cf: trading license regional`""
        } elseif($route.Prefix -eq "frontier") {
            Add-Line "		has `"cf: trading license long`""
        }
        Add-KnownSystemRequirement $target.System "		"
        Add-Line "		`"cf: reserve`" >= $neededReserve"
        Add-Line "	on offer"
        Add-Line "		`"cf: reserve`" -= $($route.Cost)"
        Add-Line "		set `"$($route.Required)`""
        Add-Line "		`"cf: trading route count`" ++"
        Add-Line "		`"cf: trading $($route.Prefix) value`" = $($target.BaseValue)"
        Add-Line "		`"cf: trading $($route.Prefix) optimized value`" = $($target.OptimizedValue)"
        Add-Line "		`"cf: trading $($route.Prefix) current value`" = $($target.BaseValue)"
        Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought the $($route.Name) trading license to $($target.Planet) for $($route.Cost.ToString('N0')) company credits after keeping at least double the purchase cost in reserve.``"
        Add-Line ""
    }

    $managerTradeShips = @($tradingShipTypes | Where-Object { $_.Key -in @("star barge", "freighter", "behemoth", "bulk freighter") })
    foreach($route in $tradingRouteTypes) {
        $target = $tradingTargets[$route.Prefix]
        foreach($ship in $managerTradeShips) {
            if($ship.Cargo -gt $route.CargoCap) {
                continue
            }
            $neededReserve = $ship.Cost * 2
            $maxCargoBeforePurchase = $route.CargoCap - $ship.Cargo
            $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($ship.Name) for $($route.Name) Trade: $name"
            Add-Line "mission $missionName"
            Add-Line "	name `"Manager Trading Fleet Purchase`""
            Add-Line "	invisible"
            Add-Line "	landing"
            Add-Line "	repeat"
            Add-Line "	to offer"
            Add-Line "		has `"cf: trading`""
            Add-Line "		has `"cf: managed`""
            Add-Line "		has $hqCondition"
            Add-Line "		not `"cf: hq suspended`""
            Add-Line "		has `"$($route.Required)`""
            Add-ShipAvailabilityRequirement $ship "		"
            Add-Line "		`"cf: reserve`" >= $neededReserve"
            Add-Line "		`"cf: trading $($route.Prefix) cargo`" <= $maxCargoBeforePurchase"
            Add-Line "	on offer"
            Add-Line "		`"cf: reserve`" -= $($ship.Cost)"
            Add-Line "		`"cf: trading $($route.Prefix) cargo`" += $($ship.Cargo)"
            Add-Line "		`"cf: trading $($route.Prefix) ships`" ++"
            Add-Line "		`"cf: trading $($route.Prefix) daily crew`" += $($ship.Crew * 100)"
            Add-Line "		`"cf: trading $($route.Prefix) trip payout`" = `"cf: trading $($route.Prefix) cargo`" * `"cf: trading $($route.Prefix) current value`" / `"cf: trading $($route.Prefix) ships`""
            Add-Line "		`"cf: trading $($route.Prefix) daily expenses`" = `"cf: trading $($route.Prefix) daily crew`""
            Add-Line "		`"cf: trading $($route.Prefix) daily expenses`" += `"cf: trading $($route.Prefix) daily trader`""
            Add-Line "		`"cf: trading $($route.Prefix) trip expenses`" = `"cf: trading $($route.Prefix) daily expenses`" * $($route.Threshold) / `"cf: trading $($route.Prefix) ships`""
            Add-Line "		`"cf: trading fleet`" ++"
            Add-Line "		`"cf: fleet value`" += $($ship.Cost)"
            Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought a $($ship.Name) for the $($route.Name) trade route for $($ship.Cost.ToString('N0')) company credits after keeping at least double the purchase cost in reserve.``"
            Add-Line ""
        }

        $spreadGain = $target.OptimizedValue - $target.BaseValue
        if($spreadGain -gt 0) {
            $minCargoForTrader = [int][math]::Ceiling((10000.0 * $route.Threshold) / $spreadGain)
            if($minCargoForTrader -le $route.CargoCap) {
                $missionName = Format-ESMissionName "Company Foundations: Manager Assign Trader to $($route.Name): $name"
                Add-Line "mission $missionName"
                Add-Line "	name `"Manager Trading Specialist Assignment`""
                Add-Line "	invisible"
                Add-Line "	landing"
                Add-Line "	repeat"
                Add-Line "	to offer"
                Add-Line "		has `"cf: trading`""
                Add-Line "		has `"cf: managed`""
                Add-Line "		has $hqCondition"
                Add-Line "		not `"cf: hq suspended`""
                Add-Line "		has `"$($route.Required)`""
                Add-Line "		not `"cf: trading $($route.Prefix) trader`""
                Add-Line "		`"cf: trading $($route.Prefix) cargo`" >= $minCargoForTrader"
                Add-Line "		`"cf: reserve`" >= 20000"
                Add-Line "	on offer"
                Add-Line "		set `"cf: trading $($route.Prefix) trader`""
                Add-Line "		`"cf: trading $($route.Prefix) daily trader`" = 10000"
                Add-Line "		`"cf: trading $($route.Prefix) current value`" = $($target.OptimizedValue)"
                Add-Line "		`"cf: trading $($route.Prefix) trip payout`" = `"cf: trading $($route.Prefix) cargo`" * `"cf: trading $($route.Prefix) current value`" / `"cf: trading $($route.Prefix) ships`""
                Add-Line "		`"cf: trading $($route.Prefix) daily expenses`" = `"cf: trading $($route.Prefix) daily crew`""
                Add-Line "		`"cf: trading $($route.Prefix) daily expenses`" += `"cf: trading $($route.Prefix) daily trader`""
                Add-Line "		`"cf: trading $($route.Prefix) trip expenses`" = `"cf: trading $($route.Prefix) daily expenses`" * $($route.Threshold) / `"cf: trading $($route.Prefix) ships`""
                Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager assigned a specialist trader to the $($route.Name) route after the route had enough cargo capacity to justify the 10,000 credit daily salary.``"
                Add-Line ""
            }
        }
    }

    foreach($contract in @($securityContractTypes | Where-Object { $_.Prefix -ne "local" })) {
        $target = switch($contract.Prefix) {
            "regional" { $routeRegional }
            "long" { $routeLong }
            default { $routeFrontier }
        }
        $neededReserve = $contract.Cost * 2
        $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($contract.Name) Security License: $name"
        Add-Line "mission $missionName"
        Add-Line "	name `"Manager Security License Purchase`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: security`""
        Add-Line "		has `"cf: managed`""
        Add-Line "		has $hqCondition"
        Add-Line "		not `"cf: hq suspended`""
        Add-Line "		not `"$($contract.Required)`""
        if($contract.Prefix -eq "long") {
            Add-Line "		has `"cf: security license regional`""
        } elseif($contract.Prefix -eq "frontier") {
            Add-Line "		has `"cf: security license long`""
        }
        Add-KnownSystemRequirement $target.System "		"
        Add-Line "		`"cf: reserve`" >= $neededReserve"
        Add-Line "	on offer"
        Add-Line "		`"cf: reserve`" -= $($contract.Cost)"
        Add-Line "		set `"$($contract.Required)`""
        Add-Line "		`"cf: security contract count`" ++"
        Add-Line "		`"cf: security $($contract.Prefix) rate`" = $($contract.Rate)"
        Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought the $($contract.Name) security license to $($target.Planet) for $($contract.Cost.ToString('N0')) company credits after keeping at least double the purchase cost in reserve.``"
        Add-Line ""
    }

    $managerSecurityShips = @($securityShipTypes | Where-Object { $_.Key -in @("hawk", "manta", "splinter", "vanguard") })
    foreach($contract in $securityContractTypes) {
        foreach($ship in $managerSecurityShips) {
            if($ship.Rating -gt $contract.RatingCap) {
                continue
            }
            $neededReserve = $ship.Cost * 2
            $maxRatingBeforePurchase = $contract.RatingCap - $ship.Rating
            $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($ship.Name) for $($contract.Name) Security: $name"
            Add-Line "mission $missionName"
            Add-Line "	name `"Manager Security Fleet Purchase`""
            Add-Line "	invisible"
            Add-Line "	landing"
            Add-Line "	repeat"
            Add-Line "	to offer"
            Add-Line "		has `"cf: security`""
            Add-Line "		has `"cf: managed`""
            Add-Line "		has $hqCondition"
            Add-Line "		not `"cf: hq suspended`""
            Add-Line "		has `"$($contract.Required)`""
            Add-ShipAvailabilityRequirement $ship "		"
            Add-Line "		`"cf: reserve`" >= $neededReserve"
            Add-Line "		`"cf: security $($contract.Prefix) rating`" <= $maxRatingBeforePurchase"
            Add-Line "	on offer"
            Add-Line "		`"cf: reserve`" -= $($ship.Cost)"
            Add-Line "		`"cf: security $($contract.Prefix) rating`" += $($ship.Rating)"
            Add-Line "		`"cf: security $($contract.Prefix) ships`" ++"
            Add-Line "		`"cf: security $($contract.Prefix) daily crew`" += $($ship.Crew * 100)"
            Add-Line "		`"cf: security $($contract.Prefix) trip payout`" = `"cf: security $($contract.Prefix) rating`" * $($contract.Rate) * $($contract.Threshold) / `"cf: security $($contract.Prefix) ships`""
            Add-Line "		`"cf: security $($contract.Prefix) trip expenses`" = `"cf: security $($contract.Prefix) daily crew`" * $($contract.Threshold) / `"cf: security $($contract.Prefix) ships`""
            Add-Line "		`"cf: security fleet`" ++"
            Add-Line "		`"cf: security combat rating`" += $($ship.Rating)"
            Add-Line "		`"cf: fleet value`" += $($ship.Cost)"
            Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought a $($ship.Name) for the $($contract.Name) security contract for $($ship.Cost.ToString('N0')) company credits after keeping at least double the purchase cost in reserve.``"
            Add-Line ""
        }
    }

    $admiralMissionName = Format-ESMissionName "Company Foundations: Manager Hire Fleet Admiral: $name"
    Add-Line "mission $admiralMissionName"
    Add-Line "	name `"Manager Fleet Admiral Hire`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: security`""
    Add-Line "		has `"cf: managed`""
    Add-Line "		has $hqCondition"
    Add-Line "		not `"cf: hq suspended`""
    Add-Line "		not `"cf: security admiral`""
    Add-Line "		`"cf: reserve`" >= 600000"
    Add-Line "	on offer"
    Add-Line "		`"cf: reserve`" -= 300000"
    Add-Line "		set `"cf: security admiral`""
    Add-ClearAllAdmiralLocationConditions "		"
    Add-ClearAllAdmiralDestinationConditions "		"
    Add-ConditionLine "set" "cf: admiral location: $name" "		"
    Add-Line "		clear `"cf: admiral in transit`""
    Add-Line "		`"cf: admiral travel days`" = 0"
    Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager hired one fleet admiral for 300,000 company credits to command an independent pirate-tribute fleet. The admiral's office remains with headquarters, and the strike fleet starts operating from $name. The admiral costs 20,000 credits per day and escort-route ships do not count toward admiral fleet rating.``"
    Add-Line ""

    $managerAdmiralShips = @($securityShipTypes | Where-Object { $_.Key -in @("manta", "vanguard", "leviathan") })
    foreach($ship in $managerAdmiralShips) {
        $neededReserve = $ship.Cost * 2
        $maxRatingBeforePurchase = 42 - $ship.Rating
        $missionName = Format-ESMissionName "Company Foundations: Manager Buy $($ship.Name) for Admiral Fleet: $name"
        Add-Line "mission $missionName"
        Add-Line "	name `"Manager Admiral Fleet Purchase`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: security`""
        Add-Line "		has `"cf: managed`""
        Add-Line "		has `"cf: security admiral`""
        Add-Line "		has $hqCondition"
        Add-Line "		not `"cf: hq suspended`""
        Add-Line "		not `"cf: admiral in transit`""
        Add-Line "		`"cf: admiral travel days`" == 0"
        Add-ShipAvailabilityRequirement $ship "		"
        Add-Line "		`"cf: reserve`" >= $neededReserve"
        Add-Line "		`"cf: admiral rating`" <= $maxRatingBeforePurchase"
        Add-Line "	on offer"
        Add-Line "		`"cf: reserve`" -= $($ship.Cost)"
        Add-Line "		`"cf: admiral fleet`" ++"
        Add-Line "		`"cf: admiral rating`" += $($ship.Rating)"
        Add-Line "		`"cf: admiral daily crew`" += $($ship.Crew * 100)"
        Add-Line "		`"cf: fleet value`" += $($ship.Cost)"
        Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The operations manager bought a $($ship.Name) for the admiral strike fleet for $($ship.Cost.ToString('N0')) company credits after keeping at least double the purchase cost in reserve.``"
        Add-Line ""
    }

    foreach($campaign in $admiralCampaignTypes) {
        $target = $admiralTargets[$campaign.Prefix]
        $reserveNeeded = [math]::Max($target.OperationCost * 2, 200000)
        $missionName = Format-ESMissionName "Company Foundations: Manager Force $($campaign.Prefix) Pirate Tribute: $name"
        Add-Line "mission $missionName"
        Add-Line "	name `"Manager Admiral Tribute Campaign`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: security`""
        Add-Line "		has `"cf: managed`""
        Add-Line "		has `"cf: security admiral`""
        Add-Line "		has $hqCondition"
        Add-Line "		not `"cf: hq suspended`""
        Add-Line "		not `"cf: admiral tribute $($campaign.Prefix)`""
        Add-Line "		not `"cf: admiral in transit`""
        Add-Line "		`"cf: admiral travel days`" == 0"
        Add-KnownPlanetRequirement $target.Planet "		"
        Add-ConditionLine "has" "cf: admiral location: $($target.Planet)" "		"
        Add-Line "		`"cf: admiral rating`" >= $($target.RequiredRating)"
        Add-Line "		`"cf: reserve`" >= $reserveNeeded"
        Add-Line "	on offer"
        Add-Line "		`"cf: reserve`" -= $($target.OperationCost)"
        Add-Line "		set `"cf: admiral tribute $($campaign.Prefix)`""
        Add-Line "		`"cf: admiral tribute count`" ++"
        Add-Line "		`"cf: admiral tribute income`" += $($target.Tribute)"
        Add-Line "		log `"Company Foundations`" `"Manager Investment`" ``The fleet admiral forced $($target.Planet) in $($target.System) to pay $($target.Tribute.ToString('N0')) credits per day in company tribute. Required admiral fleet rating was $($target.RequiredRating), derived from the vanilla tribute threshold of $($target.Threshold.ToString('N0')).``"
        Add-Line ""
    }
}

Set-OutputSection "company access.txt"
foreach($planet in $eligible) {
    $name = $planet.Name
    $hqGovernment = Get-PlanetGovernmentName $planet
    $hqRequiredReputation = [int]$planet.RequiredReputation
    $hqDailyTax = Get-HQTaxRate $planet
    $planetToken = Format-ESToken $name
    $hqCondition = Format-ESMissionName "cf: hq: $name"

    $taxMigrationName = Format-ESMissionName "Company Foundations: Tax Rebalance: $name"
    Add-Line "mission $taxMigrationName"
    Add-Line "	name `"Company Tax Rebalance`""
    Add-Line "	invisible"
    Add-Line "	landing"
    Add-Line "	repeat"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		has $hqCondition"
    Add-Line "		not `"cf: tax model v2`""
    Add-Line "	on offer"
    Add-Line "		`"cf: hq base tax`" = $hqDailyTax"
    Add-Line "		`"cf: hq daily tax`" = `"cf: hq base tax`""
    Add-Line "		`"cf: hq daily tax`" -= `"cf: hq tax relief`""
    Add-Line "		`"cf: hq daily tax`" >?= 0"
    Add-Line "		set `"cf: tax model v2`""
    Add-Line "		log `"Company Foundations`" `"Tax Rebalance`" ``Updated company headquarters taxes for $name to the staff-scaled tax model. New base jurisdiction tax is $($hqDailyTax.ToString('N0')) credits per day before employee taxes and station relief.``"
    Add-Line ""

    if($hqGovernment) {
        $suspendName = Format-ESMissionName "Company Foundations: Suspend HQ Access: $name"
        Add-Line "mission $suspendName"
        Add-Line "	name `"Company Headquarters Suspended`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: active`""
        Add-Line "		has $hqCondition"
        Add-Line "		not `"cf: hq suspended`""
        Add-ReputationFailureRequirement $hqGovernment $hqRequiredReputation "		"
        Add-Line "	on offer"
        Add-Line "		set `"cf: hq suspended`""
        Add-Line "		`"cf: hq suspension count`" ++"
        Add-RestartOperationsActions "		"
        Add-Line "		conversation"
        Add-Line "			``A terse message from your company office catches up with you through a relay.``"
        Add-Line "			``	Subject: Headquarters access suspended.``"
        Add-Line "			``	Your headquarters on $name is under $hqGovernment jurisdiction, and your reputation has fallen below the local landing requirement of $hqRequiredReputation. Company operations are paused. Restore access or move the headquarters from another accessible company registrar.``"
        Add-Line "			choice"
        Add-Line "				``	Acknowledge the suspension.``"
        Add-Line "					decline"
        Add-Line ""

        $resumeName = Format-ESMissionName "Company Foundations: Resume HQ Access: $name"
        Add-Line "mission $resumeName"
        Add-Line "	name `"Company Headquarters Restored`""
        Add-Line "	invisible"
        Add-Line "	landing"
        Add-Line "	repeat"
        Add-Line "	to offer"
        Add-Line "		has `"cf: active`""
        Add-Line "		has $hqCondition"
        Add-Line "		has `"cf: hq suspended`""
        Add-ReputationRequirement $hqGovernment $hqRequiredReputation "		"
        Add-Line "	on offer"
        Add-Line "		clear `"cf: hq suspended`""
        Add-Line "		`"cf: hq restoration count`" ++"
        Add-Line "		set `"cf: manual pending`""
        Add-Line "		set `"cf: manager pending`""
        Add-Line "		log `"Company Foundations`" `"Headquarters Restored`" ``Company headquarters access on $name has been restored. Operations will restart under the existing management mode.``"
        Add-Line ""
    }

    $moveName = Format-ESMissionName "Company Foundations: Relocate Headquarters: $name"
    Add-Line "mission $moveName"
    Add-Line "	name `"Relocate Headquarters`""
    Add-Line "	description `"Move your active company headquarters to $name for 500,000 company credits.`""
    Add-Line "	minor"
    Add-Line "	repeat"
    Add-Line "	source $planetToken"
    Add-Line "	to offer"
    Add-Line "		has `"cf: active`""
    Add-Line "		not $hqCondition"
    Add-ReputationRequirement $hqGovernment $hqRequiredReputation "		"
    Add-Line "		`"cf: reserve`" >= 500000"
    Add-Line "	on offer"
    Add-Line "		conversation"
    Add-Line "			``A relocation clerk on $name can transfer your company charter, lease records, and tax registration here. Local taxes would be $($hqDailyTax.ToString('N0')) credits per day under $hqGovernment jurisdiction.``"
    Add-Line "			choice"
    Add-Line "				``	Move the headquarters here for 500,000 company credits.``"
    Add-Line "					goto `"move headquarters`""
    Add-Line "				``	Keep the current headquarters.``"
    Add-Line "					decline"
    Add-Line "			label `"move headquarters`""
    Add-Line "			action"
    Add-Line "				`"cf: reserve`" -= 500000"
    Add-Line "				`"cf: hq relocation count`" ++"
    Add-Line "				`"cf: total relocation costs`" += 500000"
    Add-ClearAllHQConditions "				"
    Add-Line "				set $hqCondition"
    Add-Line "				set `"cf: at hq`""
    Add-PlanetDiscoveryActions $planet "				"
    Add-Line "				clear `"cf: hq suspended`""
    Add-Line "				`"cf: hq base tax`" = $hqDailyTax"
    Add-Line "				`"cf: hq daily tax`" = `"cf: hq base tax`" - `"cf: hq tax relief`""
    Add-Line "				`"cf: hq required reputation`" = $hqRequiredReputation"
    Add-Line "				set `"cf: tax model v2`""
    Add-RestartOperationsActions "				"
    Add-Line "			``Your company headquarters is now registered on $name. Operations will restart under the existing management mode with the new local tax rate.``"
    Add-Line "				decline"
    Add-Line ""
}

Set-OutputSection "company operations.txt"
foreach($plan in $managerRoutePlans) {
    Add-ManagerRouteOptimizationMission $plan
}

foreach($companyType in $operationCompanyTypes) {
    Add-OperationStateRepairMission $companyType "Manual"
    Add-OperationStateRepairMission $companyType "Managed"
}

Add-Line "mission `"Company Foundations: Enforce AutoPay`""
Add-Line "	name `"Company AutoPay Enforcement`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		not `"cf: autopay`""
Add-Line "	on offer"
Add-Line "		set `"cf: autopay`""
Add-Line "		log `"Company Foundations`" `"AutoPay`" ``AutoPay was enabled automatically because owner payout buffers are now only technical transfer queues.``"
Add-Line ""

Add-Line "mission `"Company Foundations: Allocate Positive Net Profit`""
Add-Line "	name `"Company Profit Allocation`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		`"cf: unallocated net`" > 0"
Add-Line "	on offer"
Add-Line "		`"cf: allocation owner payout`" = `"cf: unallocated net`" * `"cf: payout share`" / 100"
Add-Line "		`"cf: last owner payout`" = `"cf: allocation owner payout`""
Add-Line "		`"cf: last retained earnings`" = `"cf: unallocated net`" - `"cf: allocation owner payout`""
Add-Line "		`"cf: owner payable`" += `"cf: allocation owner payout`""
Add-Line "		`"cf: reserve`" -= `"cf: allocation owner payout`""
Add-Line "		`"cf: total owner allocations`" += `"cf: allocation owner payout`""
Add-Line "		`"cf: month owner allocations`" += `"cf: allocation owner payout`""
Add-Line "		`"cf: total retained earnings`" -= `"cf: allocation owner payout`""
Add-Line "		`"cf: month retained earnings`" -= `"cf: allocation owner payout`""
Add-Line "		`"cf: unallocated net`" = 0"
Add-Line "		clear `"cf: distress open`""
Add-Line ""

foreach($amount in @(250000, 50000, 10000, 5000, 1000, 100, 10, 1)) {
    Add-AutoPayTransferMission $amount
}

Add-Line "mission `"Company Foundations: Manager Salary Reset`""
Add-Line "	name `"Company Manager Salary Reset`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		has `"cf: managed`""
Add-Line "		`"cf: reserve`" >= 10000"
Add-Line "	on offer"
Add-Line "		`"cf: manager unpaid days`" = 0"
Add-Line "		clear `"cf: manager salary checked`""
Add-Line ""

Add-Line "mission `"Company Foundations: Manager Salary Missed`""
Add-Line "	name `"Company Manager Salary Missed`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		has `"cf: managed`""
Add-Line "		not `"cf: manager salary checked`""
Add-Line "		`"cf: reserve`" < 10000"
Add-Line "	on offer"
Add-Line "		`"cf: manager unpaid days`" ++"
Add-Line "		set `"cf: manager salary checked`""
Add-Line "		log `"Company Foundations`" `"Manager Salary`" ``The operations manager could not draw the 10,000 credit daily salary because company reserve was below 10,000 credits.``"
Add-Line ""

Add-Line "mission `"Company Foundations: Manager Resignation`""
Add-Line "	name `"Company Manager Resignation`""
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		has `"cf: managed`""
Add-Line "		`"cf: manager unpaid days`" >= 2"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-ManagerResignationActions "				"
Add-Line "			``A terse resignation notice from your operations manager is waiting when you land.``"
Add-Line "			``	After two checked operating days without enough company reserve to cover the 10,000 credit salary, the manager has terminated the contract. The company has reverted to owner-managed operations until you hire a new manager.``"
Add-Line "			choice"
Add-Line "				``	Acknowledge the resignation.``"
Add-Line "					decline"
Add-Line ""

Add-Line "mission `"Company Foundations: Negative Balance Letter`""
Add-Line "	name `"Company Distress Letter`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		not `"cf: distress open`""
Add-Line "		`"cf: unallocated net`" < 0"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			``A priority message from your company office is waiting when you land.``"
Add-Line "			``	Subject: Operating loss.``"
Add-Line "			``	The last operating period closed at &[credits@cf: unallocated net]. After fixed costs, crew, and management fees, there is no owner payout. The staff asks you to visit headquarters, review the balance, and stabilize the company reserve.``"
Add-Line "			choice"
Add-Line "				``	Acknowledge the loss report.``"
Add-Line "					goto `"acknowledge loss`""
Add-Line "			label `"acknowledge loss`""
Add-Line "			action"
Add-Line "				set `"cf: distress open`""
Add-Line "				`"cf: distress reports`" ++"
Add-Line "				`"cf: unallocated net`" = 0"
Add-Line "			``The message is archived under open company issues.``"
Add-Line "				decline"
Add-Line ""

Add-Line "mission `"Company Foundations: Monthly Balance Report`""
Add-Line "	name `"Monthly Company Balance`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: active`""
Add-Line "		`"cf: days operated`" >= `"cf: next report day`""
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			``Your company office transmits its monthly balance report as soon as you touch down.``"
Add-Line "			``	Period ending day &[number@cf: days operated]. Company reserve: &[credits@cf: reserve]. AutoPay queue: &[credits@cf: owner payable].``"
Add-Line "			``	Monthly gross: &[credits@cf: month gross]. Monthly expenses: &[credits@cf: month expenses]. Manager costs: &[credits@cf: month manager costs]. Office staff costs: &[credits@cf: month office staff costs]. Taxes: &[credits@cf: month tax paid]. Net profit: &[credits@cf: month net profit].``"
Add-Line "			``	Station operations: revenue &[credits@cf: month station revenue], upkeep &[credits@cf: month station upkeep], station assets &[number@cf: station count].``"
Add-Line "				to display"
Add-Line "					has `"cf: station orbital office`""
Add-Line "			``	Owner allocation: &[credits@cf: month owner allocations]. Retained earnings: &[credits@cf: month retained earnings]. Lifetime net profit: &[credits@cf: total net profit].``"
Add-Line "			``	AutoPay: enabled, gross automatic transfers &[credits@cf: autopay gross transfers], net received &[credits@cf: autopay net transfers], fees &[credits@cf: autopay fees].``"
Add-Line "				to display"
Add-Line "					has `"cf: autopay`""
Add-Line "			choice"
Add-Line "				``	File the monthly report.``"
Add-Line "					goto `"file report`""
Add-Line "			label `"file report`""
Add-Line "			action"
Add-Line "				`"cf: report number`" ++"
Add-Line "				`"cf: next report day`" += 30"
Add-Line "				`"cf: month gross`" = 0"
Add-Line "				`"cf: month expenses`" = 0"
Add-Line "				`"cf: month manager costs`" = 0"
Add-Line "				`"cf: month office staff costs`" = 0"
Add-Line "				`"cf: month tax paid`" = 0"
Add-Line "				`"cf: month station revenue`" = 0"
Add-Line "				`"cf: month station upkeep`" = 0"
Add-Line "				`"cf: month net profit`" = 0"
Add-Line "				`"cf: month owner allocations`" = 0"
Add-Line "				`"cf: month retained earnings`" = 0"
foreach($division in @("shuttle", "mining", "trading", "security")) {
    Add-Line "				`"cf: $division month gross`" = 0"
    Add-Line "				`"cf: $division month expenses`" = 0"
    Add-Line "				`"cf: $division month net`" = 0"
}
Add-Line "			``The report is filed. The next monthly report is scheduled for operating day &[number@cf: next report day].``"
Add-Line "				decline"
Add-Line ""

Add-Line "mission `"Company Foundations: Shuttle Manual Operations`""
Add-Line "	name `"Shuttle Company Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: shuttle`""
Add-Line "		has `"cf: manual`""
Add-Line "		has `"cf: manual pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manual pending`""
Add-Line "				set `"cf: manual active`""
Add-Line "			``Your shuttle company has finished its first operating schedule. Route profit will now be split according to the payout share set at headquarters.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-ShuttleDailyAccountingLines
Add-Line ""
Add-Line "mission `"Company Foundations: Mining Manual Operations`""
Add-Line "	name `"Mining Company Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: mining`""
Add-Line "		has `"cf: manual`""
Add-Line "		has `"cf: manual pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manual pending`""
Add-Line "				set `"cf: manual active`""
Add-Line "			``Your mining company has finished its first operating schedule. Claim profit will now be split according to the payout share set at headquarters.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-MiningDailyAccountingLines
Add-Line ""
Add-Line "mission `"Company Foundations: Trading Manual Operations`""
Add-Line "	name `"Trading Company Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: trading`""
Add-Line "		has `"cf: manual`""
Add-Line "		has `"cf: manual pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manual pending`""
Add-Line "				set `"cf: manual active`""
Add-Line "			``Your trading company has finished its first operating schedule. Operating profit will now be split according to the payout share set at headquarters.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-TradingDailyAccountingLines
Add-Line ""
Add-Line "mission `"Company Foundations: Security Manual Operations`""
Add-Line "	name `"Security Company Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: security`""
Add-Line "		has `"cf: manual`""
Add-Line "		has `"cf: manual pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manual pending`""
Add-Line "				set `"cf: manual active`""
Add-Line "			``Your security company has finished its first operating schedule. Operating profit will now be split according to the payout share set at headquarters.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-SecurityDailyAccountingLines
Add-Line ""
Add-Line "mission `"Company Foundations: Shuttle Managed Operations`""
Add-Line "	name `"Shuttle Manager Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: shuttle`""
Add-Line "		has `"cf: managed`""
Add-Line "		has `"cf: manager pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manager pending`""
Add-Line "				set `"cf: manager active`""
Add-Line "			``Your shuttle manager files the first autonomous operating plan. From now on, the company pays 10,000 credits per day for management and follows your payout policy while the manager reinvests retained reserve when there is at least twice the required purchase cost available.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-ShuttleDailyAccountingLines -ManagerCost 10000
Add-Line "		clear `"cf: manager salary checked`""
Add-Line ""
Add-Line "mission `"Company Foundations: Mining Managed Operations`""
Add-Line "	name `"Mining Manager Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: mining`""
Add-Line "		has `"cf: managed`""
Add-Line "		has `"cf: manager pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manager pending`""
Add-Line "				set `"cf: manager active`""
Add-Line "			``Your mining manager files the first autonomous operating plan. From now on, the company pays 10,000 credits per day for management, follows your payout policy, and reinvests retained reserve into mining rights, Sunders, and drones when the balance allows it.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-MiningDailyAccountingLines -ManagerCost 10000
Add-Line "		clear `"cf: manager salary checked`""
Add-Line ""
Add-Line "mission `"Company Foundations: Trading Managed Operations`""
Add-Line "	name `"Trading Manager Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: trading`""
Add-Line "		has `"cf: managed`""
Add-Line "		has `"cf: manager pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manager pending`""
Add-Line "				set `"cf: manager active`""
Add-Line "			``Your trading manager files the first autonomous operating plan. From now on, manager salary is a fixed operating cost before any owner payout is calculated.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-TradingDailyAccountingLines -ManagerCost 10000
Add-Line "		clear `"cf: manager salary checked`""
Add-Line ""
Add-Line "mission `"Company Foundations: Security Managed Operations`""
Add-Line "	name `"Security Manager Operations`""
Add-Line "	invisible"
Add-Line "	landing"
Add-Line "	repeat"
Add-Line "	to offer"
Add-Line "		has `"cf: security`""
Add-Line "		has `"cf: managed`""
Add-Line "		has `"cf: manager pending`""
Add-Line "		not `"cf: hq suspended`""
Add-Line "	to complete"
Add-Line "		never"
Add-Line "	on offer"
Add-Line "		conversation"
Add-Line "			action"
Add-Line "				clear `"cf: manager pending`""
Add-Line "				set `"cf: manager active`""
Add-Line "			``Your security manager files the first autonomous operating plan. From now on, manager salary is a fixed operating cost before any owner payout is calculated.``"
Add-Line "				accept"
Add-Line "	on daily"
Add-Line "		`"cf: days operated`" ++"
Add-SecurityDailyAccountingLines -ManagerCost 10000
Add-Line "		clear `"cf: manager salary checked`""

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
if(-not (Test-Path -LiteralPath $outputRoot)) {
    New-Item -ItemType Directory -Path $outputRoot | Out-Null
}

function Add-FailToActionOnlyInvisibleLandingMissions {
    param([System.Collections.Generic.List[string]]$Lines)

    $result = New-Object System.Collections.Generic.List[string]
    $block = New-Object System.Collections.Generic.List[string]

    function Flush-CompanyMissionBlock {
        param(
            [System.Collections.Generic.List[string]]$Source,
            [System.Collections.Generic.List[string]]$Target
        )

        if($Source.Count -eq 0) {
            return
        }

        $isInvisible = $false
        $isLanding = $false
        $offerStart = -1
        $offerEnd = $Source.Count
        for($i = 0; $i -lt $Source.Count; $i++) {
            $line = $Source[$i]
            if($line -eq "	invisible") { $isInvisible = $true }
            if($line -eq "	landing") { $isLanding = $true }
            if($line -eq "	on offer") {
                $offerStart = $i
                for($j = $i + 1; $j -lt $Source.Count; $j++) {
                    if($Source[$j] -match '^	(?!	)') {
                        $offerEnd = $j
                        break
                    }
                }
            }
        }

        $shouldAddFail = $false
        if($isInvisible -and $isLanding -and $offerStart -ge 0) {
            $hasInteractiveOffer = $false
            $hasTerminalOffer = $false
            for($i = $offerStart + 1; $i -lt $offerEnd; $i++) {
                $line = $Source[$i]
                if($line -match '^		conversation($|\s)' -or $line -match '^		dialog($|\s)') {
                    $hasInteractiveOffer = $true
                }
                if($line -match '^		(fail|complete)($|\s)') {
                    $hasTerminalOffer = $true
                }
            }
            $shouldAddFail = (-not $hasInteractiveOffer) -and (-not $hasTerminalOffer)
        }

        for($i = 0; $i -lt $Source.Count; $i++) {
            if($shouldAddFail -and $i -eq $offerEnd) {
                $Target.Add("		fail")
            }
            $Target.Add($Source[$i])
        }
        if($shouldAddFail -and $offerEnd -eq $Source.Count) {
            $Target.Add("		fail")
        }
    }

    foreach($line in $Lines) {
        if($line.StartsWith("mission `"") -and $block.Count -gt 0) {
            Flush-CompanyMissionBlock $block $result
            $block.Clear()
        }
        $block.Add($line)
    }
    Flush-CompanyMissionBlock $block $result
    return $result
}

foreach($sectionName in @($outputSections.Keys)) {
    $outputSections[$sectionName] = Add-FailToActionOnlyInvisibleLandingMissions $outputSections[$sectionName]
}

function Split-CompanyStationSiteEvents {
    param([System.Collections.Specialized.OrderedDictionary]$Sections)

    if(-not $Sections.Contains("company stations.txt")) {
        return
    }

    $rootLines = New-Object System.Collections.Generic.List[string]
    $eventLines = $null
    $eventSystem = ""

    function Flush-StationSiteEvent {
        param(
            [string]$SystemName,
            [System.Collections.Generic.List[string]]$Lines,
            [System.Collections.Specialized.OrderedDictionary]$TargetSections
        )

        if(-not $Lines -or $Lines.Count -eq 0) {
            return
        }

        $safeName = $SystemName -replace '[\\/:*?"<>|]', '_'
        $sectionName = "company station sites/$safeName.txt"
        $sectionLines = New-Object System.Collections.Generic.List[string]
        $sectionLines.Add("# Company Foundations")
        $sectionLines.Add("")
        foreach($line in $Lines) {
            $sectionLines.Add($line)
        }
        $TargetSections[$sectionName] = $sectionLines
    }

    foreach($line in $Sections["company stations.txt"]) {
        if($line -match '^event "Company Foundations: Station Site: (.+)"$') {
            Flush-StationSiteEvent $eventSystem $eventLines $Sections
            $eventSystem = $matches[1]
            $eventLines = New-Object System.Collections.Generic.List[string]
            $eventLines.Add($line)
            continue
        }

        if($null -ne $eventLines) {
            if($line -match '^event "Company Foundations: Station Stage ') {
                Flush-StationSiteEvent $eventSystem $eventLines $Sections
                $eventSystem = ""
                $eventLines = $null
                $rootLines.Add($line)
            } else {
                $eventLines.Add($line)
            }
            continue
        }

        $rootLines.Add($line)
    }

    Flush-StationSiteEvent $eventSystem $eventLines $Sections
    $Sections["company stations.txt"] = $rootLines
}

Split-CompanyStationSiteEvents $outputSections

Get-ChildItem -LiteralPath $outputRoot -Filter "company *.txt" | Remove-Item -Force
$stationSiteRoot = Join-Path $outputRoot "company station sites"
if(Test-Path -LiteralPath $stationSiteRoot) {
    Remove-Item -LiteralPath $stationSiteRoot -Recurse -Force
}

$indexLines = New-Object System.Collections.Generic.List[string]
$indexLines.Add("# Company Foundations")
$indexLines.Add("# Plugin data is split across the files listed below.")
$indexLines.Add("")
foreach($sectionName in $outputSections.Keys) {
    $indexLines.Add("# - $sectionName")
}
[System.IO.File]::WriteAllLines($OutFile, $indexLines, $utf8NoBom)

foreach($sectionName in $outputSections.Keys) {
    $sectionPath = Join-Path $outputRoot $sectionName
    $sectionDirectory = Split-Path -Parent $sectionPath
    if(-not (Test-Path -LiteralPath $sectionDirectory)) {
        New-Item -ItemType Directory -Path $sectionDirectory | Out-Null
    }
    [System.IO.File]::WriteAllLines($sectionPath, $outputSections[$sectionName], $utf8NoBom)
}

Write-Host "Wrote $($eligible.Count) eligible headquarters into $($outputSections.Count) split data files in $outputRoot"
