[CmdletBinding()]
param(
    [string]$DataRoot = "",
    [string]$EndlessSkyExecutable = "",
    [string]$SaveRoot = "",
    [switch]$Regenerate,
    [switch]$ParseAssets
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$pluginRoot = Split-Path -Parent $PSScriptRoot
$localConfigPath = Join-Path $PSScriptRoot "company_foundations.local.ps1"
if(Test-Path -LiteralPath $localConfigPath) {
    . $localConfigPath
}

$failures = New-Object System.Collections.Generic.List[string]
function Add-Failure([string]$Message) {
    $failures.Add($Message)
}

function Get-MissionBlock {
    param(
        [string]$Text,
        [string]$Name
    )

    $escapedName = [regex]::Escape($Name)
    $pattern = '(?ms)^mission "{0}"\r?\n.*?(?=^mission |\z)' -f $escapedName
    return [regex]::Match($Text, $pattern).Value
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$Path
    )

    $baseFullPath = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\', '/') + [System.IO.Path]::DirectorySeparatorChar
    $baseUri = New-Object System.Uri($baseFullPath)
    $pathUri = New-Object System.Uri([System.IO.Path]::GetFullPath($Path))
    return [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($pathUri).ToString()).Replace('/', [System.IO.Path]::DirectorySeparatorChar)
}

$scripts = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter "*.ps1" -File)
foreach($script in $scripts) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $script.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null
    foreach($parseError in $parseErrors) {
        Add-Failure "$($script.Name):$($parseError.Extent.StartLineNumber): $($parseError.Message)"
    }
}

$pluginDataRoot = Join-Path $pluginRoot "data"
$dataFiles = @(Get-ChildItem -LiteralPath $pluginDataRoot -Filter "*.txt" -File -Recurse)
$definitions = @{
    mission = @{}
    event = @{}
}
function Test-ConversationTargets {
    param(
        [string]$RelativePath,
        [string]$Definition,
        [System.Collections.Generic.HashSet[string]]$Labels,
        [System.Collections.Generic.HashSet[string]]$Gotos
    )

    foreach($target in $Gotos) {
        if(-not $Labels.Contains($target)) {
            Add-Failure "Missing conversation label '$target' in '$Definition' ($RelativePath)."
        }
    }
}

foreach($file in $dataFiles) {
    $relativePath = Get-RelativePath $pluginRoot $file.FullName
    $labels = New-Object System.Collections.Generic.HashSet[string]
    $gotos = New-Object System.Collections.Generic.HashSet[string]
    $currentMission = ""
    foreach($line in [System.IO.File]::ReadLines($file.FullName)) {
        if($line -match '^\S' -and $line -notmatch '^\s*#') {
            if($currentMission -ne "") {
                Test-ConversationTargets $relativePath $currentMission $labels $gotos
                $labels = New-Object System.Collections.Generic.HashSet[string]
                $gotos = New-Object System.Collections.Generic.HashSet[string]
                $currentMission = ""
            }
        }
        foreach($kind in @("mission", "event")) {
            if($line -match "^$kind\s+[`"](?<name>.+?)[`"]\s*$") {
                $name = $Matches['name']
                if($definitions[$kind].ContainsKey($name)) {
                    Add-Failure "Duplicate $kind '$name' in $relativePath and $($definitions[$kind][$name])."
                } else {
                    $definitions[$kind][$name] = $relativePath
                }
                if($kind -eq "mission") {
                    $currentMission = $name
                }
            }
        }
        if($currentMission -ne "" -and $line -match '^\s+label\s+[`"](?<name>.+?)[`"]\s*$') {
            if(-not $labels.Add($Matches['name'])) {
                Add-Failure "Duplicate conversation label '$($Matches['name'])' in '$currentMission' ($relativePath)."
            }
        } elseif($currentMission -ne "" -and $line -match '^\s+goto\s+[`"](?<name>.+?)[`"]\s*$') {
            [void]$gotos.Add($Matches['name'])
        }
    }
    if($currentMission -ne "") {
        Test-ConversationTargets $relativePath $currentMission $labels $gotos
    }
}

