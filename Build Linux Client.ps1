$ErrorActionPreference = 'Stop'

$systemRoot = Split-Path -Parent $PSCommandPath
$sourceRoot = $systemRoot
$zigRoot = Join-Path $env:LOCALAPPDATA 'SRB2LinuxToolchain\zig-0.17.0\zig-x86_64-windows-0.17.0'
$appPackagesRoot = Join-Path $env:USERPROFILE 'AppData\Local\Packages'
$redirectedZigRoot = Get-ChildItem -LiteralPath $appPackagesRoot -Directory -ErrorAction SilentlyContinue |
	ForEach-Object {
		Join-Path $_.FullName 'LocalCache\Local\SRB2LinuxToolchain\zig-0.17.0\zig-x86_64-windows-0.17.0'
	} |
	Where-Object {
		Test-Path -LiteralPath (Join-Path $_ 'lib')
	} |
	Select-Object -First 1
if ($redirectedZigRoot) {
	$zigRoot = $redirectedZigRoot
}
$zigCacheRoot = $systemRoot
$zigGlobalCache = Join-Path $systemRoot 'zig-cache-global'
$runtimeWrapper = $null
$workspaceZig = Join-Path $systemRoot 'zig-0.17.0.exe'
if (Test-Path -LiteralPath $workspaceZig) {
	$zigRuntimeRoot = Join-Path $env:USERPROFILE 'AppData\Local\Temp\SRB2LinuxToolchain'
	$zigCacheRoot = $zigRuntimeRoot
	if (-not (Test-Path -LiteralPath $zigRuntimeRoot)) {
		New-Item -ItemType Directory -Path $zigRuntimeRoot | Out-Null
	}
	$runtimeGlobalCache = Join-Path $zigRuntimeRoot 'cache-global-seeded'
	if (-not (Test-Path -LiteralPath $runtimeGlobalCache)) {
		if (-not (Test-Path -LiteralPath $zigGlobalCache)) {
			throw "Seeded Zig global cache is missing: $zigGlobalCache"
		}
		Copy-Item -LiteralPath $zigGlobalCache -Destination $runtimeGlobalCache -Recurse
	}
	$zigGlobalCache = $runtimeGlobalCache
	$zig = Join-Path $zigRuntimeRoot 'zig.exe'
	if (-not (Test-Path -LiteralPath $zig) -or
		(Get-Item -LiteralPath $zig).Length -ne (Get-Item -LiteralPath $workspaceZig).Length) {
		Copy-Item -LiteralPath $workspaceZig -Destination $zig -Force
	}
	$workspaceWrapper = Join-Path $systemRoot 'zig-cache-rename-workaround.ps1'
	if (-not (Test-Path -LiteralPath $workspaceWrapper)) {
		throw "Zig cache-rename workaround is missing: $workspaceWrapper"
	}
	$runtimeWrapper = Join-Path $zigRuntimeRoot 'zig-cache-rename-workaround.ps1'
	if (-not (Test-Path -LiteralPath $runtimeWrapper) -or
		(Get-Item -LiteralPath $runtimeWrapper).Length -ne (Get-Item -LiteralPath $workspaceWrapper).Length) {
		Copy-Item -LiteralPath $workspaceWrapper -Destination $runtimeWrapper -Force
	}
}
else {
	$zig = Join-Path $zigRoot 'zig.exe'
}
$make = 'C:\ProgramData\SRB2TC64\bin\mingw32-make.exe'
$objcopy = Join-Path $env:LOCALAPPDATA 'Android\Sdk\ndk\28.0.12433566\toolchains\llvm\prebuilt\windows-x86_64\bin\llvm-objcopy.exe'
$llvmBin = Split-Path -Parent $objcopy
$lld = Join-Path $llvmBin 'ld.lld.exe'
$nm = Join-Path $llvmBin 'llvm-nm.exe'
$readelf = Join-Path $llvmBin 'llvm-readelf.exe'
$zigLib = Join-Path $systemRoot 'zig-0.17.0-lib'
if (-not (Test-Path -LiteralPath $zigLib)) {
	$zigLib = Join-Path $zigRoot 'lib'
}

$glibcCompatRoot = Join-Path $sourceRoot 'linux-build\glibc217'
$glibcAssets = @(
	'crt1.o',
	'libc_nonshared.a',
	'libcompiler_rt.a',
	'libm.so.6',
	'libc.so.6',
	'librt.so.1'
) | ForEach-Object { Join-Path $glibcCompatRoot $_ }

$requiredComponents = @($sourceRoot, $zig, $zigLib, $make, $objcopy, $lld, $nm, $readelf) + $glibcAssets
if ($runtimeWrapper) {
	$requiredComponents += $runtimeWrapper
}
foreach ($required in $requiredComponents) {
	if (-not (Test-Path -LiteralPath $required)) {
		throw "Required Linux build component is missing: $required"
	}
}

