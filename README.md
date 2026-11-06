# Spark for Claude Code

Build, shoot and edit [Spark](https://lightcraft.pro) scenes from Claude Code: stage sets,
characters and props, create and aim cameras with real lenses, animate them, and render what a
camera sees. Claude works through **sparkpy**, which edits your scenes as you, signed in with
your Spark account. Anyone with the scene open in the web editor sees the changes live.

Requires one of:

- a Mac with Apple silicon on macOS 15 (Sequoia) or later;
- a Windows 10 or 11 PC with an x64 (Intel or AMD) processor, a GPU, and
  [Git for Windows](https://git-scm.com/downloads/win).
  Claude Code runs the plugin's setup in Git for Windows' Git Bash; without it, Claude Code
  reports a setup error when a session starts.

**Nothing else needs installing first:** the plugin brings its own Python and everything sparkpy
needs. On Windows, renders draw the scene the way the web editor does, in a headless Microsoft
Edge or Google Chrome. A PC with neither gets Chromium once instead: a 200 MB download into the
plugin's folder (440 MB on disk).

## Install

In Claude Code in a terminal:

```
/plugin marketplace add LightcraftTechnology/spark-claude
/plugin install spark@lightcraft
```

`/plugin` isn't available everywhere (not in the VS Code extension, for one). Anywhere, the same
from a terminal:

```sh
claude plugin marketplace add LightcraftTechnology/spark-claude
claude plugin install spark@lightcraft
```

Then **start a new Claude Code session**: sparkpy is set up when a session starts, so it isn't
available in the session you installed from. The first session takes a minute or two (it
downloads Python and sparkpy into the plugin's own folder; nothing is installed system-wide).

## Check that it worked

Spark doesn't add tools to Claude's tool list: it's a skill plus two commands, `sparkpy` and
`spark-python`, which exist inside Claude Code sessions (not in your own terminal). If setup
failed, Claude Code says so when the session starts. In Claude Code:

```
! sparkpy whoami        # your Spark account and environment, once you're signed in
! sparkpy login         # sign in now (it opens your browser); or just ask Claude for Spark work
```

On Windows those `!` commands run in Git Bash. In PowerShell, the two commands aren't on PATH;
the session's setup message gives their full paths (`…\bin\sparkpy.cmd`).

Claude also signs you in the first time you ask for Spark work. Never give anyone your Spark
password in chat: the sign-in always happens in your browser. sparkpy keeps it in the macOS
Keychain, or in Windows Credential Manager.

## Updates

To get updates automatically, turn on auto-update for the `lightcraft` marketplace in
`/plugin` → Marketplaces. Otherwise run `claude plugin update spark@lightcraft`, then start a new
session. How Claude works in Spark (the guide it reads) updates by itself, separately from the
plugin.

## If you use Claude Code's sandbox

On a Mac: sparkpy renders on your Mac's GPU, and Claude Code's sandbox blocks the GPU (it also keeps
sparkpy from saving your sign-in). If you've turned the sandbox on, let sparkpy's two commands
run outside it by adding this to `~/.claude/settings.json`:

```json
{
  "sandbox": {
    "excludedCommands": ["spark-python *", "sparkpy *"]
  }
}
```

Those commands then ask for permission like any other command outside the sandbox. Everything
else Claude runs stays sandboxed. (Claude Code has no sandbox on Windows itself, only in WSL 2,
which this plugin doesn't support.)

## What it installs

- **The `spark-scenes` skill**, which tells Claude to read sparkpy's guide (`sparkpy guide`)
  before Spark work: how to stage, shoot and edit Spark scenes, always matching the installed
  sparkpy.
- **sparkpy**, installed when a session starts into the plugin's own folder
  (`~/.claude/plugins/data/`), along with its own copy of Python. Nothing is installed
  system-wide, and uninstalling the plugin removes it. sparkpy's dependencies are pinned to
  the versions it was tested with, and every download is checked against a known hash.
- **On Windows, without Edge or Chrome:** Playwright's Chromium, for renders, in the same folder.

If something goes wrong during setup, Claude Code shows a message, and the details are in
`setup.log` in that folder.
