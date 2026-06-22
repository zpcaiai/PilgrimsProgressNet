FULL-BODY CHARACTER FIGURES — drop folder
=========================================

The in-world characters (3D billboards) are built from the cutouts in
  assets/characters/figures/<stem>.webp
Right now those are HALF-BODY (the source paintings are busts cut at the waist).

To make them full-body WITHOUT changing the faces:

1) For each character, open its portrait  assets/characters/<stem>.png  (512x640)
   in Photoshop or Firefly.
2) Use **Generative Expand** to extend the canvas DOWNWARD (add ~700 px, so the
   canvas becomes roughly 512 x 1340). Generative-fill the new area with the
   legs + feet, prompt e.g.:
       "full body, standing, legs and feet, same person, same clothing,
        same academic oil-painting style, plain background"
3) (Best) Remove Background and export a TRANSPARENT PNG. (Opaque PNG is fine too;
   the script will cut it out.)
4) Save it here as  assets/characters/figures_full/<stem>.png  (exact stem below).
5) Tell Claude "done" (or run:  python3 tools/gen_full_figures.py).
   The figure cutouts are rebuilt full-body; dialogue portraits are untouched.

Exact stems (one file each; do as many as you like, the rest stay as-is):
  pilgrim          evangelist       obstinate        pliable
  goodwill         help             hopeful          apollyon
  the_interpreter  the_shepherds    watchful         your_family
  pilgrim_child    your_family_child

Tip: keep feet near the bottom edge and a little space above the head; the
script auto-trims empty margins, so exact canvas size is not critical.
