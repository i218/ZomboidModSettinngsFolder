# Windows installer — 0.1.2

Run `ModSettingsFolders-Setup-0.1.2.exe`, close the game and choose your Zomboid user directory. The default is the current Windows user's Zomboid directory; a custom `-cachedir` location or its `mods` directory can be selected. The installer never changes the enabled-mod list. Enable Mod Settings Folders and restart the game afterwards.

The EXE is offline, unsigned and runs as the current user. It requires Windows .NET Framework 4.5 or newer, normally included with Windows 10/11. No Java, download, telemetry, registry entry, service or administrator elevation is used.

The complete ZIP and per-file SHA256 manifest are embedded. All entries are checked before filesystem changes; staged and installed files are verified as well. The manifest checks integrity, not publisher identity or authenticity of an externally replaced EXE. Compare `SHA256SUMS.txt` when transferring the build.

The install target is `mods/ModSettingsFolders`. A recognized previous version is moved to `ModSettingsFoldersBackups/<timestamp-and-random-id>` outside `mods` before the new version is committed. A failed install attempts to restore it. Other mods, saves, layout, `ModOptions.ini` and activation profiles are untouched. Repeating installation with identical files verifies them without creating another backup. An empty lock file remains in the selected user directory to coordinate installer instances.

Unsafe archive paths, drive/profile/Windows roots, network paths, junctions, symbolic links, unknown existing mod identities and concurrent installations are rejected. Staging uses a unique child of the selected user directory and is the only tree recursively cleaned up. Backups are never recursively removed.

For local automation, `--verify-payload` checks the embedded data without installing. `--install <user-directory>` performs the same installation without opening a window and returns a nonzero exit code on failure. Close Java-launched game sessions yourself: the preflight process check detects native Project Zomboid executable names, not arbitrary Java processes.

Build with `Build-Installer.ps1`; `-Rebuild` explicitly permits rebuilding the current version's EXE. Test with `tests/Test-Installer.ps1` (Python 3 on PATH). Tests compile a console runner against the same engine and embedded data and use only newly created directories under this repository's ignored `build` tree. They cover fresh/repeat installs, updates, backups, unrelated file/settings preservation, rollback at three transaction stages, locks, directory collisions, Unicode paths, invalid roots and malformed payloads. The actual EXE is also exercised through its non-GUI command line. GUI interaction and installation into a live game profile remain separate manual acceptance checks.

To uninstall, close the game and remove only `mods/ModSettingsFolders`; local layout files may be retained. To restore a backup, close the game, move the current mod folder aside and move the chosen backup back to `mods/ModSettingsFolders`.
