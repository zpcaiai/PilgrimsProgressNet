# Built-in sticker packs

Each pack is a subfolder; each sticker is a PNG named to match `manifest.json`.

```
assets/ui/stickers/
  manifest.json        # declares packs + the sticker names in each
  pilgrim/amen.png     # -> shows in the "天路" pack
  pilgrim/pray.png
  faces/smile.png      # -> shows in the "表情" pack
  ...
```

## Rules

- Drop a PNG whose name matches a `names` entry in `manifest.json` and it appears
  in the chat sticker tray automatically. Missing files are simply skipped.
- Recommended size: **128×128** or **256×256**, transparent background.
- Stickers are sent as a `sticker://<pack>/<name>` token, so they cost no upload
  and no server storage — **every client renders them from its own bundled copy.**
  That means all players must ship the same packs (they're part of the game build).
- To add a new pack: add a `"<pack_id>": { "label": "...", "names": [...] }` entry
  to `manifest.json` and create the matching folder.
