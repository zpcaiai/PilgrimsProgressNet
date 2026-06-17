# Realistic environment backdrops

Drop a realistic landscape image here per chapter to use it as that chapter's
sky / distant backdrop in **realistic mode** (`RenderConfig.REALISTIC = true`):

```
assets/scenes/realistic/<chapter_id>.jpg   (or .png / .webp)
```

`chapter_id` is one of: city_of_destruction, slough_of_despond, wicket_gate,
interpreter_house, hill_difficulty, palace_beautiful, valley_humiliation,
valley_shadow_death, vanity_fair, doubting_castle, delectable_mountains,
enchanted_ground, wilderness_road, river_of_death, celestial_city,
cross_and_tomb.

- Loaded existence-checked by `AssetLib.realistic_backdrop()`. If absent, a clean
  procedural sky is used instead — so any subset works.
- Best as a wide landscape (16:9 or 2:1). It is mapped onto the sky dome, so a
  2:1 equirectangular panorama wraps most naturally; a 16:9 frame also works
  (mild stretch at the poles).
- Suggested content: photoreal 17th-century rural England — fields, moors,
  villages, a stone-walled gate, a fortress, a green valley with sheep, a wide
  river at dusk, etc. Keep them grounded and natural (no text, no modern objects).

These can be AI-generated (e.g. Z-Image / Firefly) or real photographs you own.
