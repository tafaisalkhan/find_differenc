# Hidden Object / Spot The Difference Level Engine

Godot version target: **Godot 4.6**.

## Autoloads

`project.godot` already registers:

- `SignalHub` -> `res://autoload/SignalHub.gd`
- `GameManager` -> `res://autoload/GameManager.gd`

If you copy these files into another project, add both scripts in **Project > Project Settings > Globals > Autoload** with those exact names.

## Add A New Level

1. Create a folder such as `res://assets/levels/level2/`.
2. Add `level2_original.png` and `level2_different.png` or another Godot-supported texture format.
3. Create `res://data/levels/level2.json`, or use `res://scenes/editor/LevelEditor.tscn` to mark items and save.
4. New `.json` files are discovered by `LevelManager.list_level_paths()`, so core code does not need to change.

## Signal Flow

`SignalHub` contains shared events such as `level_loaded`, `item_selected`, `item_found`, `progress_changed`, `mode_changed`, `level_saved`, and `level_completed`.
Gameplay, editor, UI, and save/load systems communicate through those signals instead of direct node references.

## Scenes

- `res://scenes/ui/StartMenu.tscn` is the animated launch screen and opens the first game scene from its Play button.
- `res://scenes/editor/LevelEditor.tscn` opens edit mode and lets a developer mark findable areas on the different image.
- `res://scenes/game/GameLevel.tscn` opens play mode and checks clicks against saved item positions/radii. The included sample uses SVG placeholder art so it runs immediately; production levels can use PNG files.
- `res://scenes/ui/LevelUI.tscn` is reusable UI for mode, progress, status, and next level controls.
