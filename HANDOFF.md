# HANDOFF — Walk With Him

Public Godot project for Chris Gold (GitHub: AshThunder). This file is the brief for an agent picking the game up in Google Antigravity. Read it before changing code. Also see `AGENTS.md` and `CREDITS.md`.

## What it is

**Walk With Him** is a touch-first, low-poly 3D game about the life of Jesus, told through the eyes of a shepherd's child who grows up as the story moves on. Scripture is the King James Version, quoted verbatim. Invented dialogue is only a short narrative bridge and is marked "Fiction" in the UI. The tone should stay reverent and consistent with an RCCG / Pentecostal background: do not add doctrine, do not paraphrase verses, do not treat miracles as puzzles to "solve."

The long-term story runs from the Nativity to the Ascension. The current build plays from the shepherds' field through Cana (the water into wine) and then ends. Chapters 6 and 7 are the next gap in the story, not the Nativity.

Package name: `com.walkwithhim.prototype`. Display name: Walk With Him. Current version: **0.4.0** (version code 4), branch tip of `lead-the-flock`.

## Current state (verified against the code, Nov 2026)

This is **not** still a Nazareth-to-Cana-only slice, and the Nativity is **not** the next chapter to build. History:

| Version | What landed |
|---|---|
| v0.2.0 | Nazareth to Cana vertical slice (John 2:1-11), crash-safety (Back gesture, orphan coroutines), minimap/map/waypoint, save + continue |
| v0.3.0 | Nativity chapters 1-5, first age jump into Nazareth, chapter select, voices, night/temple music |
| v0.4.0 (current) | "Lead the Flock" rework: flock road loop, angels spectacle, Memory Stones, camp journal, Road of the Day |

**New Game** starts at chapter 1, **Lead the Flock** (`n1_flock`), not at Nazareth. The flow is:

