param([Parameter(Mandatory=$true)][string]$Package)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$folder = (Resolve-Path -LiteralPath $Package).Path
$source = Join-Path $root 'Contents/mods/ModSettingsFolders'
$expected = @('preview.png','workshop.txt','Contents/mods/ModSettingsFolders/LICENSE')
foreach ($file in Get-ChildItem -LiteralPath $source -File -Recurse -Force) {
    $relative = $file.FullName.Substring($source.Length+1).Replace('\','/')
    $expected += "Contents/mods/ModSettingsFolders/$relative"
    $copy = Join-Path $folder "Contents/mods/ModSettingsFolders/$relative"
    if (!(Test-Path -LiteralPath $copy) -or (Get-FileHash -LiteralPath $copy).Hash -ne (Get-FileHash -LiteralPath $file.FullName).Hash) { throw "Missing/changed mod file: $relative" }
}
$files = @(Get-ChildItem -LiteralPath $folder -File -Recurse -Force)
foreach ($file in $files) {
    if ($file.Name -match '(?i)^(\.env|credentials(?:\.|$)|secrets(?:\.|$))' -or
        ($file.Extension -notin @('.lua','.json','.info','.txt','.png') -and $file.Name -ne 'LICENSE')) {
        throw 'Non-runtime or sensitive file in upload package'
    }
}
$actual = @($files | ForEach-Object { $_.FullName.Substring($folder.Length+1).Replace('\','/') })
$difference = @(Compare-Object -ReferenceObject $expected -DifferenceObject $actual)
if ($difference.Count) { throw 'Workshop inventory differs from the explicit allowed list' }
foreach ($file in Get-ChildItem -LiteralPath $folder -Recurse -Force) {
    if ($file.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Linked upload entries are forbidden' }
    if ($file.PSIsContainer -and $file.Name -in @('.git','build','tests','installer','.codex','.vscode')) { throw 'Private/development directory in upload package' }
}
if ((Get-FileHash -LiteralPath (Join-Path $folder 'Contents/mods/ModSettingsFolders/LICENSE')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root 'LICENSE')).Hash) { throw 'License differs' }
if ((Get-FileHash -LiteralPath (Join-Path $folder 'preview.png')).Hash -ne (Get-FileHash -LiteralPath (Join-Path $root 'workshop/preview.png')).Hash) { throw 'Cover differs' }
$metadata = Get-Content -LiteralPath (Join-Path $folder 'workshop.txt') -Encoding UTF8
foreach ($key in @('version','title','tags','visibility')) {
    if (@($metadata | Where-Object { $_.StartsWith("$key=") }).Count -ne 1) { throw "Missing/duplicate workshop field: $key" }
}
if ('version=1' -notin $metadata -or 'visibility=private' -notin $metadata) { throw 'Expected version=1 and private initial visibility' }
$ids = @($metadata | Where-Object { $_.StartsWith('id=') })
[UInt64]$parsedId = 0
if ($ids.Count -gt 1 -or ($ids.Count -eq 1 -and (!(($ids[0].Substring(3)) -match '^[1-9][0-9]{0,19}$') -or ![UInt64]::TryParse($ids[0].Substring(3),[ref]$parsedId)))) { throw 'Invalid or duplicate Workshop ID' }
$description = ($metadata | Where-Object { $_.StartsWith('description=') } | ForEach-Object { $_.Substring(12) }) -join "`n"
if ($description.Length -lt 100 -or $description.Length -gt 7800) { throw 'Description length outside the upload budget' }
$png = [IO.File]::ReadAllBytes((Join-Path $folder 'preview.png'))
if ($png.Length -gt 1024000 -or [BitConverter]::ToString($png[0..7]) -ne '89-50-4E-47-0D-0A-1A-0A') { throw 'Expected PNG below the native size limit' }
$width = [BitConverter]::ToUInt32([byte[]]($png[19..16]),0)
$height = [BitConverter]::ToUInt32([byte[]]($png[23..20]),0)
if ($width -ne 512 -or $height -ne 512) { throw 'Expected square 512px cover' }
Write-Output "PASS clean Workshop inventory ($($files.Count) files), source hashes, metadata, private visibility, ID and preview ($width x $height)"
