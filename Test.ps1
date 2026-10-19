param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$GameDirectory,
    [string]$JdkDirectory = $env:JAVA_HOME,
    [string]$SplitTabReference,
    [string]$CaptureOverride
)
$ErrorActionPreference = 'Stop'
if (!$JdkDirectory) {
    $compiler = Get-Command javac -ErrorAction SilentlyContinue
    if (!$compiler) { throw 'Pass -JdkDirectory or set JAVA_HOME to a JDK installation.' }
    $JdkDirectory = Split-Path -Parent (Split-Path -Parent $compiler.Source)
}
$root = $PSScriptRoot
$out = Join-Path $root 'build/tests'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$native = Get-Content -LiteralPath (Join-Path $GameDirectory 'media/lua/client/OptionScreens/MainOptions.lua') -Raw
$match = [regex]::Match($native, '(?s)function MainOptions:addModOptionsPanel\(\).*?(?=\r?\nfunction MainOptions:onObjHighlightColor)')
if (!$match.Success) { throw 'Unsupported native options builder' }
$fixture = Join-Path $out 'NativeModOptionsPanel.lua'
[IO.File]::WriteAllText($fixture, $match.Value + "`nMSF_StockBuilder=MainOptions.addModOptionsPanel`n", [Text.UTF8Encoding]::new($false))
$jar = Join-Path $GameDirectory 'projectzomboid.jar'
& (Join-Path $JdkDirectory 'bin/javac.exe') -cp $jar -d $out (Join-Path $root 'tests/KahluaCheck.java')
if ($LASTEXITCODE) { throw 'Harness compilation failed' }
$client = Join-Path $root 'Contents/mods/ModSettingsFolders/42/media/lua/client'
$captureSource = if ($CaptureOverride) { $CaptureOverride } else { Join-Path $client 'MSF/Capture.lua' }
$sources = @(
    (Join-Path $GameDirectory 'stdlib.lua'),
    (Join-Path $root 'tests/Bootstrap.lua'),
    (Join-Path $GameDirectory 'media/lua/client/OptionScreens/GameOption.lua'),
    (Join-Path $GameDirectory 'media/lua/client/PZAPI/ModOptions.lua'),
    $fixture,
    (Join-Path $client 'MSF/Model.lua'),
    (Join-Path $client 'MSF/Store.lua'),
    (Join-Path $root 'tests/ModelTests.lua'),
    $captureSource,
    (Join-Path $client 'MSF/UI.lua'),
    (Join-Path $client 'ModSettingsFolders.lua'),
    (Join-Path $root 'tests/IntegrationTests.lua')
)
if ($SplitTabReference) {
    $reference = Get-Content -LiteralPath $SplitTabReference -Raw
    $method = [regex]::Match($reference, '(?s)function Prefs\.addPanels\(screen, base, \.\.\.\).*?(?=\r?\nfunction Prefs\.buildPage)')
    if (!$method.Success) { throw 'Installed split-tab reference method not found' }
    $referenceFixture = Join-Path $out 'InstalledSplitTab.lua'
    [IO.File]::WriteAllText($referenceFixture, "MSF_ReferencePrefs={}`nlocal Prefs=MSF_ReferencePrefs`n" + $method.Value, [Text.UTF8Encoding]::new($false))
    $sources += $referenceFixture
}
$sources += (Join-Path $root 'tests/CompatibilityTests.lua')
& (Join-Path $GameDirectory 'jre64/bin/java.exe') -cp "$jar;$out" KahluaCheck @sources
if ($LASTEXITCODE) { throw 'Kahlua checks failed' }
