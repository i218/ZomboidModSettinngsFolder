$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$source = Join-Path $root 'Contents/mods/ModSettingsFolders'
$info = Get-Content -LiteralPath (Join-Path $source '42/mod.info') -Raw
$version = [regex]::Match($info, '(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
if (!$version) { throw 'Missing semantic version in mod.info' }
$out = Join-Path $root "build/distributions/$version"
New-Item -ItemType Directory -Path $out -Force | Out-Null
$zipPath = Join-Path $out "ModSettingsFolders-$version.zip"
if (Test-Path -LiteralPath $zipPath) { throw 'Version already packaged; use a new version or remove the old archive explicitly.' }
Add-Type -AssemblyName System.IO.Compression.FileSystem
$archive = [IO.Compression.ZipFile]::Open($zipPath, [IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse) {
        $relative = $file.FullName.Substring($source.Length + 1).Replace('\', '/')
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, $file.FullName, "ModSettingsFolders/$relative", [IO.Compression.CompressionLevel]::Optimal) | Out-Null
    }
    foreach ($name in @('README.md','README.ru.md','LICENSE','docs/verification.md')) {
        [IO.Compression.ZipFileExtensions]::CreateEntryFromFile($archive, (Join-Path $root $name), "ModSettingsFolders/$name", [IO.Compression.CompressionLevel]::Optimal) | Out-Null
        New-Item -ItemType Directory -Path (Split-Path -Parent (Join-Path $out $name)) -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $out $name)
    }
} finally { $archive.Dispose() }
$hash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText((Join-Path $out 'SHA256SUMS.txt'), "$hash  $([IO.Path]::GetFileName($zipPath))`n", [Text.UTF8Encoding]::new($false))
Write-Output $out
