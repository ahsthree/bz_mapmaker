**bz_mapmaker.sh** is an interactive CLI map builder and workflow utility for BZFlag (`.bzw`) maps. Designed with accessibility in mind to minimize repetitive typing fatigue, it streamlines geometry creation by offering fast parameter prompts with sensible defaults, automatically generating `define` blocks and semicolon-separated server `options`. It manages a live local testing loop via `bzfs`—temporarily rendering geometry at the origin for instant verification—and cleanly strips test instances so you can commit or discard individual objects before setting final group transformations.

./bz_mapmaker.sh

Example Workflow
Select or Create Map: Choose an existing .bzw file or enter a new map filename.

Server Options: Enter server options separated by semicolons (e.g., -j; +r; -ms 6; -mp 10,10,0,0,10; -sb).

Define Section: Name your geometry define section (e.g., base_building).

Add Objects: Select object type (b for box, p for pyramid), then hit <Enter> or input coordinates (x y z), dimensions (xs ys zs), and rotation (rot).

Live Test: bzfs launches automatically to render your map. Exit bzfs or press Ctrl+C when done inspecting.

Commit or Rollback: Confirm if you want to keep the object or remove it.

Final Group Placement: Specify final group shift and rotation when closing the define.
