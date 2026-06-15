# assets/

Original, procedurally-generated asset pack for *Pilgrim's Road — Burden Fallen*.
All files here are produced by `tools/gen_audio.py` and `tools/gen_art.py` and are
100% original (public-domain-safe). Every asset is **existence-checked** by the
game, so deleting any file simply falls back to the procedural greybox / silence.

```
audio/music/<chapter_id>.ogg      16 seamless chapter music loops (+ title.ogg)
audio/ambient/<chapter_id>.ogg    16 seamless ambience beds
audio/sfx/<name>.ogg              9 event sound effects
textures/ground/<chapter_id>.png  16 tileable ground textures
textures/particles/<name>.png     soft particle sprites (mote, soft, spark, dust)
scenes/<chapter_id>.png           16 painterly chapter backdrops (title card)
characters/<stem>.png             12 cast portraits (shown in dialogue)
ui/title_key_art.png, icon_*.png  menu key art + token icons
anim/<name>.png                   5 horizontal flipbook sheets (8 frames each)
manifest.json                     machine-readable inventory
```

To replace with your own art/audio, just overwrite the matching file name — no
code changes needed. Full details: [`../docs/ASSETS.md`](../docs/ASSETS.md).
