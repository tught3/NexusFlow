param(
  [Parameter(ValueFromRemainingArguments = $true)]
  [string[]]$Args
)

$WorkspaceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $WorkspaceRoot '.fluxos\scripts\fluxos-session-bootstrap.ps1')
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

$session = $null
$exitCode = 0
try {
  $session = Start-FluxOsProjectSession -Project 'NexusFlow' -Source 'nexusflow-local' -Owner 'NexusFlow-local' -Label 'NexusFlow Flutter 런처' -Note ("flutter {0}" -f (($Args -join ' ').Trim())) -Cwd $ProjectRoot -PreferCurrentProjectSession

  $defineArgs = @()
  $localDefineFile = Join-Path $PSScriptRoot '..\env\local.json'
  if (Test-Path $localDefineFile) {
    $localDefines = Get-Content $localDefineFile -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($property in $localDefines.PSObject.Properties) {
      $value = [string]$property.Value
      if (-not [string]::IsNullOrWhiteSpace($value)) {
        $defineArgs += "--dart-define=$($property.Name)=$value"
      }
    }
  }

  foreach ($name in @('SUPABASE_URL', 'SUPABASE_ANON_KEY', 'OPENAI_BASE_URL', 'OPENAI_API_KEY')) {
    $value = [string][System.Environment]::GetEnvironmentVariable($name)
    if (-not [string]::IsNullOrWhiteSpace($value)) {
      $defineArgs += "--dart-define=$name=$value"
    }
  }

  if ($Args.Count -eq 0) {
    & flutter
    $exitCode = $LASTEXITCODE
  } else {
    $command = $Args[0]
    $flutterArgs = @($Args)

    if ($command -eq 'deploy') {
      $deployHelper = 'E:\AI_WIKI\scripts\flutter-deploy-or-copy.ps1'
      if (-not (Test-Path -LiteralPath $deployHelper)) {
        throw "Missing deploy helper: $deployHelper"
      }
      $tailArgs = @()
      if ($Args.Count -gt 1) {
        $tailArgs = @($Args[1..($Args.Count - 1)])
      }
      $extraJson = ConvertTo-Json -Compress -InputObject @($defineArgs)
      $deployCommand = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass',
        '-File', $deployHelper,
        '-ProjectPath', $ProjectRoot,
        '-Project', 'NexusFlow',
        '-Owner', 'NexusFlow-local',
        '-ExtraBuildArgsJson', $extraJson
      ) + $tailArgs
      & powershell @deployCommand
      $exitCode = $LASTEXITCODE
      return
    }

    if ($defineArgs.Count -gt 0 -and $command -ne 'analyze') {
      if ($command -eq 'build' -and $Args.Count -ge 2) {
        $flutterArgs = @($command, $Args[1]) + $defineArgs + $Args[2..($Args.Count - 1)]
      } elseif ($Args.Count -gt 1) {
        $flutterArgs = @($command) + $defineArgs + $Args[1..($Args.Count - 1)]
      } else {
        $flutterArgs = @($command) + $defineArgs
      }
    }

    & flutter @flutterArgs
    $exitCode = $LASTEXITCODE
  }
} finally {
  if ($session) {
    try {
      Stop-FluxOsProjectSession -SessionId $session.id -Reason 'nexusflow-local 종료'
    } catch {
      # cleanup failure is intentionally non-fatal
    }
  }
}

exit $exitCode
