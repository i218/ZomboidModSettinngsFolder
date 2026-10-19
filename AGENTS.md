# Delivery workflow

- Commit completed, checked changes locally. Push after **three new local commits**
  since the last push, or when delivering a **major/large feature release**.
  Significance is determined by user impact, not code size or version numbering.
  Restoring unavailable primary functionality (such as the entire folder GUI)
  counts as a major delivery and triggers an immediate push.
  An ordinary patch version alone does not trigger an early push. Do not create
  filler commits or rewrite history to satisfy the threshold. A direct user request
  to push takes precedence.
- Every release prepared for Steam must include a concise, user-facing changelog.
  Keep its source in `release-notes/<version>.txt` and deliver a copy as
  `build/distributions/<version>/CHANGELOG-Steam.txt`, beside the release artifacts.
  Include the changelog in the delivery response. Never copy it into Workshop
  upload folders, runtime files or installer payloads.
- At each push, also synchronize this mod's local Zomboid Workshop authoring folder
  using `Sync-Workshop.ps1`, after verifying the prepared package. Check the real
  folder first; it may contain the user's live publication metadata.
- Synchronize **only** `Contents/mods/ModSettingsFolders`. Preserve the existing
  `workshop.txt`, Workshop ID, title, description, visibility, root preview, other
  root files and other mods. Store backups outside Workshop upload folders.
- Steam upload remains manual. A Git push or local Workshop synchronization never
  authorizes launching the game, uploading, creating another Workshop item or
  changing the item's visibility.
- Before a push, run the privacy check. Use a normal non-force branch push and
  verify local/remote revisions match. Report the local Workshop synchronization
  result separately from Git and Steam publication.