1. Lead a named flock along a short road to the fire (drag to walk, tap to swing a staff). Arrival card, Memory Stone (Psalm 23:1), camp journal.
2. Glory in the Sky — look up (drag a finger up; if no one does, the sky lifts by itself), the angel and the host, a pose choice (Kneel / Praise / Look up in wonder), another Memory Stone (Luke 2:11), camp.
3. Bethlehem — walk up to stables and look inside, matching the sign of swaddling clothes and a manger.
4. The Presentation — catch two doves by steering a cage in the Temple, then Simeon and Anna.
5. The Star — trace a path across the night sky (it cannot fail; leave it and the star draws its own road). Four wise-men figures are a placeholder; the text does not say how many there were.
6. Years Pass — two taps on glowing doorpost marks grow the child into a teen, then an adult, and the game jumps to Nazareth. **This currently skips chapters 6 and 7.**
7. Chapters 8-10: Nazareth (find Naomi's scroll, walk with Jesus), the road to Cana, the wedding. Fill the six waterpots by **tapping** them (servants also pour on their own), tap a pot to draw some out, bear the cup to the governor of the feast. The slice then ends and the checkpoint save is cleared.

The older chapter 1 prototype, "Gather the lambs into the fold" (`n1_classic`), is still playable from the chapter list as "The Night Field (first version)."

**Road of the Day** is a date-seeded flock road from the title screen (one walk per calendar day is recorded; no streak is kept). Flock roster, Memory Stones, journal, wool tint, and best scores live in a **meta** file, separate from the story checkpoint save. New Game resets both; Continue restores the checkpoint. Chapter select starts a chapter fresh.

Two user files, both JSON, written atomically:

- Checkpoint: `user://walk_with_him_save.json` (version 1)
- Keepsakes: `user://walk_with_him_meta.json` (roster, stones, journal, `daily_done`, `daily_total`, wool `tint`, `best`)

Nothing in the Nativity / flock loop is a fail state: wolves scatter lambs but never harm them; a lamb that wandered is found again at camp; a patience whistle can help in the classic fold; the sky and the star complete themselves if the player does nothing.

### Mini-game types already used

New chapters must use a **different type from the one just before them**. Types already in the build, in story order:

| Chapter | Type |
|---|---|
| 1 Lead the Flock | Steering a flock; staff tap to scatter wolves |
| 1 classic (optional) | Herding by walking toward lambs so they flee into the fold |
| 2 Glory in the Sky | Look-up spectacle + a three-way pose choice (not scored) |
| 3 The Manger | Search / peek with a two-clue sign |
| 4 The Presentation | Catching (steer a cage onto doves) |
| 5 The Star | Tracing a path with a finger |
| Age jump | Ritual tap on a doorpost mark |
| 8 Nazareth | Exploration and a fetch |
| 9 Road to Cana | Walking / following |
| 10 Cana | Tap-to-fill pots, tap-to-draw, carry the cup |

Hold-to-pour is a good *future* type; it is **not** what Cana does today.

## Godot version and how to open / run

- Engine: **Godot 4.7.2** (`config/features` is `"4.7"`; `CREDITS.md` names 4.7.2). Use 4.7.2, not 4.6.x.
- Renderer: GL Compatibility (desktop and mobile).
- Main scene: `res://scenes/main.tscn` (a single `Main` node running `scripts/main.gd`).
- Autoloads: `Game` (`scripts/data.gd`), `Audio` (`scripts/audio.gd`), `Touch` (`scripts/touch.gd`).
- Viewport: 1080x1920, portrait, window override 540x960, stretch `canvas_items` / `expand`. Mouse emulates touch; a finger does not also fire mouse events.
- Open the project folder in Godot 4.7.2 (or Antigravity with the Godot extension) and press Play. On desktop, drag is a virtual stick and a short press is a world tap.

Headless checks used on the original box:

```bash
# Import / parse only
godot --headless --path . --import --quit

# Nazareth -> Cana playtest (touch events only)
godot --headless --path . res://tests/playtest.tscn

# Lead the Flock playtest (headless). With screenshots, needs a display:
godot --headless --path . res://tests/flock_play.tscn
xvfb-run godot --path . res://tests/flock_play.tscn --resolution 1080x1920

# Screenshot tours (need a display)
xvfb-run godot --path . res://tests/shots.tscn --resolution 1080x1920
xvfb-run godot --path . res://tests/nat_shots.tscn --resolution 1080x1920
```

Chris tests builds on an Infinix Spark 40. A headless pass is not a substitute for that.

## Project structure

```
project.godot          # app config, autoloads, display, renderer
export_presets.cfg     # "Android Debug" only; no keystore passwords
CREDITS.md             # licences (Kenney CC0, OFL fonts, Piper voices, KJV)
data/kjv.json          # KJV verses used in-game (public domain)
data/lines.json        # spoken lines: id, speaker, kind (kjv|fiction), ref, text, dur
scenes/main.tscn       # the only packed scene; everything else is built in code
scripts/               # game code (see below)
assets/                # Kenney CC0 kits actually used: nature, survival, town
art/                   # generated ground/wall textures, app icons
audio/music|sfx|voice  # placeholder audio (ogg + .import)
fonts/                 # Zilla Slab, Barlow Condensed (OFL)
tools/                 # generators (audio, voices, textures, KJV, lines)
tests/                 # headless playtests and screenshot tours
shots/                 # reference screenshots from those tours (already in git)
_dl/                   # local Kenney zip downloads; gitignored, not required to run
```

Characters, animals, waterpots, tables, houses' fittings, lambs, doves, angels, star, stables and temple trim are built in code, not imported character packs.

### Scripts

| File | Role |
|---|---|
| `main.gd` | Story flow, title / name / chapter select, checkpoints, Nazareth-Cana, Back gesture, save / resume |
| `nativity.gd` | Chapters 1-5, Road of the Day, first age jump; dispatches into `Flock` and `Camp` |
| `flock.gd` | Lead the Flock road: named lambs, MultiMesh flock, staff, wolves, goals, settle / lost lambs |
| `roads.gd` | Story road + date-seeded Road of the Day layouts and light palettes |
| `camp.gd` | Arrival card, Memory Stone, camp tabs (flock / wool / journal) — all flat colour |
| `data.gd` | Autoload `Game`: KJV/lines, age stage, checkpoint save, meta (roster, stones, journal, daily) |
| `world.gd` | 3D world: camera, Nazareth / road / Cana builders, movement, pots, miracle, NPC travel |
| `areas.gd` | Nativity spaces: fields, Bethlehem, Temple, home doorpost; MultiMesh helpers |
| `person.gd` | Low-poly people and animals, poses, labels |
| `props.gd` | Shared 3D props and materials |
| `ui.gd` | All UI: title, chapters, HUD, dialogue, verses, map, pause, end. Chapter list lives here |
| `touch.gd` | Touch-only input: taps, virtual stick, gesture capture, TButton routing |
| `tbutton.gd` | Touch buttons that never leak into the world |
| `audio.gd` | Music, SFX, voice playback; respects settings |
| `startrace.gd` | Chapter 5 path-tracing overlay |
| `joydraw.gd` | On-screen stick drawing |
| `mapscreen.gd` | Full map |
| `minimap.gd` | Corner minimap |
| `waypoint.gd` | Objective marker |
| `anim.gd` | Small 3D tween helpers (pulse, and so on) |

`ui.gd` `CHAPTERS` is the list shown on the title screen. It already notes that chapters 6 (Egypt) and 7 (the Temple at twelve) are not built. Checkpoints are the `STAGES` dictionary in `main.gd`.

## Android export (Spark 40)

The committed preset is **Android Debug** only:

- Preset name: `Android Debug`
- Export path: `build/walk-with-him-debug.apk` (`build/` is gitignored)
- Package: `com.walkwithhim.prototype`
- Architecture: `arm64-v8a` only
- Version name / code: `0.4.0` / `4` (bump both when you ship a new APK)
- Signed: true, using the **editor debug keystore**, not a release keystore
- Gradle build: off
- Permissions: vibrate on, internet off
- Exclude filter: `shots/*,tools/*,tests/*,*.md`

There are **no keystore paths or passwords** in `export_presets.cfg`. Keep it that way. Godot's debug keystore is a per-machine editor setting (on Linux it usually lives under `~/.local/share/godot/keystores/debug.keystore`). The password for that debug keystore is also only in the editor settings, never in this repo.

A release / Play keystore, if one is added later, must stay off git: add the path through the editor or a local untracked file, and strip any `keystore` / `keystore_password` / `keystore_user` fields from `export_presets.cfg` before committing.

To export from the editor: Project → Export → Android Debug → Export Project. From the CLI, once the Android export template for 4.7.2 is installed and the SDK is on `ANDROID_HOME` (and a JDK on `JAVA_HOME`):

```bash
godot --headless --path . --export-debug "Android Debug" build/walk-with-him-debug.apk
```

An older debug APK, `walk-with-him-0.2.0-debug.apk`, exists **outside** this repo (v0.2.0, not the current game). It was not committed and was not attached as a GitHub release. Export a fresh 0.4.0 APK for phone tests.

## Audio and data tools

There are **no environment variables** in the tools today. Paths are either relative to the project or, for Piper, hardcoded to a box-local directory. Do not invent secrets for them. If you add configuration, use env var *names* only and never commit values.

| Tool | What it does |
|---|---|
| `tools/gen_audio.py` | Synthesises SFX and music with numpy (fixed seed) and writes `audio/sfx/*.ogg` and `audio/music/*.ogg` via ffmpeg. Default run builds everything. `python tools/gen_audio.py v04` rebuilds only the v0.4 set (`bleat`, `pop`, `staff`, `yelp`, `growl`, `chime`, `stone`). `extra` rebuilds the night / vigil / temple / whistle set. Needs `numpy` and `ffmpeg`. |
| `tools/gen_voice.py` | Placeholder Piper TTS into `audio/voice/<line id>.ogg`, then writes `dur` back into `data/lines.json`. Models: `en_US-john-medium`, `en_US-joe-medium`, `en_US-ljspeech-medium` (CC0) and `en_GB-alba-medium` (CC BY 4.0, credited in `CREDITS.md`). The script currently loads models from the hardcoded path `/workspace/_gd/voices` and the docstring mentions `/workspace/_gd/venv/bin/python`. Point those at local Piper models if you regenerate voices; skip a line that already has `dur` and an ogg. Needs `piper`, `ffmpeg`, `ffprobe`. |
| `tools/build_lines.py` | Rebuilds `data/lines.json` from the script; keeps existing `dur` when text is unchanged. |
| `tools/fetch_kjv.py` | Fetches missing verses only from bible-api.com (`?translation=kjv`) into `data/kjv.json`. Never rewrite a verse already checked. |
| `tools/gen_textures.py` | Regenerates ground / wall textures in `art/`. |
| `tools/recolor_town.py` | Recolours the town kit textures. |

Voices already in `audio/voice/` are enough to run the game. Overwrite a single ogg to replace one line with a recording; ids are the keys in `data/lines.json`.

## Known issues and TODOs (from the code, not a wish list)

- Chapters **6 (Egypt / the flight)** and **7 (the Temple at twelve)** are explicitly not built. The chapter list says so. The age-jump scene currently walks child → teen → adult in one go, then calls `_intro()` into Nazareth (chapter 8). Building 6 and 7 means splitting that jump so the player is still a child in Egypt and a teen at twelve.
- After Cana the game shows the end card and **deletes the checkpoint save**. There is no chapter 11+ yet (ministry, Passion, Resurrection, Ascension).
- Four wise men are a known placeholder.
- Voices and music are placeholders.
- `Game.age_stage` comments say child = chapters 1-6, teen = 7, adult = 8+. An old save without the field is treated as an adult.
- Android Back is handled in `main.gd` (`quit_on_go_back` is off). A second Back shortly after one already opened the pause menu is how the player leaves to the title; the OS must not be allowed to quit the app behind the story's back. `touch.gd` resets fingers on pause / focus loss so a swallowed touch-up cannot leave a stuck stick.
- Coroutine helpers in `data.gd` (`sleep`, `frame`) park on a never-emitted signal if the owner was freed, so a scene reload does not resume into a dead object. Keep using these instead of raw timers in story code.
- `export_presets.cfg` has no release preset and no keystore fields. Fine for debug APKs; not enough for a signed release.
- `shots/` is already in git (reference screenshots, roughly 90 MB). Do not add new large shot dumps casually. `_dl/` and `.godot/` are ignored.

No `TODO` / `FIXME` markers were left in the scripts at handoff.

## Recommended next steps

1. Build **chapter 6** (the flight into Egypt) as a new mini-game type, not steering, not tracing, not catching, not a look-up spectacle, not a clue-search. Keep the player a child. Hook it in after chapter 5 and before the teen growth.
2. Build **chapter 7** (the Temple at twelve) as yet another type, with the player a teen, then grow to adult before Nazareth.
3. Only then continue past Cana toward the rest of the ministry and, in time, the Passion, Resurrection and Ascension, still changing the verb each chapter.
4. When a chapter needs a verse, add it with `tools/fetch_kjv.py` (missing keys only) and a matching line in `data/lines.json`. Fiction lines stay short.
5. Export a fresh debug APK for the Spark 40 after a chapter lands. Chris does the phone testing.
6. If voices are regenerated, keep Alba credited (CC BY 4.0). Prefer recorded actors over more TTS when the time comes, by overwriting the ogg files.

## Style and content rules

- Flat colour only. No gradients in UI or materials used as "style." Unshaded / solid fills are the look. The camp documents this: selected = solid gold fill + tick.
- No emojis in the UI, in on-screen copy, or in new toast / button labels.
- Type: Zilla Slab for titles, Barlow Condensed for UI. Warm parchment / gold / ink palette already in `ui.gd` and `areas.gd`.
- Touch-first. Do not add a keyboard-and-mouse control scheme that fingers cannot use.
- KJV verbatim; Fiction mark for invented words; no new doctrine.
- Low-poly, modest draw calls (MultiMesh for repeated things: flock, stars, fences, columns).
- Do not add Synty packs or paid Fab listings. Stay with Kenney CC0 already in `assets/` plus code-built meshes.

## Git and what was left out of the repo

- Default work branch: `main` (same tip as `lead-the-flock`). `master` is the older tip at v0.3.0 and is kept only for history. Do not force-push.
- Commits should be authored as `Chris Gold <98539725+AshThunder@users.noreply.github.com>`.
- Not in git, on purpose:
  - `.godot/` import cache
  - `_dl/` local kit downloads
  - `build/` and any APK / AAB
  - Godot debug or release keystores and passwords
  - The leftover v0.2.0 debug APK that lived beside the project folder on the original machine
- `.import` files and `.uid` files for assets that *are* in git should stay committed (Godot needs them).
