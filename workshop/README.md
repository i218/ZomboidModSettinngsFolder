# Workshop upload preparation

This folder contains source metadata and original cover artwork. Nothing here publishes or uploads to Steam. The game and Steam client are not launched by the build or validation scripts.

1. Run `python -B workshop/Make-Preview.py` only when changing the artwork (Pillow + Windows Segoe UI fonts). The generated SVG is editable source; PNG is the upload image. Run `python -B workshop/Make-GameImages.py` to render the text-free 256px in-game list icon and copy the 512px cover to the in-game poster. Both are stored in `common` and referenced by `42/mod.info`.
2. Write `release-notes/<modversion>.txt` with Steam-ready release changes. Run `./Build-Workshop.ps1`. The changelog is copied beside the ZIP/installer as `build/distributions/<modversion>/CHANGELOG-Steam.txt`, outside the upload folder. The result is `build/workshop/<modversion>/ModSettingsFolders`.
3. Run `./Test-Workshop.ps1 -GameDirectory <game> -JdkDirectory <JDK>`. It checks an explicit inventory, byte-identical mod sources, metadata and PNG, then calls the installed game's `SteamWorkshopItem` validator. No Steam session, account credentials or upload calls are used.
4. When ready to publish manually, copy only that generated **ModSettingsFolders** folder to your Zomboid user directory's **Workshop** folder (normally `%USERPROFILE%/Zomboid/Workshop`). For `-cachedir`, use that user directory. Do not copy the repository.
5. Open the game's Workshop uploader, choose the folder and review the page. Initial visibility is **private**. This package includes an English description and a Russian summary, valid Build 42/Interface/QoL tags, and a 512px PNG cover. It deliberately has no Workshop ID until the first item is created.
6. After first publication, keep the `id=` written by the game. For updates, pass `-WorkshopId <existing-id>` when building a new version. Rebuilding an existing prepared folder requires `-Refresh` and retains its existing ID if no replacement is supplied. Previous prepared folders are moved aside rather than deleted. Do not clear the ID unless deliberately creating a separate Workshop page.

The generated upload folder contains only `workshop.txt`, `preview.png`, and `Contents/mods/ModSettingsFolders` with mod files and the MIT license. No Git history, EXE, ZIP, test harness, user configuration, logs or development tools are included. The authoring SVG and generator stay in the repository and are not uploaded.

The native validator checks package structure; it does not establish live gameplay compatibility, successful publication, or acceptance of Steam's legal agreement.

## Updating the existing local authoring folder

Run `./Sync-Workshop.ps1` after preparing and checking the current version. It defaults to the current user's `Zomboid/Workshop/ModSettingsFolders`; `-WorkshopDirectory` supports a custom user directory. It requires an existing mod with the correct ID and updates only `Contents/mods/ModSettingsFolders`.

The existing `workshop.txt`, Workshop ID, title, description, visibility, cover and other root files remain byte-identical. Other mods in the same Workshop item are retained. The old mod tree is moved to `Zomboid/ModSettingsFoldersBackups/Workshop/<transaction>/previous`, outside the upload tree. A failed swap is rolled back; identical files cause a verification-only no-op. Junctions, foreign identities and backup paths within the Workshop tree are rejected. `tests/Test-WorkshopSync.ps1` exercises these cases and an injected post-swap failure under ignored build fixtures.

Delivery policy is recorded in `AGENTS.md`: push after three new local commits or a major feature release, synchronizing the local authoring folder at the same time. Uploading to Steam remains a separate manual action by the user.
