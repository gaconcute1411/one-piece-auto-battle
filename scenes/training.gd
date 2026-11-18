extends Control
## Character picker for the practice arena. Characters may be unowned, but never duplicated.

const GOLD := Color("ffd36a")
var _selected: Array[String] = []
var _grid: GridContainer
var _selection_label: Label
var _start_button: Button


func _ready() -> void:
	UIKit.add_background(self, 0.56)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(_header())
	root.add_child(UIKit.label("Chọn từ 1 đến 6 nhân vật để thử kỹ năng với 6 hình nộm. Nhân vật chưa sở hữu vẫn chọn được; không thể chọn trùng.", 16, UIKit.MUTED_COLOR))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(_grid)
	root.add_child(_footer())
	_refresh()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var back := UIKit.button("‹ Sảnh", Color("3c465c"), 18, Vector2(120, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(back)
	var title := UIKit.label("HUẤN LUYỆN", 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	return row


func _footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_selection_label = UIKit.label("", 16, Color("e8d39c"))
	_selection_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_selection_label)
	var clear_button := UIKit.button("BỎ CHỌN HẾT", Color("4a4f63"), 14, Vector2(170, 46))
	clear_button.pressed.connect(_clear_selection)
	row.add_child(clear_button)
	_start_button = UIKit.button("VÀO HUẤN LUYỆN", Color("bd7b34"), 17, Vector2(230, 50))
	_start_button.pressed.connect(_start_training)
	row.add_child(_start_button)
	return row


func _refresh() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	for id in GameData.sorted_ids():
		_grid.add_child(_make_character_card(id))
	var names: Array[String] = []
	for id in _selected:
		names.append(GameData.char_name(id))	
	_selection_label.text = "Đội thử nghiệm %d/6: %s" % [_selected.size(), " · ".join(names) if not names.is_empty() else "chưa chọn nhân vật"]
	_start_button.disabled = _selected.is_empty()
	_start_button.text = "VÀO HUẤN LUYỆN · %d/6" % _selected.size()


func _make_character_card(id: String) -> Button:
	var selected := _selected.has(id)
	var card := Button.new()
	card.custom_minimum_size = Vector2(204, 166)
	card.focus_mode = Control.FOCUS_NONE
	var bg := Color(0.13, 0.19, 0.23, 0.96) if selected else Color(0.07, 0.09, 0.15, 0.94)
	var border := Color("5df08a") if selected else UIKit.tier_color(GameData.char_tier(id))
	card.add_theme_stylebox_override("normal", UIKit.style(bg, 12, border, 3 if selected else 1, 6.0))
	card.add_theme_stylebox_override("hover", UIKit.style(bg.lightened(0.1), 12, border, 3, 6.0))
	card.add_theme_stylebox_override("pressed", UIKit.style(bg.darkened(0.12), 12, border, 3, 6.0))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 5
	content.offset_right = -5
	content.offset_top = 4
	content.offset_bottom = -4
	content.add_theme_constant_override("separation", 1)
	card.add_child(content)
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_child(UIKit.tier_badge(GameData.char_tier(id), 12))
	content.add_child(line)
	content.add_child(UIKit.character_view(id, 132.0, Vector2(188, 116)))
	content.add_child(UIKit.label(("✓  " if selected else "") + GameData.char_name(id), 16, Color("5df08a") if selected else UIKit.TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.ignore_mouse(content)
	card.pressed.connect(_toggle_character.bind(id))
	return card


func _clear_selection() -> void:
	_selected.clear()
	_refresh()


func _toggle_character(id: String) -> void:
	if _selected.has(id):
		_selected.erase(id)
	elif _selected.size() < GameData.TEAM_SIZE_MAX:
		_selected.append(id)
	else:
		UIKit.toast(self, "Đội huấn luyện tối đa 6 nhân vật.")
	_refresh()


func _start_training() -> void:
	if not GameState.begin_training_battle(_selected):
		UIKit.toast(self, "Chọn ít nhất một nhân vật, tối đa 6 và không trùng nhau.")