$allDataText = ($dataFiles | ForEach-Object { [System.IO.File]::ReadAllText($_.FullName) }) -join "`n"
$migrationPath = Join-Path $pluginDataRoot "company migrations.txt"
$operationsPath = Join-Path $pluginDataRoot "company operations.txt"
$idsPath = Join-Path $pluginDataRoot "company ids.txt"
$migrationText = ""
$operationsText = ""
$legacyOperations = @(
    foreach($division in @("Shuttle", "Mining", "Trading", "Security")) {
        foreach($mode in @("Manual", "Managed")) {
            "Company Foundations: $division $mode Operations"
            "Company Foundations: Repair $division $mode Operations"
        }
    }
)
if(-not (Test-Path -LiteralPath $migrationPath)) {
    Add-Failure "Missing generated save migration data."
} elseif(-not (Test-Path -LiteralPath $idsPath)) {
    Add-Failure "Missing persistent location ID map."
} else {
    $migrationText = [System.IO.File]::ReadAllText($migrationPath)
    $idsText = [System.IO.File]::ReadAllText($idsPath)

    $hqMappings = @([regex]::Matches($idsText, '(?m)^# hq (?<id>\d+)\t(?<name>.+)$'))
    $stationMappings = @([regex]::Matches($idsText, '(?m)^# station (?<id>\d+)\t(?<name>.+)$'))
    if($hqMappings.Count -eq 0 -or $stationMappings.Count -eq 0) {
        Add-Failure "Persistent location ID map is empty."
    }
    foreach($mapping in $hqMappings) {
        $name = $mapping.Groups['name'].Value.TrimEnd("`r")
        $id = $mapping.Groups['id'].Value
        $block = Get-MissionBlock $migrationText "Company Foundations: Migrate Headquarters: $name"
        if($block -notmatch [regex]::Escape("has `"cf: hq: $name`"") -or
            $block -notmatch [regex]::Escape("`"cf: hq id`" = $id")) {
            Add-Failure "Missing v0.1 headquarters migration for '$name' (ID $id)."
        }
        foreach($kind in @("Location", "Destination")) {
            $conditionKind = $kind.ToLowerInvariant()
            $block = Get-MissionBlock $migrationText "Company Foundations: Migrate Admiral ${kind}: $name"
            if($block -notmatch [regex]::Escape("has `"cf: admiral ${conditionKind}: $name`"") -or
                $block -notmatch [regex]::Escape("`"cf: admiral ${conditionKind} id`" = $id")) {
                Add-Failure "Missing v0.1 admiral $conditionKind migration for '$name' (ID $id)."
            }
        }
    }
    foreach($mapping in $stationMappings) {
        $name = $mapping.Groups['name'].Value.TrimEnd("`r")
        $id = $mapping.Groups['id'].Value
        $block = Get-MissionBlock $migrationText "Company Foundations: Migrate Station System: $name"
        if($block -notmatch [regex]::Escape("has `"cf: hq station system: $name`"") -or
            $block -notmatch [regex]::Escape("`"cf: hq station system id`" = $id")) {
            Add-Failure "Missing v0.1 headquarters-station migration for '$name' (ID $id)."
        }
    }

    $stationMigration = Get-MissionBlock $migrationText "Company Foundations: Migrate Station Economics V2"
    foreach($expectedAction in @(
        '"cf: station daily income" = "cf: station orbital office" * 5000',
        '"cf: station daily income" += "cf: station logistics hub" * 16000',
        '"cf: station daily income" += "cf: station industrial dock" * 47000',
        '"cf: station daily upkeep" = "cf: station orbital office" * 2000',
        '"cf: station daily upkeep" += "cf: station logistics hub" * 6000',
        '"cf: station daily upkeep" += "cf: station industrial dock" * 17000',
        'set "cf: station economics v2"'
    )) {
        if(-not $stationMigration.Contains($expectedAction)) {
            Add-Failure "Station save migration is missing: $expectedAction"
        }
    }
    foreach($preservedCondition in @("cf: reserve", "cf: total station revenue", "cf: total station upkeep")) {
        $preservedPattern = '(?m)^\s+"{0}"\s*(?:=|\+=|-=)' -f [regex]::Escape($preservedCondition)
        if($stationMigration -match $preservedPattern) {
            Add-Failure "Station save migration must preserve '$preservedCondition'."
        }
    }

    $schemaMigration = Get-MissionBlock $migrationText "Company Foundations: Finalize Save Schema V2"
    foreach($expected in @(
        '"cf: save schema" < 2',
        '"cf: hq id" > 0',
        'has "cf: operations accounting v3"',
        'has "cf: hq offers v3"',
        'has "cf: station economics v2"',
        '"cf: save schema" = 2'
    )) {
        if(-not $schemaMigration.Contains($expected)) {
            Add-Failure "Save-schema finalizer is missing: $expected"
        }
    }
}

if(Test-Path -LiteralPath $operationsPath) {
    $operationsText = [System.IO.File]::ReadAllText($operationsPath)
    foreach($missionName in $legacyOperations) {
        if(-not $operationsText.Contains("fail `"$missionName`"")) {
            Add-Failure "Unified accounting migration does not stop legacy mission '$missionName'."
        }
        foreach($suffix in @("failed", "offered", "done", "declined")) {
            if(-not $operationsText.Contains("clear `"$missionName`: $suffix`"")) {
                Add-Failure "Unified accounting migration does not clear '$missionName`: $suffix'."
            }
        }
    }
}

$auditedSaveCount = 0
if(-not [string]::IsNullOrWhiteSpace($SaveRoot)) {
    if(-not (Test-Path -LiteralPath $SaveRoot -PathType Container)) {
        Add-Failure "Save directory does not exist: $SaveRoot"
    } else {
        foreach($saveFile in @(Get-ChildItem -LiteralPath $SaveRoot -File)) {
            $lines = [System.IO.File]::ReadAllLines($saveFile.FullName)
            $conditionsStart = [array]::IndexOf($lines, "conditions")
            if($conditionsStart -lt 0) {
                continue
            }
            $conditions = @{}
            for($lineIndex = $conditionsStart + 1; $lineIndex -lt $lines.Count; $lineIndex++) {
                $line = $lines[$lineIndex]
                if(-not $line.StartsWith("`t") -and -not [string]::IsNullOrWhiteSpace($line)) {
                    break
                }
                if($line -match '^\s*"(?<name>cf: [^"]+)"(?:\s+(?<value>-?\d+))?\s*$') {
                    $value = if($Matches['value']) { [long]$Matches['value'] } else { 1L }
                    if($value -gt 0) {
                        $conditions[$Matches['name']] = $value
                    }
                }
            }
            if(-not $conditions.ContainsKey("cf: active")) {
                continue
            }
            $auditedSaveCount++

            if(-not $conditions.ContainsKey("cf: hq id")) {
                $legacyHeadquarters = @($conditions.Keys | Where-Object { $_ -like "cf: hq: *" })
                if($conditions.ContainsKey("cf: hq station built")) {
                    $legacyHeadquarters = @($legacyHeadquarters | Where-Object { $_ -ne "cf: hq: Company Headquarters" })
                    $legacyStationSystems = @($conditions.Keys | Where-Object { $_ -like "cf: hq station system: *" })
                    if($legacyStationSystems.Count -ne 1) {
                        Add-Failure "$($saveFile.Name): station company has no unique v0.1 station-system location."
                    } else {
                        $systemName = $legacyStationSystems[0].Substring("cf: hq station system: ".Length)
                        if([string]::IsNullOrWhiteSpace((Get-MissionBlock $migrationText "Company Foundations: Migrate Station System: $systemName"))) {
                            Add-Failure "$($saveFile.Name): no migration exists for station system '$systemName'."
                        }
                    }
                } elseif($legacyHeadquarters.Count -ne 1) {
                    Add-Failure "$($saveFile.Name): active company has no unique v0.1 headquarters location."
                } else {
                    $headquartersName = $legacyHeadquarters[0].Substring("cf: hq: ".Length)
                    if([string]::IsNullOrWhiteSpace((Get-MissionBlock $migrationText "Company Foundations: Migrate Headquarters: $headquartersName"))) {
                        Add-Failure "$($saveFile.Name): no migration exists for headquarters '$headquartersName'."
                    }
                }
            }

            if($conditions.ContainsKey("cf: security admiral") -and
                -not $conditions.ContainsKey("cf: admiral location id")) {
                $legacyLocations = @($conditions.Keys | Where-Object { $_ -like "cf: admiral location: *" })
                if($legacyLocations.Count -ne 1) {
                    Add-Failure "$($saveFile.Name): fleet admiral has no unique v0.1 location."
                }
            }
            if($conditions.ContainsKey("cf: admiral in transit") -and
                -not $conditions.ContainsKey("cf: admiral destination id")) {
                $legacyDestinations = @($conditions.Keys | Where-Object { $_ -like "cf: admiral destination: *" })
                if($legacyDestinations.Count -ne 1) {
                    Add-Failure "$($saveFile.Name): fleet admiral has no unique v0.1 destination."
                }
            }

            foreach($line in $lines) {
                if($line -match '^mission "(?<name>Company Foundations: [^"]+)"$' -and
                    $Matches['name'] -in $legacyOperations -and
                    -not $operationsText.Contains("fail `"$($Matches['name'])`"")) {
                    Add-Failure "$($saveFile.Name): active legacy operation '$($Matches['name'])' is not stopped by the migration."
                }
            }
        }
    }
}

$legacyClearCount = ([regex]::Matches(
    $allDataText,
    'clear "(?:cf: hq:|cf: hq station system:|cf: admiral location:|cf: admiral destination:)'
)).Count
if($legacyClearCount -gt 1500) {
    Add-Failure "Legacy one-hot location cleanup regressed ($legacyClearCount clear operations)."
}

$knownSystemReads = ([regex]::Matches($allDataText, '(?:has|not) "cf: known system:')).Count
if($knownSystemReads -gt 0) {
    Add-Failure "Found $knownSystemReads custom known-system reads; use native 'visited system:' conditions."
}

$shipReads = @([regex]::Matches($allDataText, '(?:has|not) "cf: ship available: (?<name>[^"]+)"') |
    ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
$shipWrites = @([regex]::Matches($allDataText, 'set "cf: ship available: (?<name>[^"]+)"') |
    ForEach-Object { $_.Groups['name'].Value } | Sort-Object -Unique)
foreach($ship in $shipReads) {
    if($ship -notin $shipWrites) {
        Add-Failure "Ship availability '$ship' is read but never discovered or backfilled."
    }
}

$foundingPath = Join-Path $pluginDataRoot "company founding.txt"
if(Test-Path -LiteralPath $foundingPath) {
    $foundingText = [System.IO.File]::ReadAllText($foundingPath)
    $foundingBlocks = @([regex]::Split($foundingText, '(?m)(?=^mission "Company Foundations: Registrar:)') |
        Where-Object { $_ -match '^mission "Company Foundations: Registrar:' })
    foreach($block in $foundingBlocks) {
        $name = [regex]::Match(
            $block,
            '^mission "Company Foundations: Registrar: (?<name>.+)"',
            [System.Text.RegularExpressions.RegexOptions]::Multiline
        ).Groups['name'].Value
        $tax = [int][regex]::Match($block, '"cf: hq base tax" = (?<value>\d+)').Groups['value'].Value
        $shuttlePayout = [int][regex]::Match($block, '"cf: shuttle local trip payout" = (?<value>\d+)').Groups['value'].Value
        $miningPayout = [int][regex]::Match($block, '"cf: mining local trip payout" = (?<value>\d+)').Groups['value'].Value
        $tradingPayout = [int][regex]::Match($block, '"cf: trading local trip payout" = (?<value>\d+)').Groups['value'].Value
        $securityPayout = [int][regex]::Match($block, '"cf: security local trip payout" = (?<value>\d+)').Groups['value'].Value
        if(([regex]::Matches($block, '"cf: save schema" = 2')).Count -ne 4) {
            Add-Failure "Registrar '$name' does not initialize save schema 2 for every charter."
        }
        if(([regex]::Matches($block, 'set "cf: station economics v2"')).Count -ne 4) {
            Add-Failure "Registrar '$name' does not initialize station economics v2 for every charter."
        }
        $startingNets = [ordered]@{
            Shuttle = ($shuttlePayout / 4) - 100 - $tax - 5
            Mining = ($miningPayout / 3) - 300 - 100 - $tax - 20
            Trading = ($tradingPayout / 4) - 100 - $tax - 5
            Security = ($securityPayout / 4) - 600 - 200 - $tax - 60
        }
        foreach($role in $startingNets.Keys) {
            if($startingNets[$role] -lt 0) {
                Add-Failure "$role charter on '$name' starts at a projected daily loss of $($startingNets[$role])."
            }
        }
    }
}

$totalDataBytes = ($dataFiles | Measure-Object Length -Sum).Sum
if($totalDataBytes -gt 25MB) {
    Add-Failure "Generated data is unexpectedly large: $([math]::Round($totalDataBytes / 1MB, 2)) MiB."
}

if($Regenerate) {
    $temporaryRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("company-foundations-test-" + [guid]::NewGuid().ToString("N"))
    $temporaryData = Join-Path $temporaryRoot "data"
    [System.IO.Directory]::CreateDirectory($temporaryData) | Out-Null
    try {
        $arguments = @{
            OutFile = Join-Path $temporaryData "company foundations.txt"
        }
        if(-not [string]::IsNullOrWhiteSpace($DataRoot)) {
            $arguments.DataRoot = $DataRoot
        }
        & (Join-Path $PSScriptRoot "generate_company_foundations.ps1") @arguments

        $generatedFiles = @(Get-ChildItem -LiteralPath $temporaryData -Filter "*.txt" -File -Recurse)
        $expectedRelative = @($dataFiles | ForEach-Object {
            Get-RelativePath $pluginDataRoot $_.FullName
        } | Sort-Object)
        $actualRelative = @($generatedFiles | ForEach-Object {
            Get-RelativePath $temporaryData $_.FullName
        } | Sort-Object)
        if(($expectedRelative -join "|") -ne ($actualRelative -join "|")) {
            Add-Failure "Regeneration produced a different file list."
        } else {
            foreach($relativePath in $expectedRelative) {
                $expectedHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $pluginDataRoot $relativePath)).Hash
                $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $temporaryData $relativePath)).Hash
                if($expectedHash -ne $actualHash) {
                    Add-Failure "Regeneration mismatch: data/$relativePath"
                }
            }
        }
    } finally {
        if(Test-Path -LiteralPath $temporaryRoot) {
            Remove-Item -LiteralPath $temporaryRoot -Recurse -Force
        }
    }
}

if($ParseAssets) {
    if([string]::IsNullOrWhiteSpace($EndlessSkyExecutable)) {
        throw "Set -EndlessSkyExecutable or define it in tools/company_foundations.local.ps1."
    }
    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $parseOutput = & $EndlessSkyExecutable --parse-assets 2>&1 | Out-String
    } finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }
    $pluginErrors = @($parseOutput -split "`r?`n" |
        Where-Object { $_ -match '(?i)Company Foundations' -and $_ -match '(?i)error|warning|failed|invalid' })
    foreach($line in $pluginErrors) {
        Add-Failure "Endless Sky asset parser: $line"
    }
}

if($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "Company Foundations verification failed with $($failures.Count) issue(s)."
}

Write-Host ("PASS: {0} scripts, {1} data files, {2} missions, {3} events, {4:N2} MiB." -f `
    $scripts.Count,
    $dataFiles.Count,
    $definitions.mission.Count,
    $definitions.event.Count,
    ($totalDataBytes / 1MB))
if($auditedSaveCount -gt 0) {
    Write-Host "PASS: audited $auditedSaveCount active Company Foundations save file(s) for v0.1 migration coverage."
}
