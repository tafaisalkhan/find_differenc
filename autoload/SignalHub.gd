extends Node

## Shared signals keep systems loosely coupled.
## Gameplay, editor, UI, and save/load code emit/listen here instead of calling unrelated nodes directly.

signal mode_changed(mode: StringName)
signal level_load_requested(level_path: String)
signal level_loaded(level_data: LevelData)
signal level_saved(level_path: String)
signal item_selected(item: FindableItem)
signal item_found(item: FindableItem, found_count: int, total_count: int)
signal wrong_item_tapped
signal progress_changed(found_count: int, total_count: int)
signal level_completed(level_data: LevelData)
signal level_failed(reason: StringName)
signal status_message_requested(message: String)
signal zoom_requested(direction: float)
signal zoom_reset_requested
signal hint_focus_started
signal hint_focus_finished
signal rewarded_hint_earned
