param([Parameter(Mandatory=$true)][string]$Archive)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path -Parent $PSScriptRoot
$zip = [IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $Archive).Path)
try {
    $names = @($zip.Entries | ForEach-Object FullName)
    if (($names | Select-Object -Unique).Count -ne $names.Count) { throw 'Duplicate ZIP entries' }
    if ('ModSettingsFolders/42/mod.info' -notin $names) { throw 'Missing Build 42 manifest' }
    foreach ($entry in $zip.Entries) {
        if ($entry.FullName -match '\.\.|\\|\.(jar|class|exe)$') { throw "Unexpected packaged entry: $($entry.FullName)" }
        if (!$entry.FullName.StartsWith('ModSettingsFolders/')) { throw 'Unexpected archive root' }
        $relative = $entry.FullName.Substring('ModSettingsFolders/'.Length)
        $expected = if ($relative -in @('README.md','README.ru.md','LICENSE','docs/verification.md')) { Join-Path $root $relative } else { Join-Path $root "Contents/mods/ModSettingsFolders/$relative" }
        $stream = $entry.Open()
        $sha = [Security.Cryptography.SHA256]::Create()
        try { $hash = [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-','') } finally { $stream.Dispose();$sha.Dispose() }
        if ($hash -ne (Get-FileHash -LiteralPath $expected -Algorithm SHA256).Hash) { throw "Payload differs: $relative" }
    }
    $expectedCount = @(Get-ChildItem -LiteralPath (Join-Path $root 'Contents/mods/ModSettingsFolders') -File -Recurse).Count + 4
    if ($names.Count -ne $expectedCount) { throw 'Missing source files in archive' }
    $declared = (Get-Content -LiteralPath (Join-Path (Split-Path -Parent $Archive) 'SHA256SUMS.txt') -Raw).Split(' ')[0]
    if ($declared -ne (Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash.ToLowerInvariant()) { throw 'ZIP checksum mismatch' }
    Write-Output "PASS ZIP layout, complete byte-identical payload, no Java/native binaries, SHA256 ($($names.Count) entries)"
} finally { $zip.Dispose() }
