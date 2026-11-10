---
name: spark-scenes
description: "Build and edit Spark (Lightcraft) scenes from Python with sparkpy — stage sets, characters and props (Gaussian splats and USD assets: upload, author, place, edit), create and aim cameras (shots) with real lenses, animate objects and cameras (keys, camera moves, focus pulls, the assets' own animation), read the scene as data or as USD, render what a camera sees to check the work, cut shots into an edit in Spark's Editor, and undo. Use when the user wants to block out, stage, animate, shoot, cut or look at a Spark scene: previs, layout, shots, coverage, camera moves, animatics and edits."
---

# Spark scenes with sparkpy

This plugin installs sparkpy, and puts its two commands on PATH: `spark-python` (runs sparkpy
code) and `sparkpy` (its command line). If they aren't on PATH, they are in
`${CLAUDE_PLUGIN_DATA}/bin` (`.cmd` versions there, for PowerShell on Windows); if they aren't there either, the plugin's setup failed (its log is
`${CLAUDE_PLUGIN_DATA}/setup.log`): say so rather than working around it.

Everything about working in Spark is in **sparkpy's guide**. **Before any Spark work, run
`sparkpy guide` and follow it.** It points to topic guides: read the one for a kind of work with
`sparkpy guide <topic>` (e.g. `sparkpy guide cameras`) before doing it. Skip its installer:
this plugin has installed sparkpy.
