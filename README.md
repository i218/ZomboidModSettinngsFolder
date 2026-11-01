# Mod Settings Folders

Standalone Project Zomboid Build 42 client mod. Organizes sections in **Options → Mods** into collapsible folders, while retaining the game's original settings controls.

## Install

Subscribe through Steam Workshop, enable **Mod Settings Folders**, and restart the game.
For manual installation, copy `Contents/mods/ModSettingsFolders` from the prepared
Workshop package into your Zomboid user directory's `mods` folder. The resulting
path must be `mods/ModSettingsFolders/42/mod.info`. Close the game before replacing
files. Local settings are stored separately in the Zomboid user directory.

No Java bridge, Mod Options Workshop dependency, server installation or aircraft mod is required. It uses the built-in Build 42 `PZAPI.ModOptions` registry. Build 41 is unsupported.

## Use

- Use the search box above **New folder** to find sections across every folder, including collapsed folders. Matching ignores case and includes setting labels, source mod names, folder names and IDs. Spaces and underscores are interchangeable. **Ctrl+F** focuses the search; clearing it restores the folder tree.
- Open Options → Mods. Create a folder with **New folder**.
- Right-click a section → **Move to folder**. Right-click a folder to rename, reorder or remove it.
- Click a folder to collapse/expand it; click a section to show its settings. **All sections** shows the complete form.
- Removing a folder moves its sections to **Unfiled**, without deleting settings.
- Narrow windows have a **Folders / settings** toggle instead of a permanent sidebar.
- Gamepad: arrows select a tree row; A opens it, X opens its context menu, Y creates a folder. B returns from the settings form to navigation, then exits through the native settings confirmation. Shoulder buttons switch native tabs.

Folder changes save immediately and separately from the game's Apply/Save/Back buttons. Pending setting edits survive folder navigation and retain their native apply/cancel behavior. Existing controls, callback arguments, GameOption registrations and keybind structures are preserved.

## Import from ModFolders

When ModFolders is installed, **Import settings from... → ModFolders** appears
below New folder. It reads the saved `ModFolders.cfg` once, on request, and never
writes to that mod or its configuration. Mod setting values are not imported.

Folders with the same name (ignoring case) merge. Folders sharing an assigned
settings section also merge transitively, retaining the earliest existing local
folder's name, order and collapse state. Other local assignments remain intact.
Sections are matched by exact mod ID first, then by a unique normalized ID or
display name. Ambiguous or unmatched mods are skipped and counted in the result;
mods without a settings section cannot be assigned. Imported folders with no matched settings sections are skipped; existing local
folders, including manually created empty folders, are preserved. Repeating the same import does not duplicate folders.
Missing/unsupported data or a layout exceeding limits leaves the layout unchanged.
A successful import uses the normal local layout backup.

Sections without a meaningful title use the source mod name from mod metadata in
the sidebar and native form heading. Explicit section titles and stable IDs remain
unchanged; unknown or ambiguous source metadata falls back to the section ID.

## Local data and compatibility

Layout lives in `ModSettingsFolders.cfg` in the Zomboid user directory, with the previous valid layout in `ModSettingsFolders.previous.cfg`. Membership uses each section's `modOptionsID`, rather than its translated name. Assignments for disabled mods remain for their return. English and Russian UI are included; folder names support Unicode.

The format is bounded text, never executable Lua. If the main layout is damaged, a valid backup is used. If neither file is usable, or a newer format is detected, the native settings form remains available and those files are preserved. To reset folders, close the game and move both files out of the user directory. Mod setting values remain in native `ModOptions.ini`.

Supports sections registered through the stock Build 42 API. Separate sandbox, keybinding, mod-selection and custom independent settings windows are outside scope. The mod chains existing form builders. If section boundaries cannot be identified safely, it retains the native form; arbitrary total replacements and late asynchronous control insertion are not guaranteed compatible. No dedicated-server state or gameplay behavior is changed.

Limits: 99 folders, 160 UTF-16 code units per name, 2000 retained memberships, 512 KiB layout file. Folders are one level deep. Layout is local to a user directory, not a save or server.

## Development

`./Test.ps1 -GameDirectory <installed game> -JdkDirectory <JDK>` runs the installed game's Kahlua VM with its actual `PZAPI.ModOptions`, `GameOption` and settings form builder. UI and files are test doubles; no game session or user configuration is opened. JDK is needed only for this test harness, not for the mod. The JDK is found through `JAVA_HOME`, `javac` on PATH, or the explicit parameter.

`./Build-Workshop.ps1` prepares `build/workshop/<version>/ModSettingsFolders` and
copies Steam release notes to `build/distributions/<version>/CHANGELOG-Steam.txt`.
`./Sync-Workshop.ps1` updates the local authoring folder while preserving publication
metadata. Steam upload remains manual. Releases do not build installers.
See [verification details](docs/verification.md).
