extends Control
## Temporary hero collection page; portrait card selection opens the character profile.

const GOLD := Color("f4cf82")

var _owned_grid: GridContainer
var _shard_row: HBoxContainer


func _ready() -> void:
	UIKit.add_background(self, 0.38)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 9)
	margin.add_child(root)
	root.add_child(_header())
	root.add_child(_tabs())
	root.add_child(_collection_panel())
	root.add_child(_shards_panel())
	_refresh()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var back := _gold_button("‹ SẢNH", Vector2(116, 42))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(back)
	var title := UIKit.label("NHÂN VẬT", 27, Color("ffebc4"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	var close := _close_button()
	close.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(close)
	return row


func _tabs() -> Control:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	var heroes := _tab_button("HERO · SỞ HỮU", true)
	heroes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(heroes)
	var formation := _tab_button("BỐ TRẬN", false)
	formation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	formation.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_FORMATION))
	bar.add_child(formation)
	return bar


func _collection_panel() -> Control:
	var panel := _wood_panel(Color("382316"), Color("c6964e"))
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var heading := HBoxContainer.new()
	var label := UIKit.label("NHÂN VẬT ĐANG SỞ HỮU", 15, GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	heading.add_child(UIKit.label("%d / %d" % [GameState.owned.size(), GameData.CHARACTERS.size()], 13, UIKit.MUTED_COLOR))
	col.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_owned_grid = GridContainer.new()
	_owned_grid.columns = 4
	_owned_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_owned_grid.add_theme_constant_override("h_separation", 9)
	_owned_grid.add_theme_constant_override("v_separation", 9)
	scroll.add_child(_owned_grid)
	return panel


func _shards_panel() -> Control:
	var panel := _wood_panel(Color("342113"), Color("a77c40"))
	panel.custom_minimum_size.y = 114
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	var heading := HBoxContainer.new()
	var label := UIKit.label("ĐỔI MẢNH NHÂN VẬT", 14, GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(label)
	heading.add_child(UIKit.label("Đủ mảnh mới đổi được", 12, UIKit.MUTED_COLOR))
	col.add_child(heading)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 70
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)
	_shard_row = HBoxContainer.new()
	_shard_row.add_theme_constant_override("separation", 7)
	scroll.add_child(_shard_row)
	return panel


func _refresh() -> void:
	for child in _owned_grid.get_children():
		_owned_grid.remove_child(child)
		child.queue_free()
	for id in GameData.sorted_ids():
		if GameState.owned.has(id):
			_owned_grid.add_child(_owned_card(String(id)))
	for child in _shard_row.get_children():
		_shard_row.remove_child(child)
		child.queue_free()
	for id in GameData.sorted_ids():
		_shard_row.add_child(_shard_card(String(id)))


func _owned_card(id: String) -> Button:
	var card := Button.new()
	card.custom_minimum_size = Vector2(0, 192)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	var border := UIKit.tier_color(GameData.char_tier(id))
	card.add_theme_stylebox_override("normal", UIKit.style(Color("352216"), 9, border, 2, 5.0))
	card.add_theme_stylebox_override("hover", UIKit.style(Color("51321e"), 9, Color("ffe5ac"), 2, 5.0))
	card.add_theme_stylebox_override("pressed", UIKit.style(Color("28180f"), 9, border, 2, 5.0))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.offset_left = 5
	col.offset_top = 4
	col.offset_right = -5
	col.offset_bottom = -4
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	col.add_child(_portrait(id, Vector2(82, 112)))
	col.add_child(UIKit.label(GameData.char_name(id), 13, Color("fff0d6"), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label("%s · ★%d" % [GameData.char_tier(id), GameState.stars_of(id)], 11, Color("d7bd91"), HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label("⚔ %s" % str(GameState.calcCharacterCP(id)), 11, GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	UIKit.ignore_mouse(col)
	card.pressed.connect(_open_character.bind(id))
	return card


func _shard_card(id: String) -> Control:
	var card := _wood_panel(Color("21160f"), UIKit.tier_color(GameData.char_tier(id)).darkened(0.2))
	card.custom_minimum_size = Vector2(216, 70)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(row)
	row.add_child(_portrait(id, Vector2(46, 52)))
	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(UIKit.label(GameData.char_name(id), 10, Color("fff0d6")))
	var tier: String = GameData.char_tier(id)
	var need: int = int(GameData.CHARACTER_SHARD_COST[tier])
	var have: int = GameState.shards_of(id)
	info.add_child(UIKit.label("%d / %d mảnh" % [have, need], 10, Color("d7bd91")))
	row.add_child(info)
	var exchange := _gold_button("ĐỔI", Vector2(48, 28))
	exchange.add_theme_font_size_override("font_size", 10)
	exchange.disabled = have < need
	exchange.pressed.connect(_exchange_shards.bind(id))
	row.add_child(exchange)
	return card


func _portrait(id: String, size: Vector2) -> TextureRect:
	var face := TextureRect.new()
	face.custom_minimum_size = size
	face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	face.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var path := "res://assets/character_faces/%s_poster.png" % id
	if ResourceLoader.exists(path):
		face.texture = load(path)
	face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return face


func _open_character(id: String) -> void:
	GameState.selected_character = id
	SceneManager.change_scene(GameData.SCENE_CHARACTER)


func _exchange_shards(id: String) -> void:
	if not GameState.exchange_character_shards(id):
		UIKit.toast(self, "Chưa đủ mảnh để đổi nhân vật.")
		return
	_refresh()
	UIKit.toast(self, "Đã đổi mảnh lấy %s." % GameData.char_name(id))


func _wood_panel(bg: Color, border: Color) -> PanelContainer:
	var panel := UIKit.panel(bg, 10, border, 2)
	panel.add_theme_stylebox_override("panel", UIKit.style(bg, 10, border, 2, 8.0))
	return panel


func _gold_button(text: String, size: Vector2) -> Button:
	var button := UIKit.button(text, Color("875a25"), 14, size)
	button.add_theme_stylebox_override("normal", UIKit.style(Color("a67835"), 8, Color("f1cb78"), 2, 5.0))
	button.add_theme_stylebox_override("hover", UIKit.style(Color("bf914a"), 8, Color("fff0c3"), 2, 5.0))
	button.add_theme_stylebox_override("pressed", UIKit.style(Color("75491f"), 8, Color("e1b85f"), 2, 5.0))
	button.add_theme_color_override("font_color", Color("fff2cf"))
	return button


func _tab_button(text: String, active: bool) -> Button:
	var button := UIKit.button(text, Color("55311d"), 14, Vector2(0, 39))
	var bg := Color("176eae") if active else Color("55311d")
	var rim := Color("78d6ff") if active else Color("bd8a49")
	button.add_theme_stylebox_override("normal", UIKit.style(bg, 8, rim, 2, 5.0))
	button.add_theme_stylebox_override("hover", UIKit.style(bg.lightened(0.12), 8, rim.lightened(0.15), 2, 5.0))
	return button


func _close_button() -> Button:
	var button := UIKit.button("×", Color("a82028"), 26, Vector2(44, 42))
	button.add_theme_stylebox_override("normal", UIKit.style(Color("bd2631"), 22, Color("ffd4a3"), 3, 0.0))
	button.add_theme_stylebox_override("hover", UIKit.style(Color("e54a44"), 22, Color.WHITE, 3, 0.0))
	return button
