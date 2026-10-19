param([switch]$Refresh, [string]$WorkshopId)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$source = Join-Path $root 'Contents/mods/ModSettingsFolders'
$info = Get-Content -LiteralPath (Join-Path $source '42/mod.info') -Raw
$version = [regex]::Match($info, '(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
if (!$version) { throw 'Missing mod version' }
$out = Join-Path $root "build/workshop/$version/ModSettingsFolders"
$previousMetadata = Join-Path $out 'workshop.txt'
if ((Test-Path -LiteralPath $out) -and !$Refresh) { throw 'Workshop package exists; use -Refresh explicitly. Existing Workshop ID will be retained.' }
if (!$PSBoundParameters.ContainsKey('WorkshopId') -and (Test-Path -LiteralPath $previousMetadata)) {
    $old = Get-Content -LiteralPath $previousMetadata -Raw
    $matches = [regex]::Matches($old, '(?m)^id=([^\r\n]*)\r?$')
    if ($matches.Count -gt 1) { throw 'Duplicate Workshop IDs in existing package; refusing to discard them.' }
    if ($matches.Count -eq 1) { $WorkshopId = $matches[0].Groups[1].Value.Trim() }

}
[UInt64]$parsedId = 0
if ($WorkshopId -and ($WorkshopId -notmatch '^[1-9][0-9]{0,19}$' -or ![UInt64]::TryParse($WorkshopId,[ref]$parsedId))) { throw 'Invalid Workshop ID' }
# Release notes stay beside distributions, outside the Workshop upload tree.
& (Join-Path $root 'Copy-ReleaseNotes.ps1')
$stage = Join-Path $root "build/workshop/.stage-$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path (Join-Path $stage 'Contents/mods') -Force | Out-Null
# Walk without following links; copy files individually from the explicit runtime root.
$pending = [Collections.Generic.Stack[string]]::new()
$pending.Push($source)
while ($pending.Count -gt 0) {
    $directory = $pending.Pop()
    if ((Get-Item -LiteralPath $directory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked mod source is not allowed' }
    foreach ($entry in Get-ChildItem -LiteralPath $directory -Force) {
        if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked mod source is not allowed' }
        if ($entry.PSIsContainer) {
            if ($entry.Name -in @('.git','build','tests','installer','.codex','.vscode')) { throw 'Development directory in runtime source' }
            $pending.Push($entry.FullName)
        } else {
            if ($entry.Name -match '(?i)^(\.env|credentials(?:\.|$)|secrets(?:\.|$))' -or
                ($entry.Extension -notin @('.lua','.json','.info','.txt','.png') -and $entry.Name -ne 'LICENSE')) { throw 'Non-runtime or sensitive file in mod source' }
            $relative = $entry.FullName.Substring($source.Length+1)
            $destination = Join-Path (Join-Path $stage 'Contents/mods/ModSettingsFolders') $relative
            New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
            Copy-Item -LiteralPath $entry.FullName -Destination $destination
        }
    }
}
Copy-Item -LiteralPath (Join-Path $root 'LICENSE') -Destination (Join-Path $stage 'Contents/mods/ModSettingsFolders/LICENSE')
# Only these two root metadata assets are copied; never the repository or installer.
Copy-Item -LiteralPath (Join-Path $root 'workshop/preview.png') -Destination (Join-Path $stage 'preview.png')
$text = [IO.File]::ReadAllText((Join-Path $root 'workshop/workshop.txt'))
if ($WorkshopId) { $text += "id=$WorkshopId`n" }
[IO.File]::WriteAllText((Join-Path $stage 'workshop.txt'), $text, [Text.UTF8Encoding]::new($false))
& (Join-Path $root 'tests/Verify-Workshop.ps1') -Package $stage
if (Test-Path -LiteralPath $out) {
    # Keep the former staging package and its metadata; never recursively delete it.
    $archive = Join-Path $root "build/workshop/previous-$version-$([Guid]::NewGuid().ToString('N'))"
    $resolvedRoot = [IO.Path]::GetFullPath((Join-Path $root 'build/workshop')) + [IO.Path]::DirectorySeparatorChar
    foreach ($candidate in @($out,$archive)) {
        if (![IO.Path]::GetFullPath($candidate).StartsWith($resolvedRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Workshop move escapes build directory' }
    }
    Move-Item -LiteralPath $out -Destination $archive
}
New-Item -ItemType Directory -Path (Split-Path -Parent $out) -Force | Out-Null
Move-Item -LiteralPath $stage -Destination $out
Write-Output $out
