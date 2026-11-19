extends Control
## Encourage formation page with exactly six stat-specific supporter slots.

const GOLD := Color("f4ce7e")

var _slot_grid: GridContainer
var _summary: VBoxContainer
var _hint: Label


func _ready() -> void:
	UIKit.add_background(self, 0.40)
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
	_hint = UIKit.label("Sáu vị trí cổ vũ cộng chỉ số theo vai trò; có thể chọn nhân vật đang ở đội chính.", 13, Color("f0d8b4"), HORIZONTAL_ALIGNMENT_CENTER)
	root.add_child(_hint)
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	root.add_child(body)
	body.add_child(_slots_panel())
	body.add_child(_summary_panel())
	_refresh()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UIKit.label("ĐỘI HÌNH", 21, Color("ffedca")))
	var formation := _tab_button("BỐ TRẬN", false)
	formation.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_FORMATION))
	row.add_child(formation)
	row.add_child(_tab_button("CỔ VŨ", true))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	row.add_child(CoinBar.new())
	var close := _close_button()
	close.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(close)
	return row


func _slots_panel() -> Control:
	var panel := _wood_panel(Color("382416"), Color("d1a552"))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)
	var head := HBoxContainer.new()
	var title := UIKit.label("VỊ TRÍ CỔ VŨ · 6 NHÂN VẬT", 15, Color("ffedca"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(UIKit.label("2 HP · 1 ATK · 1 MAG · 2 DEF", 11, GOLD))
	col.add_child(head)
	_slot_grid = GridContainer.new()
	_slot_grid.columns = 2
	_slot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_grid.add_theme_constant_override("h_separation", 8)
	_slot_grid.add_theme_constant_override("v_separation", 8)
	col.add_child(_slot_grid)
	return panel


func _summary_panel() -> Control:
	var panel := _wood_panel(Color("332114"), Color("9d7036"))
	panel.custom_minimum_size.x = 245
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary = VBoxContainer.new()
	_summary.alignment = BoxContainer.ALIGNMENT_CENTER
	_summary.add_theme_constant_override("separation", 9)
	panel.add_child(_summary)
	return panel


func _refresh() -> void:
	for child in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	for slot in range(6):
		_slot_grid.add_child(_make_slot(slot))
	_refresh_summary()


func _make_slot(slot: int) -> Control:
	var stat: String = String(GameData.SUPPORT_SLOT_STATS[slot])
	var id: String = String(GameState.support_team[slot]) if slot < GameState.support_team.size() else ""
	var accent := _stat_color(stat)
	var card := _wood_panel(Color("251910"), accent.darkened(0.15))
	card.custom_minimum_size = Vector2(0, 132)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	card.add_child(row)
	if not id.is_empty():
		row.add_child(UIKit.character_view(id, 82.0, Vector2(74, 112)))
	else:
		var empty := PanelContainer.new()
		empty.custom_minimum_size = Vector2(74, 112)
		empty.add_theme_stylebox_override("panel", UIKit.style(Color("17120e"), 8, Color("8c704c"), 1, 0.0))
		empty.add_child(UIKit.label("+", 30, Color("d4b67e"), HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(empty)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 3)
	info.add_child(UIKit.label("Ô %d · %s" % [slot + 1, _stat_name(stat)], 13, accent))
	if id.is_empty():
		info.add_child(UIKit.label("Chưa chọn", 11, UIKit.MUTED_COLOR))
	else:
		info.add_child(UIKit.label(GameData.char_name(id), 13, Color("fff0d6")))
		info.add_child(UIKit.label("+%s chỉ số cho đội chính" % _number(_support_amount(id, stat)), 10, Color("9de0b0")))
	var select := OptionButton.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item("Trống · chọn nhân vật")
	select.set_item_metadata(0, "")
	var selected_index := 0
	for candidate in GameData.sorted_ids():
		if not GameState.owned.has(candidate):
			continue
		select.add_item("%s · %s · ★%d" % [GameData.char_name(candidate), GameData.char_tier(candidate), GameState.stars_of(candidate)])
		select.set_item_metadata(select.item_count - 1, candidate)
		if String(candidate) == id:
			selected_index = select.item_count - 1
	select.select(selected_index)
	select.item_selected.connect(_on_selected.bind(slot, select))
	info.add_child(select)
	row.add_child(info)
	return card


func _refresh_summary() -> void:
	for child in _summary.get_children():
		_summary.remove_child(child)
		child.queue_free()
	_summary.add_child(UIKit.label("HIỆU ỨNG CỔ VŨ", 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	_summary.add_child(UIKit.label("Mỗi nhân vật truyền 5% một chỉ số cơ bản cho cả đội chính.", 11, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	var bonus: Dictionary = GameState.support_team_bonus()
	for stat in ["hp", "atk", "mag", "def"]:
		var row := HBoxContainer.new()
		var label := UIKit.label(_stat_name(stat), 13, _stat_color(stat))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(UIKit.label("+%s" % _number(int(bonus[stat])), 14, Color("fff0d6")))
		_summary.add_child(row)
	_summary.add_child(HSeparator.new())
	_summary.add_child(UIKit.label("ĐANG DÙNG %d / 6 Ô" % _filled_slots(), 12, Color("d6bd93"), HORIZONTAL_ALIGNMENT_CENTER))
	var note := UIKit.label("Có thể chọn nhân vật đang ở đội chính, nhưng không thể đặt cùng một nhân vật vào hai ô cổ vũ.", 11, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.add_child(note)
	var clear := _gold_button("XÓA ĐỘI CỔ VŨ", Vector2(178, 36))
	clear.pressed.connect(_clear_support)
	_summary.add_child(clear)


func _on_selected(index: int, slot: int, select: OptionButton) -> void:
	var id := String(select.get_item_metadata(index))
	if not GameState.set_support_slot(slot, id):
		_hint.text = "Hãy chọn nhân vật sở hữu; mỗi nhân vật chỉ được xếp vào một ô cổ vũ."
		_refresh()
		return
	_hint.text = "Đã lưu đội cổ vũ. Bonus chiến lực được cập nhật theo chỉ số đội chính."
	_refresh()


func _clear_support() -> void:
	GameState.support_team = ["", "", "", "", "", ""]
	GameState.save_game()
	GameState.roster_changed.emit()
	_hint.text = "Đã xóa các vị trí cổ vũ."
	_refresh()


func _support_amount(id: String, stat: String) -> int:
	return int(round(GameState.character_primary_stat(id, stat) * GameData.SUPPORT_STAT_RATE))


func _filled_slots() -> int:
	var total := 0
	for id in GameState.support_team:
		if not String(id).is_empty():
			total += 1
	return total


func _wood_panel(bg: Color, border: Color) -> PanelContainer:
	var panel := UIKit.panel(bg, 10, border, 2)
	panel.add_theme_stylebox_override("panel", UIKit.style(bg, 10, border, 2, 7.0))
	return panel


func _gold_button(text: String, size: Vector2) -> Button:
	var button := UIKit.button(text, Color("916127"), 11, size)
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


func _stat_name(stat: String) -> String:
	return {"hp": "HP", "atk": "ATK", "mag": "MAG", "def": "DEF"}.get(stat, stat.to_upper())


func _stat_color(stat: String) -> Color:
	return {"hp": Color("f27470"), "atk": Color("f5ad5c"), "mag": Color("79c9f0"), "def": Color("91cf7c")}.get(stat, GOLD)


func _number(value: int) -> String:
	var raw := str(value)
	var output := ""
	for index in range(raw.length()):
		if index > 0 and (raw.length() - index) % 3 == 0:
			output += ","
		output += raw[index]
	return output
