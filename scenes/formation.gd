extends Control
## Pirate themed formation editor; preserves the fixed six combat slots.

class FormationDragButton extends Button:
	signal character_dropped(target_slot: int, character_id: String)
	var drag_character_id: String = ""
	var target_slot: int = -1

	func _get_drag_data(_at_position: Vector2) -> Variant:
		if drag_character_id.is_empty():
			return null
		var preview := Label.new()
		preview.text = GameData.char_name(drag_character_id)
		preview.add_theme_color_override("font_color", Color("ffe8ae"))
		set_drag_preview(preview)
		return {"character_id": drag_character_id}

	func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
		return target_slot >= 0 and data is Dictionary and data.has("character_id")

	func _drop_data(_at_position: Vector2, data: Variant) -> void:
		character_dropped.emit(target_slot, String(data["character_id"]))


const GOLD := Color("f4ce7e")
const WOOD := Color("4c2c1b")

var _slot_grid: GridContainer
var _character_list: VBoxContainer
var _hint: Label
var _team_count: Label
var _detail: VBoxContainer
var _selected_slot: int = 0


func _ready() -> void:
	GameState.pending_battle = {}
	UIKit.add_background(self, 0.38)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	root.add_child(_header())
	_hint = UIKit.label("Chọn một ô rồi bấm nhân vật, hoặc kéo thả nhân vật vào ô muốn đặt.", 13, Color("f0d8b4"), HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_hint)
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	root.add_child(content)
	content.add_child(_owned_panel())
	content.add_child(_formation_panel())
	content.add_child(_selected_panel())
	root.add_child(_footer())
	_refresh()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var title := UIKit.label("ĐỘI HÌNH", 21, Color("ffedca"))
	row.add_child(title)
	var battle_tab := _tab_button("BỐ TRẬN", true)
	row.add_child(battle_tab)
	var support_tab := _tab_button("CỔ VŨ", false)
	support_tab.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_SUPPORT_FORMATION))
	row.add_child(support_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(CoinBar.new())
	var close := _close_button()
	close.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(close)
	return row


func _owned_panel() -> Control:
	var panel := _wood_panel(Color("332114"), Color("b98643"))
	panel.custom_minimum_size.x = 224
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(UIKit.label("THUYỀN VIÊN", 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label("Nhấn để gán · kéo để đổi", 10, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_character_list = VBoxContainer.new()
	_character_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_character_list.add_theme_constant_override("separation", 5)
	scroll.add_child(_character_list)
	return panel


func _formation_panel() -> Control:
	var panel := _wood_panel(Color("382416"), Color("d1a552"))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var head := HBoxContainer.new()
	var label := UIKit.label("ĐỘI CHÍNH · 6 VỊ TRÍ", 15, Color("ffedca"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	head.add_child(UIKit.label("2 cột × 3 hàng", 11, UIKit.MUTED_COLOR))
	col.add_child(head)
	_slot_grid = GridContainer.new()
	_slot_grid.columns = 2
	_slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_grid.add_theme_constant_override("h_separation", 7)
	_slot_grid.add_theme_constant_override("v_separation", 7)
	col.add_child(_slot_grid)
	return panel


func _selected_panel() -> Control:
	var panel := _wood_panel(Color("332114"), Color("9d7036"))
	panel.custom_minimum_size.x = 250
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail = VBoxContainer.new()
	_detail.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_theme_constant_override("separation", 5)
	panel.add_child(_detail)
	return panel


func _footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_team_count = UIKit.label("", 14, GOLD)
	_team_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_team_count)
	var confirm := _gold_button("LƯU BỐ TRẬN", Vector2(166, 40))
	confirm.pressed.connect(_confirm_formation)
	row.add_child(confirm)
	return row


func _refresh() -> void:
	for child in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	for row in range(3):
		_slot_grid.add_child(_make_slot_button(row))
		_slot_grid.add_child(_make_slot_button(row + 3))
	for child in _character_list.get_children():
		_character_list.remove_child(child)
		child.queue_free()
	for id in GameData.sorted_ids():
		if GameState.owned.has(id):
			_character_list.add_child(_make_character_button(String(id)))
	_refresh_detail()
	_team_count.text = "ĐỘI %d / %d    ·    ⚔ CHIẾN LỰC %s" % [GameState.team.size(), GameData.TEAM_SIZE_MAX, _number(GameState.calcTeamCP(GameState.team))]


func _make_slot_button(slot: int) -> Button:
	var button := FormationDragButton.new()
	button.custom_minimum_size = Vector2(0, 118)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.target_slot = slot
	button.focus_mode = Control.FOCUS_NONE
	var selected := slot == _selected_slot
	var base := Color("61401f") if selected else Color("271a12")
	var border := Color("ffdf88") if selected else Color("9d7540")
	button.add_theme_stylebox_override("normal", UIKit.style(base, 9, border, 2, 5.0))
	button.add_theme_stylebox_override("hover", UIKit.style(base.lightened(0.12), 9, border.lightened(0.15), 2, 5.0))
	button.add_theme_stylebox_override("pressed", UIKit.style(base.darkened(0.12), 9, border, 2, 5.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 5
	row.offset_top = 3
	row.offset_right = -5
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 6)
	button.add_child(row)
	var id := String(GameState.team[slot]) if slot < GameState.team.size() else ""
	button.drag_character_id = id
	if id != "":
		row.add_child(UIKit.character_view(id, 76.0, Vector2(68, 96)))
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(UIKit.label("VỊ TRÍ %d" % (slot + 1), 10, Color("edc76e")))
	if id != "":
		labels.add_child(UIKit.label(GameData.char_name(id), 13, Color("fff0d6")))
		labels.add_child(UIKit.label("%s · ★%d" % [GameData.char_tier(id), GameState.stars_of(id)], 10, UIKit.MUTED_COLOR))
		labels.add_child(UIKit.label("⚔ %s" % _number(GameState.calcCharacterCP(id)), 11, GOLD))
	else:
		labels.add_child(UIKit.label("TRỐNG", 13, UIKit.MUTED_COLOR))
	row.add_child(labels)
	UIKit.ignore_mouse(row)
	button.pressed.connect(_select_slot.bind(slot))
	button.character_dropped.connect(_drop_to_slot)
	return button


func _make_character_button(id: String) -> Button:
	var button := FormationDragButton.new()
	button.custom_minimum_size = Vector2(0, 68)
	button.drag_character_id = id
	button.focus_mode = Control.FOCUS_NONE
	var assigned := GameState.team.find(id)
	var fill := Color("553c24") if assigned >= 0 else Color("241910")
	var rim := Color("72bd83") if assigned >= 0 else UIKit.tier_color(GameData.char_tier(id)).darkened(0.15)
	button.add_theme_stylebox_override("normal", UIKit.style(fill, 7, rim, 1, 3.0))
	button.add_theme_stylebox_override("hover", UIKit.style(fill.lightened(0.14), 7, rim.lightened(0.15), 2, 3.0))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 4
	row.offset_top = 3
	row.offset_right = -4
	row.offset_bottom = -3
	row.add_theme_constant_override("separation", 5)
	button.add_child(row)
	row.add_child(_face(id, Vector2(48, 52)))
	var labels := VBoxContainer.new()
	labels.alignment = BoxContainer.ALIGNMENT_CENTER
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	labels.add_child(UIKit.label(GameData.char_name(id), 11, Color("fff0d6")))
	labels.add_child(UIKit.label("%s · ⚔ %s" % [GameData.char_tier(id), _number(GameState.calcCharacterCP(id))], 9, GOLD))
	row.add_child(labels)
	UIKit.ignore_mouse(row)
	button.pressed.connect(_assign_character.bind(id))
	return button


func _refresh_detail() -> void:
	for child in _detail.get_children():
		_detail.remove_child(child)
		child.queue_free()
	var id := String(GameState.team[_selected_slot]) if _selected_slot >= 0 and _selected_slot < GameState.team.size() else ""
	if id.is_empty():
		_detail.add_child(UIKit.label("CHỌN VỊ TRÍ", 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		_detail.add_child(UIKit.label("Chọn một thẻ trống để xem và gán thuyền viên.", 12, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
		return
	_detail.add_child(UIKit.character_view(id, 126.0, Vector2(154, 168)))
	_detail.add_child(UIKit.label(GameData.char_name(id), 18, Color("fff0d6"), HORIZONTAL_ALIGNMENT_CENTER))
	_detail.add_child(UIKit.label("%s · Cấp %d · ★%d" % [GameData.char_tier(id), GameState.level_of(id), GameState.stars_of(id)], 11, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	_detail.add_child(UIKit.label("⚔ CHIẾN LỰC %s" % _number(GameState.calcCharacterCP(id)), 15, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var stats: Dictionary = _final_primary_stats(id)
	for stat in ["hp", "atk", "mag", "def"]:
		_detail.add_child(UIKit.label("%s   %s" % [_stat_name(stat), _number(int(stats[stat]))], 12, Color("ead5b5"), HORIZONTAL_ALIGNMENT_CENTER))
	var remove := _gold_button("BỎ KHỎI ĐỘI", Vector2(184, 34))
	remove.pressed.connect(_remove_selected)
	_detail.add_child(remove)


func _select_slot(slot: int) -> void:
	_selected_slot = slot
	_hint.text = "Đã chọn vị trí %d. Chọn thuyền viên bên trái để gán." % (slot + 1)
	_refresh()


func _assign_character(id: String) -> void:
	if not GameState.assign_team_slot(_selected_slot, id):
		_hint.text = "Không thể gán nhân vật này. Mỗi vị trí cần một nhân vật sở hữu, không trùng nhau."
		return
	_hint.text = "%s đã được đặt vào vị trí %d." % [GameData.char_name(id), _selected_slot + 1]
	_refresh()


func _drop_to_slot(slot: int, id: String) -> void:
	if not GameState.assign_team_slot(slot, id):
		_hint.text = "Không thể gán nhân vật này vào đội hình."
		return
	_selected_slot = slot
	_hint.text = "%s đã được chuyển vào vị trí %d." % [GameData.char_name(id), slot + 1]
	_refresh()


func _remove_selected() -> void:
	var id := String(GameState.team[_selected_slot]) if _selected_slot < GameState.team.size() else ""
	if id.is_empty():
		return
	GameState.toggle_team_member(id)
	_hint.text = "%s đã rời đội hình." % GameData.char_name(id)
	_refresh()


func _confirm_formation() -> void:
	if GameState.team.size() != GameData.TEAM_SIZE_MAX:
		_hint.text = "Đội hiện có %d/6 nhân vật. Hãy gán đủ sáu vị trí." % GameState.team.size()
		return
	SceneManager.change_scene(GameData.SCENE_LOBBY)


func _final_primary_stats(id: String) -> Dictionary:
	var base: Dictionary = GameData.BASE_STATS[id]
	var flat: Dictionary = GameState.character_flat_bonus(id)
	var percent: Dictionary = GameState.character_percent_bonus(id)
	var support: Dictionary = GameState.support_team_bonus() if GameState.team.has(id) else {}
	var result := {}
	for stat in ["hp", "atk", "mag", "def"]:
		result[stat] = int(round((float(base[stat]) + float(flat[stat])) * (1.0 + float(percent[stat])) + float(support.get(stat, 0))))
	return result


func _face(id: String, size: Vector2) -> TextureRect:
	var face := TextureRect.new()
	face.custom_minimum_size = size
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var path := "res://assets/character_faces/%s.png" % id
	if ResourceLoader.exists(path):
		face.texture = load(path)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


func _wood_panel(bg: Color, border: Color) -> PanelContainer:
	var panel := UIKit.panel(bg, 10, border, 2)
	panel.add_theme_stylebox_override("panel", UIKit.style(bg, 10, border, 2, 7.0))
	return panel


func _gold_button(text: String, size: Vector2) -> Button:
	var button := UIKit.button(text, Color("916127"), 12, size)
	button.add_theme_stylebox_override("normal", UIKit.style(Color("a87935"), 7, Color("e7c172"), 2, 4.0))
	button.add_theme_stylebox_override("hover", UIKit.style(Color("be914b"), 7, Color("ffebac"), 2, 4.0))
	button.add_theme_color_override("font_color", Color("fff2d2"))
	return button


func _tab_button(text: String, active: bool) -> Button:
	var fill := Color("176caa") if active else Color("57341f")
	var rim := Color("80d8ff") if active else Color("b5844a")
	var button := UIKit.button(text, fill, 13, Vector2(104, 38))
	button.add_theme_stylebox_override("normal", UIKit.style(fill, 7, rim, 2, 3.0))
	button.add_theme_stylebox_override("hover", UIKit.style(fill.lightened(0.12), 7, rim.lightened(0.12), 2, 3.0))
	return button


func _close_button() -> Button:
	var button := UIKit.button("×", Color("ad202b"), 25, Vector2(42, 40))
	button.add_theme_stylebox_override("normal", UIKit.style(Color("b6202a"), 20, Color("ffd4a3"), 3, 0.0))
	button.add_theme_stylebox_override("hover", UIKit.style(Color("e54942"), 20, Color.WHITE, 3, 0.0))
	return button


func _number(value: int) -> String:
	var raw := str(value)
	var output := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			output += ","
		output += raw[index]
	return output


func _stat_name(stat: String) -> String:
	return {"hp": "HP", "atk": "ATK", "mag": "MAG", "def": "DEF"}.get(stat, stat.to_upper())
