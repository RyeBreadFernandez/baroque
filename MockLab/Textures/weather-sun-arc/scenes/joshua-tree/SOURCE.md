# Joshua Tree, at evening

A tall Joshua tree stands under the arc's crown, its arms raised and each one ending in a spiky rosette. Heaps of
rounded monzogranite boulders lie along the horizon, more Joshua trees stand out on the flat, and the dark desert floor
is in front.

## Reference photographs

All three are by Joshua Tree National Park (U.S. National Park Service) and are in the public domain as works of the
U.S. federal government.

- [Joshua tree sunset (50730886731).jpg](https://commons.wikimedia.org/wiki/File:Joshua_tree_sunset_(50730886731).jpg)
  - Taken 8 December 2020; 2048 x 1365 px.
  - Used for the hero tree: the whole tree against the sky, down to where the far ridge meets its trunk (y 940).
  - Below that, the trunk is carried down at its traced width to its foot at y 1190, where the photograph shows it
    meeting the ground.
- [Sunset silhouettes of Joshua trees at Juniper Flats (46491520085).jpg](https://commons.wikimedia.org/wiki/File:Sunset_silhouettes_of_Joshua_trees_at_Juniper_Flats_(46491520085).jpg)
  - Taken 26 February 2019; traced at 3840 x 2560 px.
  - Used for three of the smaller trees ("pair", "small" and "cluster"), each cut at the hill line it stands on.
- [Joshua tree silhouette and sunset (49623125253).jpg](https://commons.wikimedia.org/wiki/File:Joshua_tree_silhouette_and_sunset_(49623125253).jpg)
  - Taken 10 June 2017; 2048 x 1365 px.
  - Used for the skyline of the boulder piles, with the tree's trunk bridged.

## What was taken from them

Silhouettes only, stored in `joshua-tree.json`. No pixels were kept.

- Each tree is the dark component against the evening sky, stored as run-length rows. The hero is resampled to
  420 rows and the others to 220.
- The piles are stored as a skyline.

## Placement and lighting

- `TREES` and `PILES` in `make.py` place them. Each is scaled uniformly and never stretched.
  - The hero is 156 pt tall, its top at 78 pt.
  - The boulder skyline is drawn at 40 pt and 34 pt to its unit (the photograph's tallest pile), left and right.
- Lit by the afterglow from the upper right. The trees are black silhouettes, rim-lit along their right and upper
  edges, and the boulders are dark with lit crowns.
- The arc is the Matterhorn's, so there is no `scene.json`. Its feet stand on the boulder piles, about 2 pt (right) and
  8 pt (left) below their tops.

## Files

`make.py` paints this scene. It is deterministic and offline. It imports the shared painter from
`../half-dome/ca_paint.py`.
