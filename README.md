# Mod Settings Folders

Standalone Project Zomboid Build 42 client mod. Organizes sections in **Options → Mods** into collapsible folders, while retaining the game's original settings controls.

## Install

Run `ModSettingsFolders-Setup-0.1.2.exe` and choose the Zomboid user directory. Close the game first. Existing mod files are backed up under `ModSettingsFoldersBackups`; local settings and the enabled-mod list are preserved. Enable the mod and restart after installation. The installer is unsigned; no administrator rights or downloads are required. Windows .NET Framework 4.5 or newer is required (normally present on Windows 10/11).

For manual installation, extract `ModSettingsFolders-0.1.2.zip` into your Zomboid user directory's `mods` folder. The resulting path must be `mods/ModSettingsFolders/42/mod.info`. Enable **Mod Settings Folders** and restart the game to load its main-menu code. The Zomboid user directory is normally `%USERPROFILE%/Zomboid`, but `-cachedir` can change it.

No Java bridge, Mod Options Workshop dependency, server installation or aircraft mod is required. It uses the built-in Build 42 `PZAPI.ModOptions` registry. Build 41 is unsupported.

## Use

- Open Options → Mods. Create a folder with **New folder**.
- Right-click a section → **Move to folder**. Right-click a folder to rename, reorder or remove it.
- Click a folder to collapse/expand it; click a section to show its settings. **All sections** shows the complete form.
- Removing a folder moves its sections to **Unfiled**, without deleting settings.
- Narrow windows have a **Folders / settings** toggle instead of a permanent sidebar.
- Gamepad: arrows select a tree row; A opens it, X opens its context menu, Y creates a folder. B returns from the settings form to navigation, then exits through the native settings confirmation. Shoulder buttons switch native tabs.

Folder changes save immediately and separately from the game's Apply/Save/Back buttons. Pending setting edits survive folder navigation and retain their native apply/cancel behavior. Existing controls, callback arguments, GameOption registrations and keybind structures are preserved.

## Local data and compatibility

Layout lives in `ModSettingsFolders.cfg` in the Zomboid user directory, with the previous valid layout in `ModSettingsFolders.previous.cfg`. Membership uses each section's `modOptionsID`, rather than its translated name. Assignments for disabled mods remain for their return. English and Russian UI are included; folder names support Unicode.

The format is bounded text, never executable Lua. If the main layout is damaged, a valid backup is used. If neither file is usable, or a newer format is detected, the native settings form remains available and those files are preserved. To reset folders, close the game and move both files out of the user directory. Mod setting values remain in native `ModOptions.ini`.

Supports sections registered through the stock Build 42 API. Separate sandbox, keybinding, mod-selection and custom independent settings windows are outside scope. The mod chains existing form builders. If section boundaries cannot be identified safely, it retains the native form; arbitrary total replacements and late asynchronous control insertion are not guaranteed compatible. No dedicated-server state or gameplay behavior is changed.

Limits: 99 folders, 160 UTF-16 code units per name, 2000 retained memberships, 512 KiB layout file. Folders are one level deep. Layout is local to a user directory, not a save or server.

## Development

`./Test.ps1 -GameDirectory <installed game> -JdkDirectory <JDK>` runs the installed game's Kahlua VM with its actual `PZAPI.ModOptions`, `GameOption` and settings form builder. UI and files are test doubles; no game session or user configuration is opened. JDK is needed only for this test harness, not for the mod. The JDK is found through `JAVA_HOME`, `javac` on PATH, or the explicit parameter.

`./Build.ps1` creates a versioned, hash-manifested ZIP under `build/distributions/0.1.2`. Generated game-source test fixtures are not distributed. See [verification details](docs/verification.md).

`./Build-Installer.ps1` builds a standalone Windows EXE with an embedded, SHA256-verified payload using the installed .NET Framework compiler. No NuGet or network is used. `-Rebuild` explicitly permits replacing the current version's EXE; previous version folders remain intact. See [installer checks](docs/installer.md).
