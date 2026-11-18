extends Control
## Màn hình triệu hồi nhân vật.

var _pity_label: Label
var _btn_1: Button
var _btn_10: Button
var _overlay: Control = null
var _busy: bool = false
var _skip: bool = false


func _ready() -> void:
	UIKit.add_background(self, 0.5)

	var root := MarginContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 24)
	root.add_theme_constant_override("margin_right", 24)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_bottom", 18)
	add_child(root)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	root.add_child(col)

	# --- thanh trên
	var top := HBoxContainer.new()
	col.add_child(top)
	var back := UIKit.button("< Sảnh", Color("4a4f63"), 20, Vector2(120, 48))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	top.add_child(back)
	var title := UIKit.label("TRIỆU HỒI NHÂN VẬT", 32, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(CoinBar.new())

	# --- phần giữa: danh sách nhân vật trong pool + bảng tỉ lệ
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 16)
	col.add_child(mid)

	var pool_panel := UIKit.panel()
	pool_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.add_child(pool_panel)
	pool_panel.add_child(_build_pool_view())

	var rate_panel := UIKit.panel()
	rate_panel.custom_minimum_size = Vector2(300, 0)
	mid.add_child(rate_panel)
	rate_panel.add_child(_build_rate_view())

	# --- nút triệu hồi
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 30)
	col.add_child(bottom)

	_btn_1 = UIKit.button("Triệu hồi x1\n%d coin" % GachaSystem.cost_for(1), Color("2f6fed"), 24, Vector2(280, 78))
	_btn_1.pressed.connect(_on_pull.bind(1))
	bottom.add_child(_btn_1)
	_btn_10 = UIKit.button("Triệu hồi x10\n%d coin" % GachaSystem.cost_for(10), Color("d9392b"), 24, Vector2(280, 78))
	_btn_10.pressed.connect(_on_pull.bind(10))
	bottom.add_child(_btn_10)

	_refresh_info()


func _build_pool_view() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UIKit.label("Nhân vật có thể nhận · kéo thanh ngang để xem hết", 21, UIKit.MUTED_COLOR))
	for tier in GameData.TIER_ORDER:
		var row := HBoxContainer.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.custom_minimum_size.y = 132
		row.add_theme_constant_override("separation", 6)
		var badge_box := VBoxContainer.new()
		badge_box.alignment = BoxContainer.ALIGNMENT_CENTER
		badge_box.custom_minimum_size.x = 70
		var badge := UIKit.tier_badge(tier, 22)
		badge.custom_minimum_size = Vector2(62, 34)
		badge_box.add_child(badge)
		row.add_child(badge_box)

		var scroll := ScrollContainer.new()
		scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		row.add_child(scroll)

		var strip := HBoxContainer.new()
		strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		strip.add_theme_constant_override("separation", 8)
		for id in GameData.ids_by_tier(tier):
			var cell := VBoxContainer.new()
			cell.custom_minimum_size.x = 122
			cell.alignment = BoxContainer.ALIGNMENT_END
			cell.add_child(UIKit.character_view(id, 92.0, Vector2(116, 96)))
			cell.add_child(UIKit.label(GameData.char_name(id), 15, UIKit.TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
			strip.add_child(cell)
		scroll.add_child(strip)
		col.add_child(row)
	return col

func _build_rate_view() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UIKit.label("Tỉ lệ", 22, UIKit.MUTED_COLOR))
	for tier in GameData.TIER_ORDER:
		var row := HBoxContainer.new()
		row.add_child(UIKit.tier_badge(tier, 18))
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(sp)
		row.add_child(UIKit.label("%s%%" % _fmt_pct(float(GameData.TIER_RATES[tier]) * 100.0), 20, UIKit.tier_color(tier)))
		col.add_child(row)
	col.add_child(HSeparator.new())
	_pity_label = UIKit.label("", 17, UIKit.TEXT_COLOR)
	_pity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_pity_label)
	var rules := UIKit.label("x10: đảm bảo ít nhất 1 nhân vật %s trở lên.\nTrùng nhân vật nhận 1 bản sao để dùng nâng sao (tối đa %d sao)." % [
		GameData.TEN_PULL_MIN_TIER, GameData.MAX_STARS], 15, UIKit.MUTED_COLOR)
	rules.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(rules)
	return col


