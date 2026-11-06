# Mount Whitney, from the Alabama Hills

The view from the Alabama Hills above Lone Pine, looking west at the Sierra crest. It shows the saw of the Whitney
Needles with Mount Whitney's summit block beside them. In the foreground are the rounded granite boulder piles of the
Alabama Hills and the sage flats.

## Reference photograph

- File: [Mount Whitney (28614888246).jpg](https://commons.wikimedia.org/wiki/File:Mount_Whitney_(28614888246).jpg)
- Author: Bureau of Land Management (Flickr upload, dated 23 July 2013 on the file page)
- Licence: CC BY 2.0
- Traced at its full size, 2000 x 1625 px.

## What was taken from it

Only the skyline of the crest, stored in `whitney.json`. For every column it is the first row that is not blue sky,
median-smoothed over 5 px, over the stretch x 200 to 1620 where the sky is clear. No pixels were kept.

Units: Whitney's summit is at (0, 0), and one unit is its height above the col north of it (119.4 px).

## Placement and lighting

- `CREST` in `make.py`: the summit at (247, 153.5) pt, and one unit is 52.5 pt. That is 0.44 pt per photo px, scaled
  uniformly and never stretched.
- The crop runs from the col south of the needles (x 660) to the col north of Whitney (x 1320). The arc's feet stand
  on those two cols, so the whole massif is under the arc.
- Lit as in the photograph, by early light from the left and in front. Each needle is lit down its left flank and in
  shadow down its right. A little snow lies in the gullies, and the escarpment falls into shadow below.
- The boulder piles are painted, not traced. They are modelled as one heap, with rounded stones, dark joints, a few
  fractures, and crowns lit from the left.
- Arc (`scene.json`): `[0.5, 0.57, 0.42, 0.45]`. The feet are about 3 to 6 pt below the cols.

## Other photographs consulted (not traced)

- [Mt. Whitney, CA 2016 (28893679930).jpg](https://commons.wikimedia.org/wiki/File:Mt._Whitney,_CA_2016_(28893679930).jpg)
  (Don Graham, CC BY-SA 2.0)
- [Mt Whitney from Alabama Hills-wideshot.jpg](https://commons.wikimedia.org/wiki/File:Mt_Whitney_from_Alabama_Hills-wideshot.jpg)
  (CC BY-SA 3.0)

## Files

`make.py` paints this scene. It is deterministic and offline. It imports the shared painter from
`../half-dome/ca_paint.py`.
