# Fonts (drop a CJK font here)

The game ships with **no font file**, so it uses Godot's built-in font — which
has **no Chinese/Japanese/Korean glyphs**. The in-game story text is English and
renders fine, but the **multiplayer chat, player names, and any Chinese UI** will
show tofu boxes (□□□) until a CJK font is present.

## How to fix (30 seconds)

1. Download a CJK font, e.g.:
   - **Noto Sans CJK SC** — https://github.com/notofonts/noto-cjk (Regular `.otf`)
   - **Source Han Sans SC** — https://github.com/adobe-fonts/source-han-sans
2. Drop the `.ttf` or `.otf` into this folder (`assets/fonts/`).
   Any filename works; `main.ttf` / `cjk.otf` are picked first.
3. Restart the game (or the editor). `ThemeManager` finds it via `AssetLib.font()`
   and applies it project-wide. Chat and names now render Chinese correctly.

No code changes required — detection is by folder scan + existence check.

## Notes

- A single Noto/Source Han weight (Regular) covers Latin + CJK in one file.
- Prefer one **Regular** weight to keep the export size reasonable (~8–16 MB).
- Licensing: Noto and Source Han are SIL Open Font License (free to ship).
