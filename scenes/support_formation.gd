extends Control

var _slot_grid: GridContainer
var _summary: Label
var _hint: Label


func _ready() -> void:
	UIKit.add_background(self, 0.62)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(_header())
	var panel := UIKit.panel(Color(0.04, 0.07, 0.12, 0.94), 16, Color("7250a7"), 2)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UIKit.label("Sáu nhân vật cổ vũ cộng chỉ số cho toàn đội chính", 17, Color("d4c1ff"), HORIZONTAL_ALIGNMENT_CENTER))
	_hint = UIKit.label("Mỗi vị trí cộng 5% chỉ số tương ứng. Sáu ô cổ vũ không trùng nhau; có thể dùng nhân vật đang ở đội chính.", 13, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(scroll)
	_slot_grid = GridContainer.new()
	_slot_grid.columns = 2
	_slot_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slot_grid.add_theme_constant_override("h_separation", 12)
	_slot_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_slot_grid)
	_summary = UIKit.label("", 16, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_summary)
	_refresh()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := UIKit.button("‹ BỐ TRẬN", Color("4a4f63"), 16, Vector2(145, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_FORMATION))
	row.add_child(back)
	var title := UIKit.label("ĐỘI HÌNH CỔ VŨ", 27, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	return row


func _refresh() -> void:
	for child in _slot_grid.get_children():
		_slot_grid.remove_child(child)
		child.queue_free()
	for slot in range(GameData.SUPPORT_SLOT_STATS.size()):
		_slot_grid.add_child(_make_slot(slot))
	var bonus: Dictionary = GameState.support_team_bonus()
	_summary.text = "TỔNG CỘNG CHO ĐỘI CHÍNH   HP +%d   ·   ATK +%d   ·   MAG +%d   ·   DEF +%d" % [bonus.hp, bonus.atk, bonus.mag, bonus.def]


func _make_slot(slot: int) -> Control:
	var stat: String = String(GameData.SUPPORT_SLOT_STATS[slot])
	var id: String = String(GameState.support_team[slot]) if slot < GameState.support_team.size() else ""
	var panel := UIKit.panel(Color("101a2b"), 11, Color("584b79"), 1)
	panel.custom_minimum_size = Vector2(420, 74)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(row)
	var label := UIKit.label("Ô %d · %s" % [slot + 1, _stat_name(stat)], 15, Color("d7c7ff"))
	label.custom_minimum_size.x = 110
	row.add_child(label)
	var slot_value := 0
	if id != "":
		slot_value = int(round(GameState.character_primary_stat(id, stat) * GameData.SUPPORT_STAT_RATE))
	var amount := UIKit.label("+%d" % slot_value, 14, Color("87e3b7"))
	amount.custom_minimum_size.x = 58
	row.add_child(amount)
	var select := OptionButton.new()
	select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select.add_item("Trống · chọn nhân vật cổ vũ")
	select.set_item_metadata(0, "")
	var selected_index := 0
	for candidate in GameData.sorted_ids():
		if not GameState.owned.has(candidate):
			continue
		select.add_item("%s · %s · %d sao" % [GameData.char_name(candidate), GameData.char_tier(candidate), GameState.stars_of(candidate)])
		select.set_item_metadata(select.item_count - 1, candidate)
		if String(candidate) == id:
			selected_index = select.item_count - 1
	select.select(selected_index)
	select.item_selected.connect(_on_selected.bind(slot, select))
	row.add_child(select)
	return panel


func _on_selected(index: int, slot: int, select: OptionButton) -> void:
	var id: String = String(select.get_item_metadata(index))
	if not GameState.set_support_slot(slot, id):
		_hint.text = "Hãy chọn nhân vật đang sở hữu. Mỗi nhân vật chỉ được chọn vào một ô cổ vũ."
		_refresh()
		return
	_hint.text = "Đã lưu đội hình cổ vũ. Mỗi ô truyền 5% chỉ số tương ứng cho cả đội chính."
	_refresh()


func _stat_name(stat: String) -> String:
	return {"hp": "HP", "atk": "ATK", "mag": "MAG", "def": "DEF"}.get(stat, stat.to_upper())
