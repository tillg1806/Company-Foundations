[CmdletBinding()]
param(
    [string]$SavePath = "",
    [string]$LogPath = "",
    [ValidateRange(1, 3600)]
    [int]$IntervalSeconds = 2,
    [switch]$Once,
    [switch]$IncludeAllConditions
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pluginRoot = Split-Path -Parent $PSScriptRoot

function Get-LocationMaps {
    $maps = [ordered]@{
        Headquarters = @{}
        Stations = @{}
        AdmiralHeadquartersId = 0
    }
    $mapPath = Join-Path $pluginRoot "data\company ids.txt"
    if(-not (Test-Path -LiteralPath $mapPath -PathType Leaf)) {
        return $maps
    }
    foreach($line in [System.IO.File]::ReadLines($mapPath)) {
        if($line -match '^# hq (?<id>\d+)\t(?<name>.+)$') {
            $maps.Headquarters[[long]$Matches['id']] = $Matches['name']
        } elseif($line -match '^# station (?<id>\d+)\t(?<name>.+)$') {
            $maps.Stations[[long]$Matches['id']] = $Matches['name']
        } elseif($line -match '^# admiral headquarters (?<id>\d+)$') {
            $maps.AdmiralHeadquartersId = [long]$Matches['id']
        }
    }
    return $maps
}

$locationMaps = Get-LocationMaps

function Get-DefaultSavePath {
    $saveRoot = Join-Path $env:APPDATA "endless-sky\saves"
    $save = Get-ChildItem -LiteralPath $saveRoot -File -Filter "*.txt" |
        Where-Object { $_.Name -notlike "*~*" } |
        Sort-Object LastWriteTimeUtc -Descending |
        Select-Object -First 1

    if($null -eq $save) {
        throw "No Endless Sky save file was found in '$saveRoot'."
    }
    return $save.FullName
}

function Get-ConditionValue {
    param(
        [System.Collections.IDictionary]$Conditions,
        [string]$Name
    )

    if($Conditions.Contains($Name)) {
        return [long]$Conditions[$Name]
    }
    return [long]0
}

function Get-CompanySnapshot {
    param(
        [string]$Path,
        [bool]$WithAllConditions
    )

    $lines = [System.IO.File]::ReadAllLines($Path)
    $conditions = [ordered]@{}
    $inConditions = $false
    $date = ""
    $system = ""
    $planet = ""
    $activeOperations = New-Object System.Collections.Generic.List[string]

    foreach($line in $lines) {
        if($date -eq "" -and $line -match '^date\s+(\d+)\s+(\d+)\s+(\d+)\s*$') {
            $date = "$($Matches[1]).$($Matches[2]).$($Matches[3])"
            continue
        }
        if($system -eq "" -and $line -match '^system\s+(.+?)\s*$') {
            $system = $Matches[1].Trim('"')
            continue
        }
        if($planet -eq "" -and $line -match '^planet\s+(.+?)\s*$') {
            $planet = $Matches[1].Trim('"')
            continue
        }
        if($line -match '^mission\s+"(Company Foundations: (?:(?:Company|Shuttle|Mining|Trading|Security) (?:Manual|Managed) Operations))"\s*$') {
            $activeOperations.Add($Matches[1])
            continue
        }
        if($line -eq "conditions") {
            $inConditions = $true
            continue
        }
        if(-not $inConditions) {
            continue
        }
        if($line -notmatch '^\s') {
            break
        }
        if($line -match '^\t"(?<name>cf:[^"]+)"(?:\s+(?<value>-?\d+))?\s*$') {
            $value = if($Matches['value']) { [long]$Matches['value'] } else { [long]1 }
            $conditions[$Matches['name']] = $value
        }
    }

    $trackedNames = @(
        "cf: active", "cf: hq suspended", "cf: distress open",
        "cf: hq id", "cf: hq station system id",
        "cf: admiral location id", "cf: admiral destination id",
        "cf: save schema", "cf: station economics v2", "cf: hq offers v3",
        "cf: shuttle route book v2",
        "cf: manual", "cf: managed", "cf: manual pending", "cf: manager pending",
        "cf: manual active", "cf: manager active", "cf: operations accounting v3",
        "cf: shuttle", "cf: mining", "cf: trading", "cf: security",
        "cf: days operated", "cf: audit schema", "cf: audit sequence", "cf: audit last day",
        "cf: reserve", "cf: owner payable", "cf: last gross", "cf: last expenses",
        "cf: last net profit", "cf: last retained earnings", "cf: manager daily cost",
        "cf: hq daily tax", "cf: total gross", "cf: total operating expenses",
        "cf: total net profit", "cf: month gross", "cf: month expenses",
        "cf: month net profit", "cf: last sale proceeds"
    )
    $tracked = [ordered]@{}
    foreach($name in $trackedNames) {
        $tracked[$name.Substring(4)] = Get-ConditionValue $conditions $name
    }

    $headquarters = New-Object System.Collections.Generic.List[string]
    $hqId = Get-ConditionValue $conditions "cf: hq id"
    if($hqId -gt 0 -and $locationMaps.Headquarters.Contains($hqId)) {
        $headquarters.Add($locationMaps.Headquarters[$hqId])
    } else {
        foreach($legacyName in @($conditions.Keys | Where-Object { $_ -like "cf: hq: *" })) {
            $headquarters.Add($legacyName.Substring(8))
        }
    }
    $stationSystemId = Get-ConditionValue $conditions "cf: hq station system id"
    if((Get-ConditionValue $conditions "cf: hq station built") -ne 0 -and $locationMaps.Stations.Contains($stationSystemId)) {
        $headquarters.Add("Company Headquarters ($($locationMaps.Stations[$stationSystemId]))")
    }
    $divisions = @("shuttle", "mining", "trading", "security") |
        Where-Object { (Get-ConditionValue $conditions "cf: $_") -ne 0 }

    $anomalies = New-Object System.Collections.Generic.List[string]
    $risks = New-Object System.Collections.Generic.List[string]
    $isActive = (Get-ConditionValue $conditions "cf: active") -ne 0
    $isSuspended = (Get-ConditionValue $conditions "cf: hq suspended") -ne 0
    $manual = (Get-ConditionValue $conditions "cf: manual") -ne 0
    $managed = (Get-ConditionValue $conditions "cf: managed") -ne 0
    $manualActive = (Get-ConditionValue $conditions "cf: manual active") -ne 0
    $managerActive = (Get-ConditionValue $conditions "cf: manager active") -ne 0
    $legacyOperations = @($activeOperations | Where-Object { $_ -notlike "Company Foundations: Company *" })

    if($isActive -and ($manual -eq $managed)) {
        $anomalies.Add("An active company must have exactly one management mode.")
    }
    if($activeOperations.Count -gt 1) {
        $anomalies.Add("More than one daily operations mission is active.")
    }
    if($legacyOperations.Count -gt 0) {
        $anomalies.Add("A legacy division-specific operations mission is still active.")
    }
    if($isActive -and -not $isSuspended -and ($manualActive -or $managerActive) -and $activeOperations.Count -ne 1) {
        $anomalies.Add("The active operations flag does not match one running daily mission.")
    }
    $lastGross = Get-ConditionValue $conditions "cf: last gross"
    $lastExpenses = Get-ConditionValue $conditions "cf: last expenses"
    $lastNet = Get-ConditionValue $conditions "cf: last net profit"
    if($isActive -and $lastNet -ne ($lastGross - $lastExpenses)) {
        $anomalies.Add("Last net profit does not equal gross minus expenses.")
    }
    if((Get-ConditionValue $conditions "cf: reserve") -lt 0) {
        $risks.Add("Company reserve is negative; the company is operating in distress.")
    }
    if((Get-ConditionValue $conditions "cf: distress open") -ne 0) {
        $risks.Add("An operating-loss file is open.")
    }
    if((Get-ConditionValue $conditions "cf: audit schema") -ge 1) {
        $auditDay = Get-ConditionValue $conditions "cf: audit last day"
        $daysOperated = Get-ConditionValue $conditions "cf: days operated"
        if(($manualActive -or $managerActive) -and $auditDay -ne $daysOperated) {
            $anomalies.Add("The audit day is out of sync with days operated.")
        }
    }

    $snapshot = [ordered]@{
        gameDate = $date
        system = $system
        planet = $planet
        headquarters = @($headquarters)
        divisions = @($divisions)
        activeOperations = @($activeOperations)
        state = $tracked
        risks = @($risks)
        anomalies = @($anomalies)
    }
    if($WithAllConditions) {
        $snapshot["conditions"] = $conditions
    }
    return $snapshot
}

function Get-SnapshotChanges {
    param(
        [System.Collections.IDictionary]$Before,
        [System.Collections.IDictionary]$After
    )

    $changes = [ordered]@{}
    foreach($key in $After.state.Keys) {
        if($Before.state[$key] -ne $After.state[$key]) {
            $changes[$key] = [ordered]@{ from = $Before.state[$key]; to = $After.state[$key] }
        }
    }
    foreach($key in @("gameDate", "system", "planet")) {
        if($Before[$key] -ne $After[$key]) {
            $changes[$key] = [ordered]@{ from = $Before[$key]; to = $After[$key] }
        }
    }
    foreach($key in @("headquarters", "divisions", "activeOperations", "risks", "anomalies")) {
        $oldValue = $Before[$key] -join "|"
        $newValue = $After[$key] -join "|"
        if($oldValue -ne $newValue) {
            $changes[$key] = [ordered]@{ from = @($Before[$key]); to = @($After[$key]) }
        }
    }
    return $changes
}

function Write-JsonLine {
    param(
        [string]$Path,
        [object]$Value
    )

    $directory = Split-Path -Parent $Path
    if(-not [string]::IsNullOrWhiteSpace($directory)) {
        [System.IO.Directory]::CreateDirectory($directory) | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth 8 -Compress
    $encoding = New-Object System.Text.UTF8Encoding($false)
    $writer = New-Object System.IO.StreamWriter($Path, $true, $encoding)
    try {
        $writer.WriteLine($json)
    } finally {
        $writer.Dispose()
    }
}

if([string]::IsNullOrWhiteSpace($SavePath)) {
    $SavePath = Get-DefaultSavePath
}
$SavePath = [System.IO.Path]::GetFullPath($SavePath)
if(-not (Test-Path -LiteralPath $SavePath -PathType Leaf)) {
    throw "Save file '$SavePath' does not exist."
}

if([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $pluginRoot "logs\company-foundations.jsonl"
}
$LogPath = [System.IO.Path]::GetFullPath($LogPath)

Write-Host "Watching Company Foundations state in: $SavePath"
Write-Host "Writing JSONL audit events to: $LogPath"

$previousSnapshot = $null
$previousWriteTime = [datetime]::MinValue

do {
    try {
        $saveInfo = Get-Item -LiteralPath $SavePath
        if($Once -or $saveInfo.LastWriteTimeUtc -ne $previousWriteTime) {
            $snapshot = Get-CompanySnapshot $SavePath $IncludeAllConditions.IsPresent
            $changes = if($null -eq $previousSnapshot) { [ordered]@{} } else { Get-SnapshotChanges $previousSnapshot $snapshot }
            $event = [ordered]@{
                observedAtUtc = [datetime]::UtcNow.ToString("o")
                event = if($null -eq $previousSnapshot) { "baseline" } else { "state-change" }
                savePath = $SavePath
                saveLastWriteUtc = $saveInfo.LastWriteTimeUtc.ToString("o")
                changes = $changes
                snapshot = $snapshot
            }
            Write-JsonLine $LogPath $event
            $previousSnapshot = $snapshot
            $previousWriteTime = $saveInfo.LastWriteTimeUtc

            $summary = "{0}: day={1}, reserve={2:N0}, net={3:N0}, divisions={4}, risks={5}, anomalies={6}" -f `
                $event.event, $snapshot.state['days operated'], $snapshot.state.reserve, `
                $snapshot.state['last net profit'], ($snapshot.divisions -join ","), $snapshot.risks.Count, $snapshot.anomalies.Count
            Write-Host $summary
        }
    } catch [System.IO.IOException] {
        Write-Warning "The save is currently being written; retrying on the next interval."
    } catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning "The save is temporarily unavailable; retrying on the next interval."
    }

    if(-not $Once) {
        Start-Sleep -Seconds $IntervalSeconds
    }
} while(-not $Once)
