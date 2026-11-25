---
name: spark-scenes
description: "Build and edit Spark (Lightcraft) scenes from Python with sparkpy — stage sets, characters and props (Gaussian splats and USD assets: upload, author, place, edit), rig characters and make their poses and animations (from words, photos, videos, key poses or other files, worked on in an Object Studio draft the user sees on the web and published on their word), create and aim cameras (shots) with real lenses, animate objects and cameras (keys, camera moves, focus pulls, the assets' own animations), read the scene as data or as USD, render what a camera sees to check the work, cut shots into an edit in Spark's Editor, give a script's characters voices and make its lines' audio (generated from the text with a direction, or performed from a recording, kept or re-voiced) and place them in scenes, and undo. Use when the user wants to block out, stage, animate, pose, shoot, cut or look at a Spark scene, or to hear its script: previs, layout, character poses and animation, shots, coverage, camera moves, animatics and edits, script voices and voice lines."
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
