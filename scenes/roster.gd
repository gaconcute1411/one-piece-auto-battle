extends Control
## Bộ sưu tập nhân vật + chọn đội hình ra trận (tối đa 6).

var _grid: GridContainer
var _team_label: Label
var _shard_select: OptionButton
var _shard_info: Label
var _shard_exchange_button: Button


func _ready() -> void:
	UIKit.add_background(self, 0.55)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var margin := MarginContainer.new()
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	root.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	# --- thanh trên
	var top := HBoxContainer.new()
	col.add_child(top)
	var back := UIKit.button("< Sảnh", Color("4a4f63"), 20, Vector2(120, 48))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	top.add_child(back)
	var title := UIKit.label("KHO NHÂN VẬT", 30, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	var formation := UIKit.button("BỐ TRẬN", Color("367d62"), 16, Vector2(130, 48))
	formation.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_FORMATION))
	top.add_child(formation)
	top.add_child(CoinBar.new())

	_team_label = UIKit.label("", 20, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_team_label)
	col.add_child(_build_shard_exchange())

	# --- lưới nhân vật
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 4
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 14)
	_grid.add_theme_constant_override("v_separation", 14)
	scroll.add_child(_grid)

	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	for id in GameData.sorted_ids():
		_grid.add_child(_make_card(id))
	var names: Array = []
	for id in GameState.team:
		names.append(GameData.char_name(id))
	_team_label.text = "Đội hình (%d/%d): %s   ·   bấm nhân vật để nâng cấp và trang bị" % [
		GameState.team.size(), GameData.TEAM_SIZE_MAX, ", ".join(names)]
	_update_shard_exchange()


func _build_shard_exchange() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.9), 10, Color("c99c55"), 1)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)
	row.add_child(UIKit.label("Mảnh nhân vật", 16, Color("f0d08a")))
	_shard_select = OptionButton.new()
	_shard_select.custom_minimum_size.x = 260
	for id in GameData.sorted_ids():
		var state: String = "· đổi bản sao" if GameState.owned.has(id) else "· nhân vật mới"
		_shard_select.add_item("%s · %s %s" % [GameData.char_tier(id), GameData.char_name(id), state])
		_shard_select.set_item_metadata(_shard_select.item_count - 1, id)
	row.add_child(_shard_select)
	_shard_info = UIKit.label("", 14, UIKit.MUTED_COLOR)
	_shard_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_shard_info)
	_shard_exchange_button = UIKit.button("ĐỔI NHÂN VẬT", Color("a83d39"), 14, Vector2(180, 40))
	_shard_exchange_button.pressed.connect(_exchange_selected_shards)
	row.add_child(_shard_exchange_button)
	_shard_select.item_selected.connect(func(_index: int): _update_shard_exchange())
	return panel


func _update_shard_exchange() -> void:
	if _shard_select == null:
		return
	if _shard_select.item_count == 0:
		_shard_info.text = "Chưa có nhân vật trong danh sách."
		_shard_exchange_button.disabled = true
		return
	var id: String = String(_shard_select.get_item_metadata(_shard_select.selected))
	var tier: String = GameData.char_tier(id)
	var required: int = int(GameData.CHARACTER_SHARD_COST[tier])
	var current: int = GameState.shards_of(id)
	_shard_info.text = "%s: %d/%d mảnh" % [GameData.char_name(id), current, required]
	_shard_exchange_button.disabled = current < required


func _exchange_selected_shards() -> void:
	if _shard_select.item_count == 0:
		return
	var id: String = String(_shard_select.get_item_metadata(_shard_select.selected))
	if GameState.exchange_character_shards(id):
		var reward_text: String = "bản sao của %s" % GameData.char_name(id) if GameState.copies_of(id) > 0 and GameState.owned.has(id) else GameData.char_name(id)
		UIKit.toast(self, "Đã đổi mảnh lấy %s!" % reward_text)
		SceneManager.change_scene(GameData.SCENE_ROSTER)
	else:
		UIKit.toast(self, "Chưa đủ mảnh của nhân vật này.")


func _make_card(id: String) -> Button:
	var owned: bool = GameState.owned.has(id)
	var in_team: bool = GameState.team.has(id)
	var tier: String = GameData.char_tier(id)
	var tcolor: Color = UIKit.tier_color(tier)

	var card := Button.new()
	card.custom_minimum_size = Vector2(250, 244)
	card.focus_mode = Control.FOCUS_NONE
	var border: Color = Color("5df08a") if in_team else (tcolor if owned else Color(1, 1, 1, 0.15))
	var bw: int = 4 if in_team else 2
	var bg := Color(0.08, 0.10, 0.17, 0.92) if owned else Color(0.05, 0.06, 0.10, 0.85)
	card.add_theme_stylebox_override("normal", UIKit.style(bg, 14, border, bw))
	card.add_theme_stylebox_override("hover", UIKit.style(bg.lightened(0.08), 14, border, bw))
	card.add_theme_stylebox_override("pressed", UIKit.style(bg.darkened(0.2), 14, border, bw))
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var inner := VBoxContainer.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_top = 8
	inner.offset_bottom = -8
	inner.add_theme_constant_override("separation", 2)
	card.add_child(inner)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UIKit.tier_badge(tier, 15))
	inner.add_child(head)

	var view := UIKit.character_view(id, 108.0, Vector2(250, 122), not owned)
	inner.add_child(view)

	if owned:
		inner.add_child(UIKit.label(GameData.char_name(id), 22, UIKit.TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
		inner.add_child(UIKit.star_row(GameState.stars_of(id), GameData.MAX_STARS))
		var st := "TRONG ĐỘI" if in_team else "SỞ HỮU · XEM CHI TIẾT"
		inner.add_child(UIKit.label(st, 15, Color("5df08a") if in_team else UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	else:
		inner.add_child(UIKit.label("???", 22, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
		inner.add_child(UIKit.label("Chưa sở hữu", 15, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	UIKit.ignore_mouse(inner)
	card.pressed.connect(_on_card_pressed.bind(id))
	return card


func _on_card_pressed(id: String) -> void:
	if not GameState.owned.has(id):
		UIKit.toast(self, "Chưa sở hữu - hãy triệu hồi để có nhân vật này")
		return
	GameState.selected_character = id
	SceneManager.change_scene(GameData.SCENE_CHARACTER)

