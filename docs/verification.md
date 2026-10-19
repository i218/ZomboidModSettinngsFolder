# Verification — 0.1.2

Date: 2026-10-19. Independent mod; installed game files and user configuration were not changed. No live game was launched for these checks.

## Automated evidence

`Test.ps1` compiles a test-only Java runner against the installed `projectzomboid.jar`. The shipped mod is Lua only; the runner is not part of its payload. The runner loads stock `stdlib.lua`, `GameOption.lua`, `PZAPI/ModOptions.lua`, and the actual `MainOptions:addModOptionsPanel()` body extracted at test time. Only UI primitives and file I/O are replaced with in-memory doubles.

Passing scenarios:

- Unicode folder names supplied as runtime Java strings, delimiter/percent escaping, strict bounded non-executable parsing, stable IDs, ordering, rename/delete, disabled-mod membership retention.
- Local save, previous-valid backup, corrupt-primary recovery, future-format preservation, write failure.
- Stock title, description, separator, checkbox, multiple checkbox, text, combo, slider, color, button and keybind registration.
- Identical control/GameOption/keybind references through section switches; pending edits retained; apply callbacks fire once on a change and not on a second unchanged apply.
- Stock keybind serialization into `ModOptions.ini`; button target and arguments retained.
- Duplicate display names remain separate; duplicate IDs trigger native fallback.
- Dynamic visibility callbacks cannot reveal an inactive section; returning preserves requested visibility.
- Wide/compact layouts, larger-font compact selection, context-menu moves, folder cursor retention, gamepad navigation, tab switching and deactivation routing.
- Original-builder error restores temporary hooks; injected navigation failure restores native tab ownership and controls.

`tests/Verify-Package.ps1` verifies the full ZIP inventory, Build 42 manifest path, byte-for-byte agreement with sources, absence of Java/native binaries, and archive SHA256. It does not install the mod.

Inspected native source SHA256:

| File | SHA256 |
| --- | --- |
| MainOptions.lua | BF705E2F64B6AAEE7ACECC1F99F0C496A4C300ACEBBB91A56E48CCF1B2507E96 |
| PZAPI/ModOptions.lua | 3393B4D669F6B832EC24628921338C87B4F8AA732E7985BB82F36E61BD69BE13 |
| GameOption.lua | E7494223C5695E595AE0E1EA61224F29ED67D7ECB2610F4DFDB1388169D68141 |

Two runtime differences were addressed: this Kahlua's `rawget` traverses table metatables, so own-field restoration uses table iteration; string bytes cannot round-trip Java Unicode as a two-digit hex stream, so layout text preserves Unicode and escapes only ASCII delimiters. Tests inject Unicode names directly, avoiding Lua compiler string-literal truncation.

## Still requires live acceptance

Enable the mod and restart, then test Options → Mods both from the main menu and a running save. Check Russian/English labels, long names, scrolling, font sizes, color popup placement, real keybind dialogs, gamepad focus and Apply/Back confirmation. Change several settings, navigate folders, cancel and reopen; repeat with Apply. Restart to check folder persistence; disable/re-enable a mod to check retained membership.

Installed Viewpoint wraps the native builder and MPOptimiser hooks rendering; these patterns informed chaining and control preservation. Full coexistence with those actual mods and other UI replacements is not established by the automated doubles. Dedicated-server joining and client checksum acceptance also remain untested. The mod sends no network commands and has no server component.
