extends Control

var _character_grid: GridContainer
var _equipment_panel: VBoxContainer
var _selected_id: String = ""
var _hint: Label


func _ready() -> void:
	_selected_id = GameState.selected_character if GameState.owned.has(GameState.selected_character) else (String(GameState.team[0]) if not GameState.team.is_empty() else "")
	UIKit.add_background(self, 0.58)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 22
	root.offset_right = -22
	root.offset_top = 14
	root.offset_bottom = -14
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(_header())
	_hint = UIKit.label("Chỉ trang bị trong túi mới có thể lắp. Có thể mua thêm tại Cửa hàng.", 13, UIKit.MUTED_COLOR)
	root.add_child(_hint)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	var roster_panel := UIKit.panel(Color(0.03, 0.07, 0.12, 0.94), 14, Color("537392"), 2)
	roster_panel.custom_minimum_size.x = 360
	body.add_child(roster_panel)
	var roster_col := VBoxContainer.new()
	roster_col.add_theme_constant_override("separation", 8)
	roster_panel.add_child(roster_col)
	roster_col.add_child(UIKit.label("NHÂN VẬT", 18, Color("b9d8ff"), HORIZONTAL_ALIGNMENT_CENTER))
	var roster_scroll := ScrollContainer.new()
	roster_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	roster_col.add_child(roster_scroll)
	_character_grid = GridContainer.new()
	_character_grid.columns = 2
	_character_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_grid.add_theme_constant_override("h_separation", 6)
	_character_grid.add_theme_constant_override("v_separation", 6)
	roster_scroll.add_child(_character_grid)
	var right_panel := UIKit.panel(Color(0.03, 0.07, 0.12, 0.94), 14, Color("5c866e"), 2)
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right_panel)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right_panel.add_child(detail_scroll)
	_equipment_panel = VBoxContainer.new()
	_equipment_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_panel.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(_equipment_panel)
	_refresh()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := UIKit.button("‹ SẢNH", Color("4a4f63"), 17, Vector2(120, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(back)
	var title := UIKit.label("TRANG BỊ", 28, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	var shop := UIKit.button("CỬA HÀNG", Color("397b52"), 15, Vector2(145, 46))
	shop.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_SHOP))
	row.add_child(shop)
	row.add_child(CoinBar.new())
	return row


func _refresh() -> void:
	for child in _character_grid.get_children():
		_character_grid.remove_child(child)
		child.queue_free()
	for id in GameData.sorted_ids():
		if GameState.owned.has(id):
			_character_grid.add_child(_character_card(String(id)))
	for child in _equipment_panel.get_children():
		_equipment_panel.remove_child(child)
		child.queue_free()
	if _selected_id == "":
		_equipment_panel.add_child(UIKit.label("Chưa có nhân vật nào trong kho.", 18, UIKit.MUTED_COLOR))
		return
	_equipment_panel.add_child(UIKit.label("%s · %s · %d sao" % [GameData.char_name(_selected_id), GameData.char_tier(_selected_id), GameState.stars_of(_selected_id)], 22, Color("d5f5dc")))
	_equipment_panel.add_child(UIKit.character_view(_selected_id, 120.0, Vector2(140, 130)))
	_equipment_panel.add_child(UIKit.label("Trang bị sở hữu: %d món" % _owned_equipment_count(), 14, Color("a8b9c8")))
	var equipped: Dictionary = GameState.equipment.get(_selected_id, {})
	for slot in GameData.EQUIPMENT_SLOTS:
		_equipment_panel.add_child(_slot_row(slot, String(equipped.get(slot, ""))))
	var shop := UIKit.button("MỞ CỬA HÀNG TRANG BỊ", Color("397b52"), 15, Vector2(270, 44))
	shop.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_SHOP))
	_equipment_panel.add_child(shop)


func _character_card(id: String) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(160, 82)
	var selected := id == _selected_id
	button.add_theme_stylebox_override("normal", UIKit.style(Color("183c32") if selected else Color("101a2a"), 8, Color("ffe08a") if selected else UIKit.tier_color(GameData.char_tier(id)), 2, 4.0))
	button.add_theme_stylebox_override("hover", UIKit.style(Color("203d35"), 8, Color("ffe08a"), 2, 4.0))
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_theme_constant_override("separation", 4)
	button.add_child(row)
	row.add_child(UIKit.character_view(id, 60.0, Vector2(56, 72)))
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(UIKit.label(GameData.char_name(id), 13, UIKit.TEXT_COLOR))
	labels.add_child(UIKit.label("%d sao" % GameState.stars_of(id), 11, UIKit.MUTED_COLOR))
	row.add_child(labels)
	UIKit.ignore_mouse(row)
	button.pressed.connect(_select_character.bind(id))
	return button


func _select_character(id: String) -> void:
	_selected_id = id
	GameState.selected_character = id
	_refresh()


func _slot_row(slot: String, selected_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := UIKit.label(slot, 13, UIKit.MUTED_COLOR)
	label.custom_minimum_size.x = 78
	row.add_child(label)
	var select := OptionButton.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item("Trống · chọn vật phẩm")
	select.set_item_metadata(0, "")
	var selected_index := 0
	for item_id in GameData.equipment_ids_for_slot(slot):
		var count: int = GameState.equipment_count(item_id)
		if count <= 0:
			continue
		var used: int = GameState.equipment_item_use_count(item_id)
		var is_current := String(item_id) == selected_id
		select.add_item("%s · túi %d · đang lắp %d" % [GameData.EQUIPMENT[item_id]["name"], count, used])
		var index := select.item_count - 1
		select.set_item_metadata(index, item_id)
		if used >= count and not is_current:
			select.set_item_disabled(index, true)
		if is_current:
			selected_index = index
	select.select(selected_index)
	select.item_selected.connect(_on_equipment_selected.bind(slot, select))
	row.add_child(select)
	return row


func _on_equipment_selected(index: int, slot: String, select: OptionButton) -> void:
	var item_id: String = String(select.get_item_metadata(index))
	if not GameState.equip_item(_selected_id, slot, item_id):
		_hint.text = "Trang bị này đã được lắp cho nhân vật khác hoặc không còn trong túi."
		_refresh()
		return
	_hint.text = "%s · %s đã được cập nhật." % [GameData.char_name(_selected_id), slot]
	_refresh()


func _owned_equipment_count() -> int:
	var count := 0
	for item_id in GameData.EQUIPMENT:
		count += GameState.equipment_count(String(item_id))
	return count
