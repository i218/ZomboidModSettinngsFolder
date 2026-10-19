$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$fixture = Join-Path $root "build/workshop-sync-tests/$([Guid]::NewGuid().ToString('N'))"
$sync = Join-Path $root 'Sync-Workshop.ps1'
function New-Fixture([string]$Name,[string]$Identity='ModSettingsFolders') {
    $user = Join-Path $fixture $Name
    $folder = Join-Path $user 'Workshop/ModSettingsFolders'
    $mod = Join-Path $folder 'Contents/mods/ModSettingsFolders'
    New-Item -ItemType Directory -Path (Join-Path $mod '42'),(Join-Path $folder 'Contents/mods/AnotherMod') -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $folder 'workshop.txt'),"version=1`nid=1234567890`ntitle=Custom title`ndescription=Custom description`nvisibility=friendsOnly`n",[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText((Join-Path $folder 'preview.png'),'existing cover bytes')
    [IO.File]::WriteAllText((Join-Path $folder 'notes.txt'),'existing notes')
    [IO.File]::WriteAllText((Join-Path $mod '42/mod.info'),"id=$Identity`nmodversion=0.1.1`n")
    [IO.File]::WriteAllText((Join-Path $mod 'old.txt'),'old version')
    [IO.File]::WriteAllText((Join-Path $folder 'Contents/mods/AnotherMod/keep.txt'),'unrelated mod')
    return $folder
}
$target = New-Fixture 'normal'
$metadata = (Get-FileHash -LiteralPath (Join-Path $target 'workshop.txt')).Hash
$cover = (Get-FileHash -LiteralPath (Join-Path $target 'preview.png')).Hash
$result = & $sync -WorkshopDirectory $target
if ($result.Status -ne 'Updated' -or !$result.MetadataPreserved) { throw 'Expected update' }
if ((Get-FileHash -LiteralPath (Join-Path $target 'workshop.txt')).Hash -ne $metadata -or (Get-FileHash -LiteralPath (Join-Path $target 'preview.png')).Hash -ne $cover) { throw 'Publication metadata or preview changed' }
if ([IO.File]::ReadAllText((Join-Path $target 'notes.txt')) -ne 'existing notes' -or [IO.File]::ReadAllText((Join-Path $target 'Contents/mods/AnotherMod/keep.txt')) -ne 'unrelated mod') { throw 'Unrelated files changed' }
if (!(Test-Path -LiteralPath (Join-Path $result.Target 'common/icon.png')) -or !(Test-Path -LiteralPath (Join-Path $result.Target 'common/poster.png'))) { throw 'Current images missing' }
if ([IO.File]::ReadAllText((Join-Path $result.Backup 'old.txt')) -ne 'old version') { throw 'Prior contents not backed up' }
$workshopRoot = [IO.Path]::GetFullPath((Split-Path -Parent $target)) + [IO.Path]::DirectorySeparatorChar
if ($result.Backup.StartsWith($workshopRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Backup leaked into Workshop tree' }
$again = & $sync -WorkshopDirectory $target
if ($again.Status -ne 'AlreadyCurrent' -or $again.Backup) { throw 'Idempotent sync failed' }
$foreign = New-Fixture 'foreign' 'AnotherMod'
$rejected=$false;try { & $sync -WorkshopDirectory $foreign | Out-Null } catch {$rejected=$true}
if (!$rejected -or [IO.File]::ReadAllText((Join-Path $foreign 'Contents/mods/ModSettingsFolders/old.txt')) -ne 'old version') { throw 'Foreign identity not protected' }
$badBackup = New-Fixture 'bad-backup'
$rejected=$false;try { & $sync -WorkshopDirectory $badBackup -BackupDirectory (Join-Path $badBackup 'backup') | Out-Null } catch {$rejected=$true}
if (!$rejected -or !(Test-Path -LiteralPath (Join-Path $badBackup 'Contents/mods/ModSettingsFolders/old.txt'))) { throw 'Unsafe backup location accepted' }
$linked = New-Fixture 'linked'
$outside = Join-Path $fixture 'outside'
New-Item -ItemType Directory -Path $outside -Force | Out-Null
[IO.File]::WriteAllText((Join-Path $outside 'sentinel.txt'),'preserve')
New-Item -ItemType Junction -Path (Join-Path $linked 'Contents/mods/ModSettingsFolders/common') -Target $outside | Out-Null
$rejected=$false;try { & $sync -WorkshopDirectory $linked | Out-Null } catch {$rejected=$true}
if (!$rejected -or [IO.File]::ReadAllText((Join-Path $outside 'sentinel.txt')) -ne 'preserve') { throw 'Linked target not protected' }
$locked = New-Fixture 'locked'
$lockPath = Join-Path $locked 'Contents/mods/ModSettingsFolders/old.txt'
$held = [IO.FileStream]::new($lockPath,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    $rejected=$false;try { & $sync -WorkshopDirectory $locked | Out-Null } catch {$rejected=$true}
    if (!$rejected) { throw 'Locked prior files accepted' }
} finally { $held.Dispose() }
if ([IO.File]::ReadAllText($lockPath) -ne 'old version') { throw 'Locked original files changed' }
$rollback = New-Fixture 'rollback'
$env:MSF_SYNC_REPOSITORY = $root
# Inject a failure into an in-memory test copy immediately after the new tree moves
# into place. Production script has no fault-injection switches.
$faulty = (Get-Content -LiteralPath $sync -Raw).Replace('$root = $PSScriptRoot','$root = $env:MSF_SYNC_REPOSITORY').Replace('Assert-SyncDigest $expected (Get-SyncDigest $target)',"throw 'Injected post-swap failure'")
$rejected=$false;try { & ([scriptblock]::Create($faulty)) -WorkshopDirectory $rollback | Out-Null } catch {$rejected=$true}
if (!$rejected -or [IO.File]::ReadAllText((Join-Path $rollback 'Contents/mods/ModSettingsFolders/old.txt')) -ne 'old version') { throw 'Post-swap failure did not restore original files' }
if ((Get-Content -LiteralPath (Join-Path $rollback 'workshop.txt') -Raw) -notmatch 'visibility=friendsOnly') { throw 'Rollback changed metadata' }
Write-Output 'PASS Workshop sync: verified update, backup outside uploads, exact metadata/cover preservation, other mods retained, idempotence, foreign identity/unsafe backup/junction/locked file rejection and post-swap rollback'
