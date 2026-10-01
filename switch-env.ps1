param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("local", "remote")]
    [string]$Environment
)

# Cambia las variables activas de Hop copiando la plantilla elegida
# (environments/<env>.json) a project-config.json -> config.variables y
# sobreponiendo DB_ORA_DW_* desde docs/credenciales/<env>.txt (gitignored).
# Equivalente Windows de switch-env.sh.
# Uso: .\switch-env.ps1 local   |   .\switch-env.ps1 remote

$ErrorActionPreference = "Stop"

$root     = $PSScriptRoot
$envFile  = Join-Path $root "environments\$Environment.json"
$credFile = Join-Path $root "docs\credenciales\$Environment.txt"
$projFile = Join-Path $root "project-config.json"

if (-not (Test-Path -LiteralPath $envFile)) {
    throw "No existe la plantilla: $envFile"
}

$envCfg = Get-Content -LiteralPath $envFile -Raw | ConvertFrom-Json
$vars   = @($envCfg.variables)

function Test-Placeholder {
    param([string]$Value)
    return $null -ne $Value -and $Value -match '<[^>]+>'
}

# project-config.json puede no existir todavia (lo genera este script).
if (Test-Path -LiteralPath $projFile) {
    $proj = Get-Content -LiteralPath $projFile -Raw | ConvertFrom-Json
} else {
    $proj = [pscustomobject]@{
        metadataBaseFolder         = '${PROJECT_HOME}/metadata'
        unitTestsBasePath          = '${PROJECT_HOME}'
        dataSetsCsvFolder          = '${PROJECT_HOME}/datasets'
        enforcingExecutionInHome   = $true
        parentProjectName          = 'default'
        config                     = [pscustomobject]@{ variables = @() }
    }
}

# --- Overlay DB_ORA_DW_* desde docs/credenciales/<env>.txt -------------------
# Los environments/*.json van sin secretos en git (placeholders <...>); el
# password real solo vive en el .txt (gitignored) y se copia al project-config
# generado. Mismo criterio que switch-env.sh.
if (Test-Path -LiteralPath $credFile) {
    $wanted = @{}
    foreach ($line in Get-Content -LiteralPath $credFile) {
        $line = $line.Trim()
        if ($line -eq '' -or $line.StartsWith('#')) { continue }
        $idx = $line.IndexOf(':')
        if ($idx -lt 1) { continue }
        $key = $line.Substring(0, $idx).Trim()
        $val = $line.Substring($idx + 1).Trim()
        if ($key -in @('Host', 'Port', 'Service', 'User', 'Password')) { $wanted[$key] = $val }
    }
    $missing = @('Host', 'Port', 'Service', 'User', 'Password') | Where-Object { -not $wanted.ContainsKey($_) }
    if ($missing) {
        throw "Faltan $($missing -join ', ') en $credFile"
    }
    $dwHost = $wanted['Host']; $dwPort = $wanted['Port']; $dwService = $wanted['Service']
    $overlay = @{
        DB_ORA_DW_HOST     = $dwHost
        DB_ORA_DW_PORT     = $dwPort
        DB_ORA_DW_DATABASE = $dwService
        DB_ORA_DW_USERNAME = $wanted['User']
        DB_ORA_DW_PASSWORD = $wanted['Password']
        DB_ORA_DW_URL      = "jdbc:oracle:thin:@//${dwHost}:${dwPort}/${dwService}"
    }
    foreach ($v in $vars) {
        if ($overlay.ContainsKey($v.name)) { $v.value = $overlay[$v.name] }
    }
    Write-Host "DW overlay: ${dwHost}:${dwPort}/$dwService user=$($wanted['User'])"
} else {
    Write-Warning "No existe $credFile; DB_ORA_DW_* quedan con los placeholders de la plantilla."
}

# --- No pisar valores reales ya presentes si la plantilla trae placeholders --
$existing = @{}
foreach ($v in @($proj.config.variables)) {
    if ($v.name -and -not $existing.ContainsKey($v.name)) { $existing[$v.name] = $v }
}
$merged = foreach ($v in $vars) {
    if ((Test-Placeholder $v.value) -and $existing.ContainsKey($v.name) -and
        -not (Test-Placeholder $existing[$v.name].value)) {
        [pscustomobject]@{
            name        = $v.name
            value       = $existing[$v.name].value
            description = $v.description
        }
    } else {
        [pscustomobject]@{
            name        = $v.name
            value       = $v.value
            description = $v.description
        }
    }
}
$proj.config.variables = @($merged)

$json = $proj | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText($projFile, $json, (New-Object System.Text.UTF8Encoding($false)))

Write-Host "Entorno activo: $Environment (variables copiadas a project-config.json)"
