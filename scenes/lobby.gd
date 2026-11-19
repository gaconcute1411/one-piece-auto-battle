extends Control
## Sảnh chờ kiểu game mobile:
##   thẻ người chơi (trên trái) | tiền tệ + menu (trên phải) | cột chức năng (trái)
##   đội hình đứng giữa-phải    | hàng điều hướng (đáy)     | nút RA KHƠI (dưới phải)
## Thêm/bớt nút: sửa các mảng trong _build_top_right / _build_side_column / _build_bottom_nav.
## scene = "" nghĩa là tính năng chưa làm (bấm hiện "Sắp ra mắt").
## Muốn icon thật: thả PNG vào res://assets/icons/<key>.png, nút sẽ tự dùng thay cho chữ cái.

const ICON_DIR := "res://assets/icons/"
const AL_BEGIN := Control.SIZE_SHRINK_BEGIN
const AL_CENTER := Control.SIZE_SHRINK_CENTER
const AL_END := Control.SIZE_SHRINK_END


func _ready() -> void:
	GameState.pending_battle = {}      # rời trận -> xóa cấu hình trận cũ
	UIKit.add_background(self, 0.12)

	# Thứ tự thêm = thứ tự chồng lớp: đội hình nằm dưới cùng, nút bấm nằm trên.
	_place(_build_stage(), AL_CENTER, AL_END, 330, 0, 60, 118)
	_place(_build_player_card(), AL_BEGIN, AL_BEGIN, 16, 12, 0, 0)
	_place(_build_top_right(), AL_END, AL_BEGIN, 0, 12, 16, 0)
	_place(_build_side_column(), AL_BEGIN, AL_BEGIN, 16, 150, 0, 0)
	_place(_build_bottom_nav(), AL_BEGIN, AL_END, 16, 0, 0, 12)
	_place(_build_sail_button(), AL_END, AL_END, 0, 0, 16, 14)

	# Lần đầu vào sảnh trong phiên mà còn quà chưa nhận -> mở màn điểm danh
	if GameState.can_claim_login() and not GameState.login_popup_shown:
		GameState.login_popup_shown = true
		await get_tree().create_timer(0.6).timeout
		if is_inside_tree():
			SceneManager.change_scene(GameData.SCENE_LOGIN)


## Đặt `child` vào một lớp phủ kín màn hình, canh theo h/v (AL_BEGIN/AL_CENTER/AL_END) với lề cho trước.
## Lớp phủ để mouse_filter = IGNORE nên không chặn click vào các lớp bên dưới.
func _place(child: Control, h: int, v: int, ml: int, mt: int, mr: int, mb: int) -> void:
	var layer := MarginContainer.new()
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_theme_constant_override("margin_left", ml)
	layer.add_theme_constant_override("margin_top", mt)
	layer.add_theme_constant_override("margin_right", mr)
	layer.add_theme_constant_override("margin_bottom", mb)
	child.size_flags_horizontal = h
	child.size_flags_vertical = v
	layer.add_child(child)
	add_child(layer)