$env:ZIG_LIB_DIR = $zigLib
$env:ZIG_LOCAL_CACHE_DIR = Join-Path $zigCacheRoot 'cache-local'
$env:ZIG_GLOBAL_CACHE_DIR = $zigGlobalCache

$zigCommand = $zig.Replace('\', '/')
if ($runtimeWrapper) {
	$runtimeWrapperCommand = $runtimeWrapper.Replace('\', '/')
	$zigCommand = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File $runtimeWrapperCommand"
}
$makeArgs = @(
	'-C', 'src', '-j4',
	'LINUX64=1', 'X86_64=1', 'SDL=1', 'WINDOWSHELL=1',
	'NOGME=1', 'NOOPENMPT=1', 'RELAXWARNINGS=1', 'NOLDWARNING=1',
	'EXENAME=srb2-v5.104-linux-x86_64',
	'DBGNAME=srb2-v5.104-linux-x86_64.debug',
	'makedir=../make-linux-v5104-glibc217',
	'bin=../bin-linux-v5104-glibc217',
	"CC=$zigCommand cc -target x86_64-linux-gnu",
	"OBJCOPY=$($objcopy.Replace('\', '/'))",
	'CFLAGS=-Wno-error=date-time',
	'PNG_CFLAGS=-I../libs/libpng-src',
	'PNG_LDFLAGS=../linux-build/libpng/libpng.a',
	'CURL_CFLAGS=-I../libs/curl/include',
	'CURL_LDFLAGS=../linux-build/link/libcurl.so.4.8.0',
	'MINIUPNPC_CFLAGS=-I../libs/miniupnpc/include',
	'MINIUPNPC_LDFLAGS=../linux-build/miniupnpc/libminiupnpc.a',
	'ZLIB_CFLAGS=-I../libs/zlib',
	'ZLIB_LDFLAGS=../linux-build/zlib/libz.a',
	'SDL_CFLAGS=-I../libs/SDL2/include -I../libs/SDL2_mixer/include -D_REENTRANT',
	'SDL_LDFLAGS=../linux-build/link/libSDL2-2.0.so.0.2600.5',
	'SDL_MIXER_LDFLAGS=../linux-build/link/libSDL2_mixer.so',
	'LDFLAGS=-Wl,-rpath,$$ORIGIN/lib -Wl,-z,now -Wl,--as-needed -no-pie',
	'linux-objects-only'
)

Push-Location $sourceRoot
try {
	& $make @makeArgs
	if ($LASTEXITCODE -ne 0) {
		throw "Linux compilation failed with exit code $LASTEXITCODE"
	}

	$objectRoot = Join-Path $sourceRoot 'make-linux-v5104-glibc217\objs'
	$compatRoot = Join-Path $sourceRoot 'make-linux-v5104-glibc217\compat'
	$compatBlua = Join-Path $compatRoot 'blua'
	if (-not (Test-Path -LiteralPath $compatBlua)) {
		New-Item -ItemType Directory -Path $compatBlua | Out-Null
	}

	$compatObjects = @{
		'make-linux-v5104-glibc217/objs/blua/lcode.o' = 'make-linux-v5104-glibc217/compat/blua/lcode.o'
		'make-linux-v5104-glibc217/objs/blua/lvm.o' = 'make-linux-v5104-glibc217/compat/blua/lvm.o'
	}
	foreach ($entry in $compatObjects.GetEnumerator()) {
		$inputPath = Join-Path $sourceRoot ($entry.Key.Replace('/', '\'))
		$outputPath = Join-Path $sourceRoot ($entry.Value.Replace('/', '\'))
		& $objcopy '--redefine-sym' 'pow=pow@GLIBC_2.2.5' $inputPath $outputPath
		if ($LASTEXITCODE -ne 0) {
			throw "glibc symbol-version rewrite failed for $($entry.Key)"
		}
		$undefinedText = (& $nm --undefined-only $outputPath) -join "`n"
		if ($undefinedText -notmatch 'pow@GLIBC_2\.2\.5') {
			throw "Versioned pow reference was not created in $outputPath"
		}
	}

	$compatPng = Join-Path $compatRoot 'libpng-glibc217.a'
	& $objcopy '--redefine-sym' 'pow=pow@GLIBC_2.2.5' (Join-Path $sourceRoot 'linux-build\libpng\libpng.a') $compatPng
	if ($LASTEXITCODE -ne 0) {
		throw "libpng glibc symbol-version rewrite failed with exit code $LASTEXITCODE"
	}
	$pngUndefined = (& $nm --undefined-only $compatPng) -join "`n"
	if ($pngUndefined -notmatch 'pow@GLIBC_2\.2\.5') {
		throw 'Versioned pow reference was not created in the compatibility libpng archive.'
	}

	$objects = Get-ChildItem -LiteralPath $objectRoot -Filter '*.o' -File -Recurse |
		Sort-Object FullName |
		ForEach-Object {
			$relative = $_.FullName.Substring($sourceRoot.Length).TrimStart([char[]]@('\', '/')).Replace('\', '/')
			if ($compatObjects.ContainsKey($relative)) { $compatObjects[$relative] } else { $relative }
		}

	$compatDebug = 'bin-linux-v5104-glibc217/srb2-v5.104-linux-x86_64.debug217'
	$linkArgs = @(
		'-m', 'elf_x86_64',
		'--dynamic-linker=/lib64/ld-linux-x86-64.so.2',
		'--image-base=0x1000000',
		'--hash-style=both', '--eh-frame-hdr', '--enable-new-dtags',
		'--export-dynamic', '--allow-shlib-undefined', '--as-needed',
		'-z', 'now', '-z', 'stack-size=16777216',
		'-rpath', '$ORIGIN/lib',
		'-o', $compatDebug,
		'linux-build/glibc217/crt1.o'
	) + $objects + @(
		'make-linux-v5104-glibc217/compat/libpng-glibc217.a',
		'linux-build/miniupnpc/libminiupnpc.a',
		'linux-build/zlib/libz.a',
		'linux-build/link/libcurl.so.4.8.0',
		'linux-build/link/libSDL2_mixer.so',
		'linux-build/link/libSDL2-2.0.so.0.2600.5',
		'linux-build/glibc217/libm.so.6',
		'linux-build/glibc217/libc.so.6',
		'linux-build/glibc217/librt.so.1',
		'linux-build/glibc217/libc_nonshared.a',
		'linux-build/glibc217/libcompiler_rt.a'
	)

	& $lld @linkArgs
	if ($LASTEXITCODE -ne 0) {
		throw "glibc 2.17 compatibility link failed with exit code $LASTEXITCODE"
	}

	$compatDebugPath = Join-Path $sourceRoot ($compatDebug.Replace('/', '\'))
	$versionInfo = (& $readelf '--version-info' $compatDebugPath) -join "`n"
	if ($LASTEXITCODE -ne 0) {
		throw "Reading Linux symbol versions failed with exit code $LASTEXITCODE"
	}

	$unsupportedGlibc = @(
		foreach ($match in [regex]::Matches($versionInfo, 'GLIBC_(\d+)\.(\d+)')) {
			$major = [int]$match.Groups[1].Value
			$minor = [int]$match.Groups[2].Value
			if ($major -gt 2 -or ($major -eq 2 -and $minor -gt 17)) {
				$match.Value
			}
		}
	) | Sort-Object -Unique
	if ($unsupportedGlibc.Count -ne 0) {
		throw "Linux executable requires unsupported glibc versions: $($unsupportedGlibc -join ', ')"
	}

	$dynamicSymbols = (& $readelf '--dyn-syms' '--wide' $compatDebugPath) -join "`n"
	if ($LASTEXITCODE -ne 0) {
		throw "Reading Linux dynamic symbols failed with exit code $LASTEXITCODE"
	}
	if ($dynamicSymbols -notmatch '(?m)\bpow@GLIBC_2\.2\.5\b') {
		throw 'Linux executable is missing the glibc 2.2.5-compatible pow reference'
	}
	if ($dynamicSymbols -match '(?m)\bpow@GLIBC_2\.29\b') {
		throw 'Linux executable unexpectedly requires pow from glibc 2.29'
	}

	$binRoot = Join-Path $sourceRoot 'bin-linux-v5104-glibc217'
	$debugName = 'srb2-v5.104-linux-x86_64.debug'
	$releaseName = 'srb2-v5.104-linux-x86_64'
	Move-Item -LiteralPath (Join-Path $sourceRoot $compatDebug) -Destination (Join-Path $binRoot $debugName) -Force
	& $objcopy '--strip-debug' (Join-Path $binRoot $debugName) (Join-Path $binRoot $releaseName)
	if ($LASTEXITCODE -ne 0) {
		throw "Stripping the Linux executable failed with exit code $LASTEXITCODE"
	}

	Push-Location $binRoot
	try {
		& $objcopy "--add-gnu-debuglink=$debugName" $releaseName
		if ($LASTEXITCODE -ne 0) {
			throw "Adding the Linux debug link failed with exit code $LASTEXITCODE"
		}
	}
	finally {
		Pop-Location
	}

	Write-Host "Linux V5.104 build completed in $binRoot"
}
finally {
	Pop-Location
}
