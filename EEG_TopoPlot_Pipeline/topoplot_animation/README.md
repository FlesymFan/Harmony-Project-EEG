# Topoplot Animation Helpers

This folder contains helper files for generating and inspecting animation frames. These are separate from the main `EEG_TopoPlot` analysis pipeline.

Files:

- `topoplotFrameSeries.m`: generates PNG frame sequences from multi-subject topoplots
- `topoplotFrameViewer.m`: opens generated frames with exact frame-by-frame control
- `prepareFramesForPhotoshop.m`: copies frames into simple Photoshop image-sequence filenames

Output folders:

- `topoplot_frames`: original generated frames with time-window information in the filename
- `topoplot_frames_photoshop`: copied frames named `frame_0001.png`, `frame_0002.png`, etc.

Exported animation files, such as `.mp4` videos made from the frames, can also live in this folder.

Typical order:

```matlab
cd('path/to/Mehta/EEG_TopoPlot/topoplot_animation')
addpath('path/to/Mehta/Data')

topoplotFrameSeries
topoplotFrameViewer
prepareFramesForPhotoshop
```

Use `topoplotFrameViewer` for scientific inspection, because one frame step equals one saved PNG frame. Use Photoshop only after the frames are ready for final animation export.
