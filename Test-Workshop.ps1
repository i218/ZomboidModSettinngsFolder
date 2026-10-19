param(
    [Parameter(Mandatory=$true)][string]$GameDirectory,
    [Parameter(Mandatory=$true)][string]$JdkDirectory,
    [string]$Package
)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
if (!$Package) {
    $info = Get-Content -LiteralPath (Join-Path $root 'Contents/mods/ModSettingsFolders/42/mod.info') -Raw
    $version = [regex]::Match($info, '(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
    $Package = Join-Path $root "build/workshop/$version/ModSettingsFolders"
}
$Package = (Resolve-Path -LiteralPath $Package).Path
& (Join-Path $root 'tests/Verify-Workshop.ps1') -Package $Package
$out = Join-Path $root 'build/workshop-tests'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$jar = Join-Path $GameDirectory 'projectzomboid.jar'
& (Join-Path $JdkDirectory 'bin/javac.exe') -cp $jar -d $out (Join-Path $root 'tests/WorkshopCheck.java')
if ($LASTEXITCODE) { throw 'Workshop validator harness compilation failed' }
Push-Location $GameDirectory
try {
    & (Join-Path $GameDirectory 'jre64/bin/java.exe') -cp "$jar;$GameDirectory/*;$out" WorkshopCheck $Package
    if ($LASTEXITCODE) { throw 'Native Workshop validation failed' }
} finally { Pop-Location }
