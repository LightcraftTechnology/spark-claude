---
name: spark-scenes
description: "Build and edit Spark (Lightcraft) scenes from Python with sparkpy — stage sets, characters and props (Gaussian splats and USD assets: upload, author, place, edit), create and aim cameras (shots) with real lenses, animate objects and cameras (keys, camera moves, focus pulls, the assets' own animation), read the scene as data or as USD, render what a camera sees to check the work, cut shots into an edit in Spark's Editor, and undo. Use when the user wants to block out, stage, animate, shoot, cut or look at a Spark scene: previs, layout, shots, coverage, camera moves, animatics and edits."
---

# Spark scenes with sparkpy

This plugin installs sparkpy in its own Python. Everything about working in Spark (what it is,
the conventions, the API, cameras, animation, assets, edits) is in **sparkpy's guide**, which
always matches the installed sparkpy. **Before any Spark work, run `sparkpy guide` and follow
it.** It points to topic guides: read the one for a kind of work with `sparkpy guide <topic>`
(e.g. `sparkpy guide cameras`) before doing it. Skip its "Install and connect" steps for
installing: this plugin has done that. What differs here:

## Running sparkpy here

Run sparkpy code with **`spark-python`**: write it to a script file and run
`spark-python that_file.py`, never the system `python`, and don't pip-install sparkpy anywhere
else. The command line is **`sparkpy`** (`sparkpy whoami`, `sparkpy guide`). If neither is on
PATH, they are `${CLAUDE_PLUGIN_DATA}/bin/spark-python` and `${CLAUDE_PLUGIN_DATA}/bin/sparkpy`;
if they don't exist, the plugin's setup failed (its log is `${CLAUDE_PLUGIN_DATA}/setup.log`):
say so rather than working around it.

If `connect()` says "not signed in", run `sparkpy login` yourself, with a timeout of at least
5 minutes: it opens the user's browser to the Spark sign-in and waits until they finish. Tell
them to complete it there; never ask for their password.

Changes are recorded as made by `claude-code` on the signed-in person's behalf without passing
`actor=`; `sparkpy.connect()` is enough.

**Claude Code's sandbox.** sparkpy can't work inside it: renders need the GPU, which the
sandbox blocks ("no Metal device"), and it can't renew the sign-in ("needs renewing", or
"Operation not permitted" under `~/.config/sparkpy` or `~/Library/Caches/sparkpy`). If you see
those, ask the user to let sparkpy's commands run outside the sandbox, in `~/.claude/settings.json`:
`"sandbox": {"excludedCommands": ["spark-python *", "sparkpy *"]}`. Don't edit their settings
without asking, and don't switch the sandbox off for each call instead. Run sparkpy as a plain
`spark-python file.py` or `sparkpy ...` call, with no heredoc, `cd`, pipe or redirect in the
same command, or the call stays in the sandbox. To see less output, print less from the
script; don't pipe it through `grep` or `head`.