# ---------------------------------------------------------------- thẻ người chơi
func _build_player_card() -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.style(Color(0.05, 0.07, 0.12, 0.82), 18, Color("ffc83d"), 2, 10.0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	# Avatar: chưa có ảnh đại diện nên dùng chữ cái đầu của nhân vật đầu đội
	var leader: String = GameState.team[0] if GameState.team.size() > 0 else ""
	var ring: Color = UIKit.tier_color(GameData.char_tier(leader)) if leader != "" else Color("ffc83d")
	var avatar := Panel.new()
	avatar.custom_minimum_size = Vector2(78, 78)
	avatar.add_theme_stylebox_override("panel", UIKit.style(Color(0.12, 0.15, 0.25), 39, ring, 4, 0.0))
	if leader != "":
		var initial := UIKit.label(GameData.char_name(leader).substr(0, 1), 42, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		initial.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		initial.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		avatar.add_child(initial)
	row.add_child(avatar)

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	info.add_child(UIKit.label(GameState.player_name, 26))
	info.add_child(UIKit.label("Sưu tầm nhân vật  %d/%d" % [GameState.owned.size(), GameData.CHARACTERS.size()], 15, UIKit.MUTED_COLOR))

	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = GameData.CHARACTERS.size()
	progress.value = GameState.owned.size()
	progress.show_percentage = false
	progress.custom_minimum_size = Vector2(230, 14)
	progress.add_theme_stylebox_override("background", UIKit.style(Color(0, 0, 0, 0.55), 7, Color(1, 1, 1, 0.25), 1, 0.0))
	progress.add_theme_stylebox_override("fill", UIKit.style(Color("ffc83d"), 7, Color(0, 0, 0, 0), 0, 0.0))
	info.add_child(progress)
	info.add_child(UIKit.label("Hải trình 1-%02d  ·  Thắng %d trận" % [mini(GameState.campaign_stage, 10), GameState.total_wins], 14, UIKit.MUTED_COLOR))
	return panel


# ---------------------------------------------------------------- trên phải
func _build_top_right() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)

	var coin := CoinBar.new()
	coin.size_flags_horizontal = AL_END
	col.add_child(coin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = AL_END
	col.add_child(row)

	var items := [
		{"key": "login", "label": "Điểm danh", "color": Color("c98a1b"), "scene": GameData.SCENE_LOGIN, "dot": GameState.can_claim_login() or GameState.can_claim_sp_choice()},
		{"key": "quest", "label": "Nhiệm vụ", "color": Color("2f6fed"), "scene": GameData.SCENE_ACTIVITIES},
		{"key": "events", "label": "Sự kiện", "color": Color("8a4fd8"), "scene": GameData.SCENE_EVENTS, "dot": GameState.has_claimable_spend_event() or GameState.can_claim_sp_choice() or GameState.can_claim_login()},
	]
	for it in items:
		row.add_child(_icon_button(it))
	return col


# ---------------------------------------------------------------- cột trái
func _build_side_column() -> Control:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	var items := [
		{"key": "training", "label": "Huấn luyện", "color": Color("bd7b34"), "scene": GameData.SCENE_TRAINING},
		{"key": "rank", "label": "Xếp hạng", "color": Color("b8402f"), "scene": ""},
		{"key": "news", "label": "Tin tức", "color": Color("2f8f9d"), "scene": ""},
		{"key": "shop", "label": "Cửa hàng", "color": Color("3c8d5a"), "scene": GameData.SCENE_SHOP},
	]
	for it in items:
		col.add_child(_icon_button(it))
	return col


# ---------------------------------------------------------------- hàng đáy
func _build_bottom_nav() -> Control:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UIKit.style(Color(0.04, 0.05, 0.09, 0.80), 18, Color(1, 1, 1, 0.12), 2, 8.0))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	bar.add_child(row)

	var items := [
		{"key": "formation", "label": "Đội hình", "color": Color("3c8d5a"), "scene": GameData.SCENE_FORMATION},
		{"key": "pet", "label": "Thú cưng", "color": Color("347f9a"), "scene": GameData.SCENE_PETS},
		{"key": "summon", "label": "Triệu hồi", "color": Color("8a4fd8"), "scene": GameData.SCENE_GACHA},
		{"key": "equipment", "label": "Trang bị", "color": Color("b07a2a"), "scene": GameData.SCENE_EQUIPMENT},
		{"key": "friends", "label": "Bạn bè", "color": Color("d0607a"), "scene": ""},
		{"key": "guild", "label": "Bang hội", "color": Color("2f6fed"), "scene": ""},
		{"key": "mail", "label": "Thư", "color": Color("9a7b5a"), "scene": ""},
		{"key": "exit", "label": "Thoát", "color": Color("4a4f63"), "scene": GameData.SCENE_TITLE},
	]
	for it in items:
		row.add_child(_icon_button(it))
	return bar


# ---------------------------------------------------------------- RA KHƠI
func _build_sail_button() -> Control:
	var btn := UIKit.button("RA KHƠI", Color("d9392b"), 36, Vector2(230, 100))
	btn.add_theme_stylebox_override("normal", UIKit.style(Color("d9392b"), 20, Color("ffd36a"), 4))
	btn.add_theme_stylebox_override("hover", UIKit.style(Color("ec4a3b"), 20, Color("ffd36a"), 4))
	btn.add_theme_stylebox_override("pressed", UIKit.style(Color("a82a1f"), 20, Color("ffd36a"), 4))
	btn.pressed.connect(func(): GameState.open_activities())
	return btn


# ---------------------------------------------------------------- đội hình đứng trên bến
func _build_stage() -> Control:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", -8)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var i := 0
	for id in GameState.team.slice(0, 6):
		var col := VBoxContainer.new()
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_theme_constant_override("separation", 2)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE

		# Thẻ tên phía trên đầu: [bậc] Tên
		var tag := HBoxContainer.new()
		tag.alignment = BoxContainer.ALIGNMENT_CENTER
		tag.add_theme_constant_override("separation", 6)
		tag.add_child(UIKit.tier_badge(GameData.char_tier(id), 14))
		tag.add_child(UIKit.label(GameData.char_name(id), 15))
		col.add_child(tag)

		col.add_child(UIKit.character_view(id, 125.0, Vector2(125, 135)))

		# Nhân vật xen kẽ cao/thấp một chút
		var lift := Control.new()
		lift.custom_minimum_size = Vector2(0, 0 if i % 2 == 0 else 8)
		lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(lift)

		grid.add_child(col)
		i += 1
	return grid


# ---------------------------------------------------------------- nút tròn dùng chung
## it: {key, label, color, scene, dot?}
func _icon_button(it: Dictionary) -> Control:
	var scene: String = it["scene"]
	var locked: bool = scene == ""
	var base: Color = it["color"]
	if locked:
		base = base.darkened(0.45)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(68, 68)
	btn.focus_mode = Control.FOCUS_NONE
	var rim := Color("fff2c2") if not locked else Color(1, 1, 1, 0.35)
	btn.add_theme_stylebox_override("normal", UIKit.style(base, 34, rim, 3, 0.0))
	btn.add_theme_stylebox_override("hover", UIKit.style(base.lightened(0.15), 34, rim, 3, 0.0))
	btn.add_theme_stylebox_override("pressed", UIKit.style(base.darkened(0.2), 34, rim, 3, 0.0))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var icon_path: String = ICON_DIR + String(it["key"]) + ".png"
	if ResourceLoader.exists(icon_path):
		btn.icon = load(icon_path)
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		btn.text = String(it["label"]).substr(0, 1).to_upper()
		btn.add_theme_font_size_override("font_size", 30)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.pressed.connect(_on_item_pressed.bind(scene))
	col.add_child(btn)

	if it.get("dot", false):
		var dot := Panel.new()
		dot.add_theme_stylebox_override("panel", UIKit.style(Color("ff3b30"), 9, Color.WHITE, 2, 0.0))
		dot.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
		dot.offset_left = -22
		dot.offset_right = -4
		dot.offset_top = 4
		dot.offset_bottom = 22
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(dot)

	var name_label := UIKit.label(String(it["label"]), 15, UIKit.TEXT_COLOR if not locked else UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(name_label)
	return col


func _on_item_pressed(scene: String) -> void:
	if scene == "":
		UIKit.toast(self, "Tính năng này sắp ra mắt")
		return
	SceneManager.change_scene(scene)



