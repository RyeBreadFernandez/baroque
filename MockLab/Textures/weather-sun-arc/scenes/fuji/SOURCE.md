# Fuji: source

**Subject:** Mount Fuji (3,776 m) over Lake Kawaguchi. This is the postcard view from the lake's north shore, looking south-south-west. Left is east: dawn lights the left flank, and the sun rises on the left and sets on the right.

**Reference photograph:** [File:Fuji Kawaguchi 460.JPG](https://commons.wikimedia.org/wiki/File:Fuji_Kawaguchi_460.JPG) on Wikimedia Commons
- Author: Marion & Christoph Aistleitner
- Licence: CC0 1.0 (public domain dedication)
- Taken 20 January 2014, at dawn, from the north shore.

**What was taken from it:** the skyline only. For every column of a 3840 px wide copy, the trace records the first row that is not sky. It follows a guide drawn by eye, and outliers are removed with a running median. The result is stored in `fuji.json`, normalised and kept every 4 columns. The units are Fuji's height above the lake's far shore in the photograph (925 px). No pixels of the photograph are kept.

**Painted, not traced:**
- the cone's modelling (a cone of revolution under the traced skyline, lit from the left);
- the snow cap and its fingers. They reach about 0.4 units down, as in the photograph, and stop a little higher out on the flanks so the sun times stay on dark ground;
- the far shore's trees;
- the water.

**Framing:**
- The summit sits at (0.546, 0.397), at 0.17 pt per photo px, with the skyline scaled uniformly.
- The traced flanks pass through the arc's feet. With Fuji's true slopes, that caps the summit at about 65 pt above them.
- The far shore lies at 0.83.

**Arc:** the Matterhorn's, (0.5, 0.575, 0.42, 0.45). There is no `scene.json`.

**Shared painter:** `world.py` in this folder is shared with `glencoe`, `dolomites` and `tuscany`, which import it by path. Keep it if this folder is removed.
