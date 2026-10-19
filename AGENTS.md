# Delivery workflow

- Commit completed, checked changes locally. Push after **three new local commits**
  since the last push, or when delivering a **major/large feature release**.
  An ordinary patch version alone does not trigger an early push. Do not create
  filler commits or rewrite history to satisfy the threshold. A direct user request
  to push takes precedence.
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
