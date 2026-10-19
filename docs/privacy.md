# Public repository privacy check

The initial unpublished commit was sanitized before its first push. Commit author
and committer use the public handle `i218` and GitHub's noreply email domain. No
global Git identity configuration was changed. The test runner takes an explicit
game directory instead of embedding the author's installation path.

The tracked payload contains this mod's source, translations, documentation and
synthetic test fixtures. Game code is extracted locally into ignored build output
for tests; it is not committed. JDK/game binaries, generated archives, logs, crash
dumps, local settings, secrets and editor/agent configuration are excluded.

Before pushing, run `python -B tests/check_privacy.py`. It checks tracked working
files and every commit reachable from local Git refs, including metadata, for
common credentials, private keys, personal email, machine paths and unexpected
binary/config files. Findings contain only locations and categories. This is a
targeted scanner and manual review aid, not a universal secret detector. Review
the staged diff and outgoing commit range too. Do not force-add local data.

The runtime has no network calls, telemetry or server commands. It reads/writes
only its local layout files through the game's file API and calls the original
settings UI. Its operation does not upload folder names or game settings.

Git push sends reachable commits, not ignored files, local configuration,
credentials, reflogs or unreachable superseded commits. Use an ordinary branch
push; do not use mirror push, push all refs or create public diagnostic bundles.
