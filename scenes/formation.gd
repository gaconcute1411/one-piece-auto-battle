extends Control
## Bố trí sáu nhân vật theo hai cột dọc, mỗi cột ba vị trí.

class FormationDragButton extends Button:
	signal character_dropped(target_slot: int, character_id: String)
	var drag_character_id: String = ""
	var target_slot: int = -1

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if drag_character_id.is_empty():
			return null
		var preview := Label.new()
		preview.text = GameData.char_name(drag_character_id)
		preview.add_theme_color_override("font_color", Color("ffe08a"))
		set_drag_preview(preview)
		return {"character_id": drag_character_id}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		if target_slot < 0 or not data is Dictionary:
			return false
		var payload: Dictionary = data
		return payload.has("character_id")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		var payload: Dictionary = data
		character_dropped.emit(target_slot, String(payload["character_id"]))

var _slot_grid: GridContainer
var _character_grid: GridContainer
var _hint: Label
var _team_count: Label
var _selected_slot: int = 0


func _ready() -> void:
	GameState.pending_battle = {}
	UIKit.add_background(self, 0.62)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)
	root.add_child(_build_header())
	_hint = UIKit.label("Kéo nhân vật vào ô tham chiến để gán hoặc đổi chỗ. Cũng có thể bấm ô rồi chọn nhân vật.", 15, Color("d6dfed"))
	root.add_child(_hint)

	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)
	content.add_child(_build_formation_panel())
	content.add_child(_build_character_panel())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	root.add_child(footer)
	_team_count = UIKit.label("", 16, Color("ffe08a"))
	_team_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_team_count)
	var confirm := UIKit.button("XÁC NHẬN ĐỘI HÌNH", Color("367d62"), 17, Vector2(250, 48))
	confirm.pressed.connect(_confirm_formation)
	footer.add_child(confirm)
	_refresh()


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := UIKit.button("‹ SẢNH", Color("4a4f63"), 17, Vector2(120, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(back)
	var support := UIKit.button("ĐỘI CỔ VŨ", Color("7250a7"), 14, Vector2(135, 46))
	support.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_SUPPORT_FORMATION))
	row.add_child(support)
	var title := UIKit.label("BỐ TRẬN 6v6", 28, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var roster := UIKit.button("KHO NHÂN VẬT", Color("3d587f"), 15, Vector2(150, 46))
	roster.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_ROSTER))
	row.add_child(roster)
	row.add_child(CoinBar.new())
	return row


