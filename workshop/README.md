# Workshop upload preparation

This folder contains source metadata and original cover artwork. Nothing here publishes or uploads to Steam. The game and Steam client are not launched by the build or validation scripts.

1. Run `python -B workshop/Make-Preview.py` only when changing the artwork (Pillow + Windows Segoe UI fonts). The generated SVG is editable source; PNG is the upload image.
2. Run `./Build-Workshop.ps1`. The result is `build/workshop/<modversion>/ModSettingsFolders`.
3. Run `./Test-Workshop.ps1 -GameDirectory <game> -JdkDirectory <JDK>`. It checks an explicit inventory, byte-identical mod sources, metadata and PNG, then calls the installed game's `SteamWorkshopItem` validator. No Steam session, account credentials or upload calls are used.
4. When ready to publish manually, copy only that generated **ModSettingsFolders** folder to your Zomboid user directory's **Workshop** folder (normally `%USERPROFILE%/Zomboid/Workshop`). For `-cachedir`, use that user directory. Do not copy the repository.
5. Open the game's Workshop uploader, choose the folder and review the page. Initial visibility is **private**. This package includes an English description and a Russian summary, valid Build 42/Interface/QoL tags, and a 512px PNG cover. It deliberately has no Workshop ID until the first item is created.
6. After first publication, keep the `id=` written by the game. For updates, pass `-WorkshopId <existing-id>` when building a new version. Rebuilding an existing prepared folder requires `-Refresh` and retains its existing ID if no replacement is supplied. Previous prepared folders are moved aside rather than deleted. Do not clear the ID unless deliberately creating a separate Workshop page.

The generated upload folder contains only `workshop.txt`, `preview.png`, and `Contents/mods/ModSettingsFolders` with mod files and the MIT license. No Git history, EXE, ZIP, test harness, user configuration, logs or development tools are included. The authoring SVG and generator stay in the repository and are not uploaded.

The release is still marked as an early test version: local GUI and multiplayer acceptance are pending. The native validator checks package structure; it does not establish live gameplay compatibility, successful publication, or acceptance of Steam's legal agreement.
