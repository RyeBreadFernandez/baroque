# Big Sur, Bixby Creek Bridge

The view from the turnout north of the bridge on Highway 1, looking south in the late light. The open-spandrel
concrete arch leaps the dark mouth of Bixby Creek, its deck level with the sea's horizon. Hurricane Point's hills rise
behind it, the headland falls in cliffs to the cove, and the Pacific is on the right (west), where the sun sets. East
and west are therefore true to the view.

## Reference photograph

- File: [Sunset At The Bixby (44143484).jpeg](https://commons.wikimedia.org/wiki/File:Sunset_At_The_Bixby_(44143484).jpeg)
- Author: Aaron Albrecht
- Licence: CC BY 3.0
- Traced at its full size, 1920 x 1279 px.

## What was taken from it

Lines and silhouettes only, stored in `big-sur.json`. No pixels were kept.

- The hills' skyline: for every column, the first warm, unhazed row below the sky, median-smoothed over 7 px.
- The bridge: its pale concrete joined to the deck, stored as run-length rows.
- The shore under the headland.
- The top of the sea stack off the point.
- The sea's horizon, at y 553.

## Placement and lighting

- `SCALE` in `make.py` is 0.27 pt per photo px, uniform and never stretched. `CROP_X` is 235, the photograph's column
  at the canvas's left edge. The horizon falls at 208 pt.
- The arc is the Matterhorn's, so there is no `scene.json`.
  - The left foot stands on the bridge deck, which sits about 2 pt above it.
  - The right foot is on the sea's horizon, just past the headland's point, about 2 pt below it.
- The hills behind the bridge are hazed middle distance. They are drawn again in front of the arc at only 30%
  (`HAZE`), so the gilt line reads down across them to the deck. Everything at or below the horizon is fully in front.
- Lit by the late sun from the right, over the sea.
  - The deck and the arch are pale concrete.
  - The near spans on the left stand in shadow below the deck, which keeps the sunrise time on dark paint.
  - The canyon, the cliffs, the cove and the brush form the dark ground.

## Superseded

An earlier version used Pfeiffer Beach, traced from
[Robert Brett's photograph](https://commons.wikimedia.org/wiki/File:Pfeiffer_Beach,_Big_Sur,_California,_United_States.jpg)
(CC BY-SA 4.0). It read as "a hill and a beach", so this view replaced it.

## Files

`make.py` paints this scene. It is deterministic and offline. It imports the shared painter from
`../half-dome/ca_paint.py`.