func _build_formation_panel() -> Control:
	var panel := UIKit.panel(Color(0.04, 0.07, 0.12, 0.94), 14, Color("5f7d9f"), 2)
	panel.custom_minimum_size.x = 492
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UIKit.label("VỊ TRÍ THAM CHIẾN", 18, Color("a9d4ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var note := UIKit.label("Cột trái và cột phải, mỗi cột 3 vị trí", 13, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(note)
	_slot_grid = GridContainer.new()
	_slot_grid.columns = 2
	_slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_grid.add_theme_constant_override("h_separation", 8)
	_slot_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_slot_grid)
	return panel


func _build_character_panel() -> Control:
	var panel := UIKit.panel(Color(0.04, 0.07, 0.12, 0.94), 14, Color("6b598f"), 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UIKit.label("CHỌN NHÂN VẬT ĐANG SỞ HỮU", 18, Color("d2b7ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_character_grid = GridContainer.new()
	_character_grid.columns = 2
	_character_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_grid.add_theme_constant_override("h_separation", 8)
	_character_grid.add_theme_constant_override("v_separation", 8)
	scroll.add_child(_character_grid)
	return panel


func _refresh() -> void:
	for child in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	for row in range(3):
		_slot_grid.add_child(_make_slot_button(row))
		_slot_grid.add_child(_make_slot_button(row + 3))
	for child in _character_grid.get_children():
		_character_grid.remove_child(child)
		child.queue_free()
	for id in GameData.sorted_ids():
		if GameState.owned.has(id):
			_character_grid.add_child(_make_character_button(id))
	_team_count.text = "Đội hiện tại: %d/%d · bấm một nhân vật đang dùng để đổi vị trí" % [GameState.team.size(), GameData.TEAM_SIZE_MAX]


func _make_slot_button(slot: int) -> Button:
	var button := FormationDragButton.new()
	button.custom_minimum_size = Vector2(222, 116)
	button.target_slot = slot
	button.focus_mode = Control.FOCUS_NONE
	var selected := slot == _selected_slot
	var bg := Color("18384a") if selected else Color("101c2c")
	var border := Color("ffe08a") if selected else Color("526984")
	var border_width := 3 if selected else 1
	button.add_theme_stylebox_override("normal", UIKit.style(bg, 10, border, border_width, 6.0))
	button.add_theme_stylebox_override("hover", UIKit.style(bg.lightened(0.12), 10, border.lightened(0.15), border_width, 6.0))
	button.add_theme_stylebox_override("pressed", UIKit.style(bg.darkened(0.12), 10, border, border_width, 6.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7
	row.offset_top = 5
	row.offset_right = -7
	row.offset_bottom = -5
	row.add_theme_constant_override("separation", 6)
	button.add_child(row)
	var id := String(GameState.team[slot]) if slot < GameState.team.size() else ""
	button.drag_character_id = id
	if id != "":
		row.add_child(UIKit.character_view(id, 78.0, Vector2(74, 96)))
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(UIKit.label("VỊ TRÍ %d" % (slot + 1), 12, Color("ffe08a")))
	if id != "":
		labels.add_child(UIKit.label(GameData.char_name(id), 17, UIKit.TEXT_COLOR))
		labels.add_child(UIKit.label("%s  ·  %d sao" % [GameData.char_tier(id), GameState.stars_of(id)], 12, UIKit.MUTED_COLOR))
	else:
		labels.add_child(UIKit.label("Chọn nhân vật", 15, UIKit.MUTED_COLOR))
	row.add_child(labels)
	UIKit.ignore_mouse(row)
	button.pressed.connect(_select_slot.bind(slot))
	button.character_dropped.connect(_drop_to_slot)
	return button


func _make_character_button(id: String) -> Button:
	var button := FormationDragButton.new()
	button.custom_minimum_size = Vector2(250, 96)
	button.drag_character_id = id
	button.focus_mode = Control.FOCUS_NONE
	var index: int = GameState.team.find(id)
	var in_team := index >= 0
	var bg := Color("183c32") if in_team else Color("111a2a")
	var border := Color("5df08a") if in_team else UIKit.tier_color(GameData.char_tier(id)).darkened(0.25)
	button.add_theme_stylebox_override("normal", UIKit.style(bg, 10, border, 2, 6.0))
	button.add_theme_stylebox_override("hover", UIKit.style(bg.lightened(0.12), 10, border.lightened(0.15), 2, 6.0))
	button.add_theme_stylebox_override("pressed", UIKit.style(bg.darkened(0.12), 10, border, 2, 6.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 7
	row.offset_top = 5
	row.offset_right = -7
	row.offset_bottom = -5
	row.add_theme_constant_override("separation", 8)
	button.add_child(row)
	row.add_child(UIKit.character_view(id, 72.0, Vector2(70, 82)))
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(UIKit.label(GameData.char_name(id), 16, UIKit.TEXT_COLOR))
	labels.add_child(UIKit.label("%s  ·  %d sao" % [GameData.char_tier(id), GameState.stars_of(id)], 12, UIKit.MUTED_COLOR))
	labels.add_child(UIKit.label("ĐANG Ở Ô %d" % (index + 1) if in_team else "NHẤN ĐỂ GÁN", 11, Color("5df08a") if in_team else Color("b9c2d2")))
	row.add_child(labels)
	UIKit.ignore_mouse(row)
	button.pressed.connect(_assign_character.bind(id))
	return button


func _drop_to_slot(slot: int, id: String) -> void:
	if not GameState.assign_team_slot(slot, id):
		_hint.text = "Không thể gán nhân vật này vào đội hình."
		return
	_selected_slot = slot
	_hint.text = "%s đã được chuyển vào vị trí %d." % [GameData.char_name(id), slot + 1]
	_refresh()


func _select_slot(slot: int) -> void:
	_selected_slot = slot
	_hint.text = "Đã chọn vị trí %d. Bây giờ chọn một nhân vật ở danh sách bên phải." % (slot + 1)
	_refresh()


func _assign_character(id: String) -> void:
	if _selected_slot < 0:
		_hint.text = "Hãy chọn vị trí tham chiến trước. Nhân vật đang trong đội có thể đổi chỗ bằng cách gán vào vị trí khác."
		return
	if not GameState.assign_team_slot(_selected_slot, id):
		_hint.text = "Không thể cập nhật. Cần sở hữu đủ 6 nhân vật khác nhau để lập đội 6v6."
		return
	_hint.text = "%s đã được gán vào vị trí %d. Thay đổi đã tự lưu." % [GameData.char_name(id), _selected_slot + 1]
	_refresh()


func _confirm_formation() -> void:
	if GameState.team.size() != GameData.TEAM_SIZE_MAX:
		_hint.text = "Đội hiện có %d/6 nhân vật. Hãy gán đủ sáu vị trí trước khi ra trận." % GameState.team.size()
		return
	SceneManager.change_scene(GameData.SCENE_LOBBY)
