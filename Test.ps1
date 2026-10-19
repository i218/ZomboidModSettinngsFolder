param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$GameDirectory,
    [string]$JdkDirectory = $env:JAVA_HOME
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
[IO.File]::WriteAllText($fixture, $match.Value, [Text.UTF8Encoding]::new($false))
$jar = Join-Path $GameDirectory 'projectzomboid.jar'
& (Join-Path $JdkDirectory 'bin/javac.exe') -cp $jar -d $out (Join-Path $root 'tests/KahluaCheck.java')
if ($LASTEXITCODE) { throw 'Harness compilation failed' }
$client = Join-Path $root 'Contents/mods/ModSettingsFolders/42/media/lua/client'
$sources = @(
    (Join-Path $GameDirectory 'stdlib.lua'),
    (Join-Path $root 'tests/Bootstrap.lua'),
    (Join-Path $GameDirectory 'media/lua/client/OptionScreens/GameOption.lua'),
    (Join-Path $GameDirectory 'media/lua/client/PZAPI/ModOptions.lua'),
    $fixture,
    (Join-Path $client 'MSF/Model.lua'),
    (Join-Path $client 'MSF/Store.lua'),
    (Join-Path $root 'tests/ModelTests.lua'),
    (Join-Path $client 'MSF/Capture.lua'),
    (Join-Path $client 'MSF/UI.lua'),
    (Join-Path $client 'ModSettingsFolders.lua'),
    (Join-Path $root 'tests/IntegrationTests.lua')
)
& (Join-Path $GameDirectory 'jre64/bin/java.exe') -cp "$jar;$out" KahluaCheck @sources
if ($LASTEXITCODE) { throw 'Kahlua checks failed' }
