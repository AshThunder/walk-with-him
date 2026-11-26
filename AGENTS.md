# Walk With Him — agent rules

Read [HANDOFF.md](HANDOFF.md) before changing anything. It is the project brief: current state, structure, export, audio tools, style, and next steps.

## Working rules

- This is a Godot 4.7.2 project. Open and run `project.godot`. Target is a touch-first Android phone (Infinix Spark 40). Keep the viewport 1080x1920, GL Compatibility renderer.
- Flat UI and art only. No gradients, no glow-as-style, no emojis in the UI or in on-screen copy. Selected controls are a solid fill plus a tick, as in the camp.
- Scripture is King James Version, quoted verbatim from `data/kjv.json`. Never paraphrase a verse. Invented spoken lines are short narrative bridges only; mark them `kind: "fiction"` in `data/lines.json` so the UI can show the Fiction mark. Add no doctrine.
- The player is a shepherd's child who grows up across the story (child, teen, adult). Voices and music in the repo are placeholders (synthesised music/SFX, Piper TTS voices). Overwrite `audio/voice/<line id>.ogg` to swap in a recording.
- Each new chapter needs its own distinct mini-game type (examples already used: lead/steer a flock, look-up spectacle, search with clues, catching, tracing, tap-to-fill). Never use the same type back to back.
- Nativity-style interactions should not be fail states: help the player along (auto-complete, patience whistle, lost lambs found at camp). Wolves scatter, they do not harm.
- Do not commit secrets: keystores, keystore passwords, `.env`, API keys, or export credentials. `export_presets.cfg` in this repo is a debug preset with no signing passwords. If you add a release preset, strip passwords before committing.
- Do not commit `build/`, `.godot/`, `_dl/`, or APK/AAB files. Chris tests APKs on his phone; do not treat a missing device test as a pass.
- Keep token use and scope tight: one change at a time, no drive-by refactors, no repeated sweeps. Reuse existing scripts, Kenney CC0 kits already in `assets/`, and the synthesis tools rather than adding new third-party packs (no Synty, no paid Fab packs).
- Prefer the current branch tip (`lead-the-flock` / `main`) over the older `master` branch, which stops at v0.3.0.
