VAST Lite Version 1.2.1
(c) November 15th, 2018 by Daniel Berger, Lichtman Lab, Harvard

VAST is a Volume Annotation and Segmentation Tool for microscopic image stacks.
It runs on PCs with 64-bit Windows 7 or later.

This version of VAST is free of charge and may be distributed freely, but not sold. 
Commercial usage is allowed.
You are using this software at your own risk.


Version 1.2.1 implements the following improvements over version 1.2.01:

- Parameter assignment in flood filling fixed
- Image data reading at end of stack fixed for .VSVR and .VSVI sources
- Flood filling spill-out at sides fixed
- Segmentation importing at non-zero offset fixed
- Sections in .VSVI stacks can now be arbitrarily reordered using an optional parameter, like this for example:
  "SourceSectionOrder": "1000:-1:36 30:35 29 28:-2:10",  <-- Matlab syntax
  This will disable parameters SourceMinS, SourceMaxS, and OffsetZ (which still have to be included but are ignored).
- Fixed a bug which caused VAST to crash when Segmentation Metadata was exported from a segmentation layer with no associated file
- Segmentation importing from 16-bit TIFF images implemented
- Added segment cleaning - Size-limited debris removal and hole filling (disabled because it doesn't fully work yet)
- 'Show color clamping' added to Layers toolwindow context menu, to show pixels clamped to 0 or 255 during changes of Brightness or Contrast
- Progress bar now moves during segmentation importing
- Changed Canceling in Progress window to remove lingering pop-up message window
- Added segment bounding box reevaluation function
- Added segmentation cleaning function
- Added 'Autopick nonzero source' to drawing masking modes
- 3D viewer pick cursor added
- One-pixel offset in bounding boxes fixed
- Planar splitting tool implemented
- 'Avoid parent color' option in Preferences added
- 'Hybrid Recolor / Auto-Pick' option for filling added
- Miplevel updating when pasting segmentations fixed
- Fixed changing ports for API remote connections
- 3D viewer updating now visible and can be canceled
