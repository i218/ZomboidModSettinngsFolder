param([switch]$Rebuild)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$info = Get-Content -LiteralPath (Join-Path $root 'Contents/mods/ModSettingsFolders/42/mod.info') -Raw
$version = [regex]::Match($info, '(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
if (!$version) { throw 'Missing semantic version' }
$out = Join-Path $root "build/distributions/$version"
$payload = Join-Path $out "ModSettingsFolders-$version.zip"
if (!(Test-Path -LiteralPath $payload)) { & (Join-Path $root 'Build.ps1') }
& (Join-Path $root 'tests/Verify-Package.ps1') -Archive $payload
$setup = Join-Path $out "ModSettingsFolders-Setup-$version.exe"
if ((Test-Path -LiteralPath $setup) -and !$Rebuild) { throw 'Installer exists; use -Rebuild explicitly or change the version.' }
$work = Join-Path $root 'build/installer'
New-Item -ItemType Directory -Path $work -Force | Out-Null
Add-Type -AssemblyName System.IO.Compression.FileSystem
$manifest = Join-Path $work 'payload.manifest'
$archive = [IO.Compression.ZipFile]::OpenRead($payload)
try {
    $rows = foreach ($entry in $archive.Entries | Sort-Object FullName) {
        $stream = $entry.Open(); $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','').ToLowerInvariant() }
        finally { $stream.Dispose();$sha.Dispose() }
        "$hash|$($entry.Length)|$($entry.FullName)"
    }
    [IO.File]::WriteAllText($manifest, ($rows -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
} finally { $archive.Dispose() }
$versionSource = Join-Path $work 'Version.cs'
[IO.File]::WriteAllText($versionSource, "[assembly: System.Reflection.AssemblyVersion(""$version.0"")]", [Text.UTF8Encoding]::new($false))
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (!(Test-Path -LiteralPath $compiler)) { throw 'Windows .NET Framework compiler is required.' }
$references = @('/reference:System.Windows.Forms.dll','/reference:System.Drawing.dll','/reference:System.IO.Compression.dll','/reference:System.IO.Compression.FileSystem.dll')
& $compiler /nologo /target:winexe /platform:anycpu /optimize+ "/out:$setup" "/win32manifest:$(Join-Path $root 'installer/app.manifest')" @references "/resource:$payload,payload.zip" "/resource:$manifest,payload.manifest" $versionSource (Join-Path $root 'installer/InstallEngine.cs') (Join-Path $root 'installer/Setup.cs')
if ($LASTEXITCODE -ne 0) { throw 'Installer compilation failed' }
$sums = foreach ($file in @($payload,$setup)) { "$((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($file))" }
[IO.File]::WriteAllText((Join-Path $out 'SHA256SUMS.txt'), ($sums -join "`n") + "`n", [Text.UTF8Encoding]::new($false))
Write-Output $setup
