$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $root "build/workshop-lifecycle/$([Guid]::NewGuid().ToString('N'))"
New-Item -ItemType Directory -Path $fixture,(Join-Path $fixture 'tests'),(Join-Path $fixture 'workshop') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $root 'Contents') -Destination (Join-Path $fixture 'Contents') -Recurse
foreach ($name in @('Build-Workshop.ps1','Copy-ReleaseNotes.ps1','LICENSE')) { Copy-Item -LiteralPath (Join-Path $root $name) -Destination (Join-Path $fixture $name) }
Copy-Item -LiteralPath (Join-Path $root 'tests/Verify-Workshop.ps1') -Destination (Join-Path $fixture 'tests/Verify-Workshop.ps1')
foreach ($name in @('workshop.txt','preview.png')) { Copy-Item -LiteralPath (Join-Path $root "workshop/$name") -Destination (Join-Path $fixture "workshop/$name") }
Copy-Item -LiteralPath (Join-Path $root 'release-notes') -Destination (Join-Path $fixture 'release-notes') -Recurse
$builder = Join-Path $fixture 'Build-Workshop.ps1'
& $builder | Out-Null
$version = [regex]::Match((Get-Content -LiteralPath (Join-Path $fixture 'Contents/mods/ModSettingsFolders/42/mod.info') -Raw),'(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
$package = Join-Path $fixture "build/workshop/$version/ModSettingsFolders"
$notes = Join-Path $fixture "build/distributions/$version/CHANGELOG-Steam.txt"
if (!(Test-Path -LiteralPath $notes) -or (Get-FileHash -LiteralPath $notes).Hash -ne (Get-FileHash -LiteralPath (Join-Path $fixture "release-notes/$version.txt")).Hash) { throw 'Release changelog missing or altered' }
if (Get-ChildItem -LiteralPath $package -Recurse -File | Where-Object { $_.Name -match 'changelog' }) { throw 'Changelog leaked into Workshop upload' }
$metadata = Join-Path $package 'workshop.txt'
$before = (Get-FileHash -LiteralPath $metadata).Hash
$rejected = $false
try { & $builder | Out-Null } catch { $rejected = $true }
if (!$rejected -or (Get-FileHash -LiteralPath $metadata).Hash -ne $before) { throw 'Existing package was silently overwritten' }
# Synthetic ID stays exclusively in the ignored lifecycle fixture.
[IO.File]::AppendAllText($metadata, "id=1234567890`n", [Text.UTF8Encoding]::new($false))
& $builder -Refresh | Out-Null
if (@(Get-Content -LiteralPath $metadata | Where-Object { $_ -eq 'id=1234567890' }).Count -ne 1) { throw 'Refresh lost or duplicated the existing ID' }
if (@(Get-ChildItem -LiteralPath (Join-Path $fixture 'build/workshop') -Directory -Filter 'previous-*').Count -ne 1) { throw 'Previous package was not retained' }
$before = (Get-FileHash -LiteralPath $metadata).Hash
foreach ($invalid in @('0','not-an-id','18446744073709551616')) {
    $rejected = $false
    try { & $builder -Refresh -WorkshopId $invalid | Out-Null } catch { $rejected = $true }
    if (!$rejected -or (Get-FileHash -LiteralPath $metadata).Hash -ne $before) { throw 'Invalid ID changed the package' }
}
$source = Join-Path $fixture 'Contents/mods/ModSettingsFolders'
[IO.File]::WriteAllText((Join-Path $source '.env'), 'synthetic fixture, no credentials')
$rejected = $false
try { & $builder -Refresh | Out-Null } catch { $rejected = $true }
if (!$rejected -or (Get-FileHash -LiteralPath $metadata).Hash -ne $before) { throw 'Sensitive file was accepted or previous package changed' }
Write-Output 'PASS Workshop lifecycle: new package, explicit refresh, ID retention, previous-package preservation, invalid/overflow IDs rejected, sensitive files rejected without replacing prior package'
