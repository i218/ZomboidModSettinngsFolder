param(
    [string]$WorkshopDirectory = (Join-Path ([Environment]::GetFolderPath('UserProfile')) 'Zomboid/Workshop/ModSettingsFolders'),
    [string]$BackupDirectory,
    [string]$Package
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
function Assert-SyncChild([string]$Parent,[string]$Path) {
    $prefix = [IO.Path]::GetFullPath($Parent).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    if (![IO.Path]::GetFullPath($Path).StartsWith($prefix,[StringComparison]::OrdinalIgnoreCase)) { throw 'Sync path escapes its intended directory' }
}
function Assert-SyncNoLinks([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if ((Test-Path -LiteralPath $current) -and ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Linked synchronization paths are not supported' }
        $current = [IO.Path]::GetDirectoryName($current)
    }
}
function Get-SyncDigest([string]$Directory) {
    Assert-SyncNoLinks $Directory
    $result = @{}
    $pending = [Collections.Generic.Stack[string]]::new();$pending.Push($Directory)
    while ($pending.Count) {
        foreach ($entry in Get-ChildItem -LiteralPath $pending.Pop() -Force) {
            if ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked synchronization entries are not supported' }
            if ($entry.PSIsContainer) { $pending.Push($entry.FullName) }
            else { $result[$entry.FullName.Substring($Directory.Length+1)] = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash }
        }
    }
    return $result
}
function Assert-SyncDigest($Expected,$Actual) {
    if ($Expected.Count -ne $Actual.Count) { throw 'Synchronization file inventory differs' }
    foreach ($name in $Expected.Keys) { if ($Expected[$name] -ne $Actual[$name]) { throw "Synchronization checksum differs: $name" } }
}
function Get-SyncRootFiles([string]$Directory) {
    $result = @{}
    foreach ($entry in Get-ChildItem -LiteralPath $Directory -File -Force) {
        Assert-SyncNoLinks $entry.FullName
        $result[$entry.Name] = (Get-FileHash -LiteralPath $entry.FullName -Algorithm SHA256).Hash
    }
    return $result
}
$info = Get-Content -LiteralPath (Join-Path $root 'Contents/mods/ModSettingsFolders/42/mod.info') -Raw
$version = [regex]::Match($info,'(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
if (!$Package) { $Package = Join-Path $root "build/workshop/$version/ModSettingsFolders" }
$Package = (Resolve-Path -LiteralPath $Package).Path
& (Join-Path $root 'tests/Verify-Workshop.ps1') -Package $Package | Out-Host
$WorkshopDirectory = (Resolve-Path -LiteralPath $WorkshopDirectory).Path.TrimEnd('\','/')
Assert-SyncNoLinks $WorkshopDirectory
if (!(Test-Path -LiteralPath (Join-Path $WorkshopDirectory 'workshop.txt') -PathType Leaf)) { throw 'Existing publication metadata is required; this script does not create Workshop items' }
$source = Join-Path $Package 'Contents/mods/ModSettingsFolders'
$target = Join-Path $WorkshopDirectory 'Contents/mods/ModSettingsFolders'
Assert-SyncChild $WorkshopDirectory $target
Assert-SyncNoLinks $target
if (!(Test-Path -LiteralPath $target -PathType Container)) { throw 'Expected existing ModSettingsFolders authoring folder' }
$identity = Get-Content -LiteralPath (Join-Path $target '42/mod.info') -Raw
if ([regex]::Matches($identity,'(?m)^id=ModSettingsFolders\r?$').Count -ne 1 -or [regex]::Matches($identity,'(?m)^id=').Count -ne 1) { throw 'Target mod identity differs; nothing changed' }
$expected = Get-SyncDigest $source
$preserved = Get-SyncRootFiles $WorkshopDirectory
if (!$BackupDirectory) {
    $userDirectory = Split-Path -Parent (Split-Path -Parent $WorkshopDirectory)
    $BackupDirectory = Join-Path $userDirectory 'ModSettingsFoldersBackups/Workshop'
}
$BackupDirectory = [IO.Path]::GetFullPath($BackupDirectory)
$workshopRoot = [IO.Path]::GetFullPath((Split-Path -Parent $WorkshopDirectory)).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
if (($BackupDirectory + [IO.Path]::DirectorySeparatorChar).StartsWith($workshopRoot,[StringComparison]::OrdinalIgnoreCase)) { throw 'Backups must stay outside the Workshop upload tree' }
Assert-SyncNoLinks $BackupDirectory
New-Item -ItemType Directory -Path $BackupDirectory -Force | Out-Null
$lockPath = Join-Path $BackupDirectory '.sync.lock'
Assert-SyncChild $BackupDirectory $lockPath;Assert-SyncNoLinks $lockPath
$syncLock = [IO.FileStream]::new($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    $current = Get-SyncDigest $target
    $same = $current.Count -eq $expected.Count
    foreach ($name in $expected.Keys) { if ($current[$name] -ne $expected[$name]) { $same = $false } }
    if ($same) {
        Assert-SyncDigest $preserved (Get-SyncRootFiles $WorkshopDirectory)
        [pscustomobject]@{Status='AlreadyCurrent';Version=$version;Target=$target;Backup=$null;MetadataPreserved=$true}
        return
    }
    $transaction = Join-Path $BackupDirectory ((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmmss') + '-' + [Guid]::NewGuid().ToString('N'))
    $staged = Join-Path $transaction 'staged';$previous = Join-Path $transaction 'previous';$rejected = Join-Path $transaction 'rejected'
    foreach ($path in @($transaction,$staged,$previous,$rejected)) { Assert-SyncChild $BackupDirectory $path;Assert-SyncNoLinks $path }
    New-Item -ItemType Directory -Path $transaction -Force | Out-Null
    Copy-Item -LiteralPath $source -Destination $staged -Recurse
    Assert-SyncDigest $expected (Get-SyncDigest $staged)
    # All absolute move endpoints are checked above; no recursive deletion is used.
    $oldMoved = $false;$newMoved = $false
    try {
        Assert-SyncNoLinks $target;Assert-SyncNoLinks $previous
        Move-Item -LiteralPath $target -Destination $previous;$oldMoved=$true
        Assert-SyncNoLinks $target
        Move-Item -LiteralPath $staged -Destination $target;$newMoved=$true
        Assert-SyncDigest $expected (Get-SyncDigest $target)
        Assert-SyncDigest $preserved (Get-SyncRootFiles $WorkshopDirectory)
    } catch {
        $failure = $_
        try {
            if ($newMoved) { Assert-SyncNoLinks $target;Move-Item -LiteralPath $target -Destination $rejected }
            if ($oldMoved) { Assert-SyncNoLinks $target;Assert-SyncNoLinks $previous;Move-Item -LiteralPath $previous -Destination $target }
        } catch { throw "Synchronization failed and rollback could not complete; previous files remain at $previous" }
        throw $failure
    }
    [pscustomobject]@{Status='Updated';Version=$version;Target=$target;Backup=$previous;MetadataPreserved=$true}
} finally { $syncLock.Dispose() }
