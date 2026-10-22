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

## What it installs

- **The `spark-scenes` skill**, which teaches Claude how to stage, shoot and edit Spark scenes.
- **sparkpy**, installed when a session starts into the plugin's own folder
  (`~/.claude/plugins/data/`), along with its own copy of Python. Nothing is installed
  system-wide, and uninstalling the plugin removes it. sparkpy's dependencies are pinned to
  the versions it was tested with, and every download is checked against a known hash.

If something goes wrong during setup, Claude Code shows a message, and the details are in
`setup.log` in that folder.
