# Manual tracing of corpus callosum
---
## File specification
+ [VAST](https://software.rc.fas.harvard.edu/lichtman/vast/)
    - VAST_Lite\_V1\_2\_1: The VAST software
    - VAST\_package\_1\_2\_1: Supplementary materials of VAST
    - VAST_paper: For background knowledge(optional)
+ callosum_4\*4\*60 (**Your mission**)
    - images: 50 images of callosum named as `section%2d.tif`
+ example_6\*6\*30 (For reference)
    - images: 100 images of SNEMI3D named as `section%2d.tif`
    - segmentation: 100 label-images of SNEMI3D named as `labels%2d.tif`
## Tutorial
1. (optional) Read the paper and the official tutorial of VAST.
2. (optional) Refer to the ground truth of SNEMI3D dataset.
	- Import EM stack from images to `.vsv` file
	- Set resolution to `6*6*30 nm `
	- Import segmentation from images, choose `labels00.tif`
	- In the new dialog, set `basic filename string` to `labels%2d.tif` and `No of first/last slice` to `0/99`
3. Do manual segmentation on our corpus callosum dataset(***Copyright@ssSEM-LAB,SIBET***)
	- Import EM stack from images to `.vsv` file
	- Set resolution to `4*4*60 nm`
	- Create a new segmentation layer
	- **Enjoy the <del>boring</del> interesting painting!**
	- Output your final segmentation as `.tif` images

## Contact
### Author: [Horace.Kem](https://github.com/HoraceKem)
### Group: ssSEM-LAB,SIBET
