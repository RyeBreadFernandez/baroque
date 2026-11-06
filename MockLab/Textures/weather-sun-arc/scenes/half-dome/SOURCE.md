# Half Dome, from Glacier Point

The classic view, looking northeast up Tenaya Canyon: Half Dome in profile, its sheer northwest face falling straight
down on the left, the rounded back curving away to the right, Clouds Rest's long slab rising behind it on the left.

## Reference photograph

- File: [Half dome view from Glacier point - panoramio.jpg](https://commons.wikimedia.org/wiki/File:Half_dome_view_from_Glacier_point_-_panoramio.jpg)
- Author: el ui (via Panoramio), taken 30 July 2010
- Licence: CC BY 3.0
- Traced at its full size, 3456 x 2592 px.

## What was taken from it

Lines only, stored in `half-dome.json`. No pixels were kept.

- The skyline: for every column, the first row that is not blue sky, median-smoothed over 7 px. This gives the far
  ridges, Clouds Rest, the notch, the visor and the dome.
- Lines read by eye off gridded crops of the same photograph: the left and right edges of the lit face, the face's
  lower left edge below the notch, the dome's right edge below the skyline, the forested shoulder at its foot, and
  where the great dark water streak runs.

Units: the summit is at (0, 0), and one unit is the dome's height from the summit to its right foot on the forest
beyond (433.6 px of the photograph).

## Placement and lighting

- `DOME` in `make.py`: the summit at (221, 141.2) pt, and one unit is 94.55 pt. That is 0.218 pt per photo px, scaled
  uniformly and never stretched.
- The framing comes from where the traced skyline crosses the photograph's row 900, at columns 1658 and 2997:
  - The left crossing, on Clouds Rest's slope, falls at the arc's left foot.
  - The right crossing, on the dome's right flank, falls at the arc's right foot.
  - So the land at both feet sits 1 to 2 pt above them, and the arc runs visibly down to just above the times.
  - The visor and the face stand under the arc's crown, with the summit to the right of it.
- The arc is the Matterhorn's, so there is no `scene.json`.
- Lit as in the photograph, from the upper left:
  - The face is the brightest plane, with the dark streak down it.
  - The back is modelled as a dome that turns from facing up over the face to facing right at the far limb, lit
    half-Lambert. So it reads round, and darkens toward its limb and its foot.
  - Clouds Rest's lower slope (Tenaya Canyon) and the dome's foot are in shadow, under the times.

## Other photographs consulted (not traced)

- [Half Dome from Glacier Point, Yosemite NP - Diliff.jpg](https://commons.wikimedia.org/wiki/File:Half_Dome_from_Glacier_Point,_Yosemite_NP_-_Diliff.jpg)
  (Diliff, CC BY-SA 3.0)
- [Half Dome from Glacier Point - panoramio.jpg](https://commons.wikimedia.org/wiki/File:Half_Dome_from_Glacier_Point_-_panoramio.jpg)
  (Aaron Zhu, CC BY-SA 3.0)

## Files

- `make.py` paints this scene: `python3 make.py [--preview <folder>]`. It is deterministic and offline.
- `ca_paint.py` is the painter shared by the four California scenes (half-dome, whitney, big-sur and joshua-tree).
  The other three import it from here by path.
