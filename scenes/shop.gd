extends Control

var _items: GridContainer
var _category: String = "equipment"
var _hint: Label


func _ready() -> void:
	UIKit.add_background(self, 0.58)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(_header())
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 10)
	var gear_tab := UIKit.button("TRANG BỊ", Color("47795d"), 16, Vector2(170, 42))
	gear_tab.pressed.connect(_set_category.bind("equipment"))
	tabs.add_child(gear_tab)
	var gem_tab := UIKit.button("NGỌC", Color("76539b"), 16, Vector2(170, 42))
	gem_tab.pressed.connect(_set_category.bind("gems"))
	tabs.add_child(gem_tab)
	root.add_child(tabs)
	_hint = UIKit.label("Mua trang bị dùng chung hoặc ngọc cấp 1 bằng xu.", 14, UIKit.MUTED_COLOR)
	root.add_child(_hint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_items = GridContainer.new()
	_items.columns = 3
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.add_theme_constant_override("h_separation", 12)
	_items.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_items)
	_refresh()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var back := UIKit.button("‹ SẢNH", Color("4a4f63"), 17, Vector2(120, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(back)
	var title := UIKit.label("CỬA HÀNG", 28, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	return row


func _refresh() -> void:
	for child in _items.get_children():
		_items.remove_child(child)
		child.queue_free()
	if _category == "equipment":
		for item_id in GameData.EQUIPMENT:
			_items.add_child(_equipment_card(String(item_id)))
	else:
		for gem_type in GameData.GEMS:
			_items.add_child(_gem_card(String(gem_type)))


func _set_category(category: String) -> void:
	_category = category
	_refresh()


func _equipment_card(item_id: String) -> Control:
	var item: Dictionary = GameData.EQUIPMENT[item_id]
	var price: int = int(GameData.SHOP_EQUIPMENT_PRICES[item_id])
	var card := UIKit.panel(Color("0a1524"), 13, Color("5c866e"), 2)
	card.custom_minimum_size = Vector2(300, 142)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	col.add_child(UIKit.label(String(item["name"]), 17, Color("d5f5dc")))
	col.add_child(UIKit.label("%s · %s" % [String(item["slot"]), _stats_text(item["stats"])], 12, UIKit.MUTED_COLOR))
	col.add_child(UIKit.label("Trong túi: %d  ·  Đang lắp: %d" % [GameState.equipment_count(item_id), GameState.equipment_item_use_count(item_id)], 12, Color("a8b9c8")))
	var buy := UIKit.button("MUA · %d xu" % price, Color("397b52"), 14, Vector2(190, 38))
	buy.disabled = GameState.coins < price
	buy.pressed.connect(_buy_equipment.bind(item_id))
	col.add_child(buy)
	return card


func _gem_card(gem_type: String) -> Control:
	var gem: Dictionary = GameData.GEMS[gem_type]
	var price: int = GameData.SHOP_GEM_FLAT_PRICE if String(gem["mode"]) == "flat" else GameData.SHOP_GEM_PERCENT_PRICE
	var tint := Color("#" + String(gem["color"]))
	var edge_tint := tint.lightened(0.65) if String(gem["stat"]) == "crit_dmg" else tint.darkened(0.25)
	var text_tint := tint.lightened(0.55) if String(gem["stat"]) == "crit_dmg" else tint.lightened(0.2)
	var card := UIKit.panel(Color("0a1524"), 13, edge_tint, 2)
	card.custom_minimum_size = Vector2(300, 142)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	col.add_child(UIKit.label("%s  %s" % [String(gem["shape"]), String(gem["name"])], 16, text_tint))
	col.add_child(UIKit.label("%s · %s" % [String(gem["label"]), _gem_value_text(gem)], 12, UIKit.MUTED_COLOR))
	col.add_child(UIKit.label("Cấp 1 trong túi: %d" % GameState.gem_count(gem_type, 1), 12, Color("a8b9c8")))
	var buy := UIKit.button("MUA 1 VIÊN · %d xu" % price, Color("67508b"), 13, Vector2(200, 38))
	buy.disabled = GameState.coins < price
	buy.pressed.connect(_buy_gem.bind(gem_type))
	col.add_child(buy)
	return card


func _buy_equipment(item_id: String) -> void:
	if not GameState.buy_equipment(item_id):
		_hint.text = "Không đủ xu để mua trang bị này."
		return
	_hint.text = "Đã mua %s. Mở mục Trang bị để lắp cho nhân vật." % GameData.EQUIPMENT[item_id]["name"]
	_refresh()


func _buy_gem(gem_type: String) -> void:
	if not GameState.buy_gem(gem_type):
		_hint.text = "Không đủ xu để mua viên ngọc này."
		return
	_hint.text = "Đã mua %s cấp 1." % GameData.GEMS[gem_type]["name"]
	_refresh()


func _stats_text(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for stat in ["hp", "atk", "mag", "def"]:
		if int(stats.get(stat, 0)) > 0:
			parts.append("%s +%d" % [String(stat).to_upper(), int(stats[stat])])
	return " · ".join(parts)


func _gem_value_text(gem: Dictionary) -> String:
	var stat: String = String(gem["stat"]).to_upper()
	if String(gem["stat"]) in ["crit", "crit_dmg"]:
		if String(gem["mode"]) == "flat":
			return "+%.1f điểm %% mỗi cấp" % (float(gem["per_level"]) * 100.0)
		return "+%.0f%% tương đối mỗi cấp" % (float(gem["per_level"]) * 100.0)
	if String(gem["mode"]) == "flat":
		return "+%d %s mỗi cấp" % [int(gem["per_level"]), stat]
	return "+%.1f%% %s mỗi cấp" % [float(gem["per_level"]) * 100.0, stat]
