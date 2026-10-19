param([string]$PythonExecutable = "python")
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$info = Get-Content -LiteralPath (Join-Path $root 'Contents/mods/ModSettingsFolders/42/mod.info') -Raw
$version = [regex]::Match($info, '(?m)^modversion=([0-9]+\.[0-9]+\.[0-9]+)\s*$').Groups[1].Value
$out = Join-Path $root "build/distributions/$version"
$payload = Join-Path $out "ModSettingsFolders-$version.zip"
$setup = Join-Path $out "ModSettingsFolders-Setup-$version.exe"
$work = Join-Path $root 'build/installer'
$runner = Join-Path $work 'InstallerTests.exe'
$compiler = Join-Path $env:WINDIR 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
& $compiler /nologo /target:exe /main:InstallerTests "/out:$runner" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/resource:$payload,payload.zip" "/resource:$(Join-Path $work 'payload.manifest'),payload.manifest" (Join-Path $work 'Version.cs') (Join-Path $root 'installer/InstallEngine.cs') (Join-Path $root 'installer/Setup.cs') (Join-Path $root 'installer/InstallerTests.cs')
if ($LASTEXITCODE) { throw 'Installer test compilation failed' }
$fixture = Join-Path $root "build/installer-tests/$([Guid]::NewGuid().ToString('N'))"
& $runner $fixture
if ($LASTEXITCODE) { throw 'Installer tests failed' }
$junctionRoot = Join-Path $fixture 'junction-case'
$junctionTarget = Join-Path $fixture 'junction-external'
New-Item -ItemType Directory -Path $junctionRoot,$junctionTarget | Out-Null
[IO.File]::WriteAllText((Join-Path $junctionTarget 'sentinel.txt'), 'preserve')
New-Item -ItemType Junction -Path (Join-Path $junctionRoot 'mods') -Target $junctionTarget | Out-Null
$env:MSF_SETUP_TEST_JUNCTION = $junctionRoot
$env:MSF_SETUP_TEST_JUNCTION_TARGET = $junctionTarget
$env:MSF_SETUP_TEST_EXE = $setup
$env:MSF_SETUP_TEST_ROOT = Join-Path $fixture 'real-exe-cli'
@'
import os,subprocess
exe=os.environ['MSF_SETUP_TEST_EXE']
for args in [['--verify-payload'],['--install',os.environ['MSF_SETUP_TEST_ROOT']],['--install',os.environ['MSF_SETUP_TEST_ROOT']]]:
    result=subprocess.run([exe]+args,capture_output=True,text=True)
    assert result.returncode==0,(result.returncode,result.stderr)
    print(result.stdout.strip())
result=subprocess.run([exe,'--install',os.environ['MSF_SETUP_TEST_JUNCTION']],capture_output=True,text=True)
assert result.returncode!=0
from pathlib import Path
outside=Path(os.environ['MSF_SETUP_TEST_JUNCTION_TARGET'])
assert (outside/'sentinel.txt').read_text()=='preserve' and len(list(outside.iterdir()))==1
print('PASS actual NTFS junction rejected without modifying its target')
result=subprocess.run([exe,'--unknown'],capture_output=True,text=True)
assert result.returncode!=0
print('PASS real EXE payload verification, fresh install, repeat install and invalid argument rejection')
'@ | & $PythonExecutable -B -
if ($LASTEXITCODE) { throw 'Real installer EXE checks failed; Python 3 must be available on PATH.' }