static func _fmt_pct(v: float) -> String:
	return str(snappedf(v, 0.1))


func _refresh_info() -> void:
	_pity_label.text = "Bảo hiểm UR: còn %d lượt nữa chắc chắn ra UR.\nĐã triệu hồi: %d lượt." % [
		GachaSystem.pulls_until_pity(), GameState.total_pulls]


# ---------------------------------------------------------------- triệu hồi
func _on_pull(count: int) -> void:
	if _busy:
		return
	var cost := GachaSystem.cost_for(count)
	if GameState.coins < cost:
		UIKit.toast(self, "Không đủ coin (cần %d). Chiến đấu hoặc điểm danh để kiếm thêm!" % cost)
		return
	_busy = true
	var results := GachaSystem.pull(count)
	_refresh_info()
	await _show_results(results)
	_busy = false


func _show_results(results: Array) -> void:
	if results.is_empty():
		return
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP     # chặn click phía sau
	_overlay.z_index = 40
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.93)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(dim)

	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	_overlay.add_child(col)

	var per_row: int = 5 if results.size() > 1 else 1
	var grid := GridContainer.new()
	grid.columns = per_row
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	var grid_center := CenterContainer.new()
	grid_center.add_child(grid)
	col.add_child(grid_center)

	var cards: Array = []
	for r in results:
		var card := _make_result_card(r, results.size() == 1)
		card.modulate.a = 0.0
		grid.add_child(card)
		cards.append(card)

	var ok := UIKit.button("Xác nhận", Color("2f6fed"), 24, Vector2(220, 60))
	ok.visible = false
	var ok_row := HBoxContainer.new()
	ok_row.alignment = BoxContainer.ALIGNMENT_CENTER
	ok_row.add_child(ok)
	col.add_child(ok_row)

	_skip = false
	var skip_btn := UIKit.button("Bỏ qua", Color("4a4f63"), 18, Vector2(110, 44))
	skip_btn.pressed.connect(func(): _skip = true)
	skip_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_btn.offset_left = -130
	skip_btn.offset_top = -64
	skip_btn.offset_right = -20
	skip_btn.offset_bottom = -20
	_overlay.add_child(skip_btn)

	await get_tree().create_timer(0.25).timeout
	for i in range(cards.size()):
		var tier: String = results[i]["tier"]
		if not _skip and tier != "SSR":
			_flash(UIKit.tier_color(tier))
			await get_tree().create_timer(0.30).timeout
		cards[i].modulate.a = 1.0
		if not _skip:
			await get_tree().create_timer(0.22 if results.size() > 1 else 0.1).timeout

	skip_btn.queue_free()
	ok.visible = true
	await ok.pressed
	_overlay.queue_free()
	_overlay = null


func _flash(color: Color) -> void:
	var f := ColorRect.new()
	f.color = Color(color.r, color.g, color.b, 0.55)
	f.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func _make_result_card(r: Dictionary, big: bool) -> Control:
	var tier: String = r["tier"]
	var id: String = r["id"]
	var tcolor := UIKit.tier_color(tier)
	var card_size := Vector2(300, 400) if big else Vector2(190, 248)
	var body_h: float = 250.0 if big else 140.0

	var card := PanelContainer.new()
	card.custom_minimum_size = card_size
	card.add_theme_stylebox_override("panel", UIKit.style(Color(0.08, 0.10, 0.17, 1.0), 14, tcolor, 4, 8.0))

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)

	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(UIKit.tier_badge(tier, 22 if big else 16))
	col.add_child(head)

	col.add_child(UIKit.character_view(id, body_h, Vector2(card_size.x - 16, body_h + 12)))
	col.add_child(UIKit.label(GameData.char_name(id), 28 if big else 19, UIKit.TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	var note: String
	var note_color: Color = UIKit.MUTED_COLOR
	if r["is_new"]:
		note = "MỚI!"
		note_color = Color("5df08a")
	elif r.get("copy", false):
		note = "Bản sao +1  ·  tổng %d" % GameState.copies_of(id)
		note_color = Color("ffe08a")
	else:
		note = "Nhận nhân vật"
	col.add_child(UIKit.label(note, 22 if big else 15, note_color, HORIZONTAL_ALIGNMENT_CENTER))
	return card
