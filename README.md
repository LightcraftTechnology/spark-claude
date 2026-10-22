# Spark for Claude Code

Build, shoot and edit [Spark](https://lightcraft.pro) scenes from Claude Code: stage sets,
characters and props, create and aim cameras with real lenses, animate them, and render what a
camera sees. Claude works through **sparkpy**, which edits your scenes as you, signed in with
your Spark account. Anyone with the scene open in the web editor sees the changes live.

Requires a Mac with Apple silicon on macOS 15 (Sequoia) or later.

## Install

```
/plugin marketplace add LightcraftTechnology/spark-claude
/plugin install spark@lightcraft
```

Start a new session (or run `/reload-plugins`). The first session installs sparkpy into the
plugin's own data folder, so nothing is installed system-wide. Then ask Claude for Spark work. The
first time, it opens your browser to sign in to Spark.

To get updates automatically, turn on auto-update for the `lightcraft` marketplace in
`/plugin` → Marketplaces. Otherwise run `claude plugin update spark@lightcraft`.

## How it's put together

- `skills/spark-scenes/SKILL.md`: the skill. Its source is `sparkpy/skill/SKILL.md` in
  [sparkai](https://github.com/LightcraftTechnology/sparkai). This copy differs only in how it
  runs sparkpy (`spark-python` and `sparkpy` instead of a dev checkout's `python`).
- `hooks/hooks.json` → `scripts/setup.sh`: a SessionStart hook. It installs the sparkpy wheel
  pinned in `sparkpy.lock` into `${CLAUDE_PLUGIN_DATA}`, using a pinned, checksum-verified uv
  and Python. It also puts the `spark-python` and `sparkpy` shims on PATH for the session.
  Once installed, the hook takes under 0.1 s. Its log is `${CLAUDE_PLUGIN_DATA}/setup.log`.
- `sparkpy.lock`: the wheel's version, URL and sha256, the oldest macOS it loads on, and the
  pinned Python and uv.

## Releasing

1. Build the wheel in sparkai (see `sparkpy/pyproject.toml`) and upload it.
2. Update `sparkpy.lock` (`SPARKPY_VERSION`, `SPARKPY_WHEEL_URL`, `SPARKPY_WHEEL_SHA256`), and
   set `.claude-plugin/plugin.json`'s `version` to the same version. Claude Code only offers
   an update when that version changes.
3. If the skill changed, copy it in from sparkai, keeping this copy's "Connect" section.

## Developing

To test a local wheel, start Claude Code with `SPARKPY_WHEEL=/path/to/sparkpy-*.whl` set. The
hook then installs that wheel, and skips the checksum.
To try the plugin from this checkout: `claude --plugin-dir .`.
