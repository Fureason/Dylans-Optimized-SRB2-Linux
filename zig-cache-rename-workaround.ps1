$ErrorActionPreference = 'Stop'

$zig = Join-Path $PSScriptRoot 'zig.exe'
if (-not (Test-Path -LiteralPath $zig)) {
	[Console]::Error.WriteLine("Zig executable is missing: $zig")
	exit 127
}

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$captured = @(& $zig @args 2>&1)
$zigExit = $LASTEXITCODE
$ErrorActionPreference = $previousErrorActionPreference
if ($zigExit -eq 0) {
	foreach ($line in $captured) {
		if ($line -is [System.Management.Automation.ErrorRecord]) {
			[Console]::Error.WriteLine($line.ToString())
		}
		else {
			[Console]::Out.WriteLine([string]$line)
		}
	}
	exit 0
}

$message = ($captured | ForEach-Object { [string]$_ }) -join "`n"
$renameMatch = [regex]::Match(
	$message,
	"failed to rename 'tmp\\(?<temp>[^']+)' into '(?<cache>[^']+)': (?:Unexpected|AccessDenied)"
)
if (-not $renameMatch.Success) {
	foreach ($line in $captured) {
		[Console]::Error.WriteLine([string]$line)
	}
	exit $zigExit
}

if ([string]::IsNullOrWhiteSpace($env:ZIG_LOCAL_CACHE_DIR)) {
	[Console]::Error.WriteLine('ZIG_LOCAL_CACHE_DIR is not set.')
	exit $zigExit
}

$tempName = $renameMatch.Groups['temp'].Value
$generated = Join-Path (Join-Path $env:ZIG_LOCAL_CACHE_DIR 'tmp') $tempName
if (-not (Test-Path -LiteralPath $generated)) {
	[Console]::Error.WriteLine("Zig generated output is missing: $generated")
	exit $zigExit
}

$outputArgument = $null
for ($index = 0; $index -lt $args.Count; $index++) {
	$argument = [string]$args[$index]
	if ($argument -eq '-o' -and $index + 1 -lt $args.Count) {
		$outputArgument = [string]$args[$index + 1]
		break
	}
	if ($argument.StartsWith('-o') -and $argument.Length -gt 2) {
		$outputArgument = $argument.Substring(2)
		break
	}
	if ($argument.StartsWith('-femit-bin=')) {
		$outputArgument = $argument.Substring('-femit-bin='.Length)
		break
	}
}

if ([string]::IsNullOrWhiteSpace($outputArgument)) {
	[Console]::Error.WriteLine('Unable to determine the requested compiler output path.')
	exit $zigExit
}

if ([IO.Path]::IsPathRooted($outputArgument)) {
	$outputPath = [IO.Path]::GetFullPath($outputArgument)
}
else {
	$outputPath = [IO.Path]::GetFullPath((Join-Path (Get-Location).Path $outputArgument))
}

$outputDirectory = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $outputDirectory)) {
	New-Item -ItemType Directory -Path $outputDirectory | Out-Null
}
Copy-Item -LiteralPath $generated -Destination $outputPath -Force
if (-not (Test-Path -LiteralPath $outputPath) -or (Get-Item -LiteralPath $outputPath).Length -eq 0) {
	[Console]::Error.WriteLine("Recovered compiler output is invalid: $outputPath")
	exit $zigExit
}

exit 0
