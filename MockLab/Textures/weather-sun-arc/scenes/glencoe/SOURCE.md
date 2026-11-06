# Glencoe: source

**Subject:** Buachaille Etive Mor (Stob Dearg, 1,022 m), the pyramid at the head of Glen Coe. This is the postcard view from the Kingshouse, across the River Etive and Rannoch Moor, looking south-west. The sun comes from the left (south-east), and the sun sets on the right.

**Reference photograph:** [File:Buachaille Etive Mor from Kingshouse Hotel.jpg](https://commons.wikimedia.org/wiki/File:Buachaille_Etive_Mor_from_Kingshouse_Hotel.jpg) on Wikimedia Commons
- Author: jtweedie1976 ([Flickr](https://www.flickr.com/photos/25921513@N00/432613184/))
- Licence: CC BY 2.0
- Taken 24 March 2007.

**What was taken from it:**
- **The skyline.** For every column of the 1200 px wide file, the trace records the first row that is not sky. It follows a guide drawn by eye, and outliers are removed with a running median.
- **Two inner lines, drawn by eye on the same photograph:**
  - `front_ridge`: where the pyramid's left ridge passes in front of the far snowy top behind it;
  - `right_flank`: where its right flank passes in front of the far hill on the right.

Both are stored in `glencoe.json`, normalised. The units are the summit's height above the flat of the moor in the photograph (389 px). No pixels of the photograph are kept.

**Painted, not traced:**
- the crags, buttresses and gullies;
- the old snow under the summit, kept to the sunlit upper left as in the photograph;
- the moorland apron, in the shadow of a cloud, so the sun times and the type sit on dark ground (in the photograph it is sunlit);
- the moor, the River Etive and the near bank.

The Scots pines at the photograph's left edge are left out.

**Framing:**
- The summit sits at (0.559, 0.345), at 0.365 pt per photo px, with the skyline scaled uniformly.
- The flanks pass through the arc's feet, and the moor lies at 0.735.

**Arc:** the Matterhorn's, (0.5, 0.575, 0.42, 0.45). There is no `scene.json`.

**Shared painter:** `../fuji/world.py`.
