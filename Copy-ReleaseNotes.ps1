$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$info = Get-Content -LiteralPath (Join-Path $root 'Contents/mods/ModSettingsFolders/42/mod.info') -Raw
$version = [regex]::Match($info, '(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
if (!$version) { throw 'Missing semantic version' }
$source = Join-Path $root "release-notes/$version.txt"
if (!(Test-Path -LiteralPath $source -PathType Leaf)) { throw "Missing Steam changelog for $version" }
$text = [IO.File]::ReadAllText($source)
if (!$text.StartsWith("[h1]v$version[/h1]") -or $text -notmatch '\[\*\]\S') { throw 'Steam changelog must identify this version and list its changes' }
$out = Join-Path $root "build/distributions/$version"
New-Item -ItemType Directory -Path $out -Force | Out-Null
Copy-Item -LiteralPath $source -Destination (Join-Path $out 'CHANGELOG-Steam.txt')
