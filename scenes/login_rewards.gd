extends Control
## Điểm danh tích lũy: nhận quà mỗi ngày đăng nhập, không cần liên tục. 30 ngày / vòng.

const COLUMNS := 10

var _grid: GridContainer
var _claim_btn: Button
var _summary: Label
var _sp_choice_select: OptionButton
var _sp_choice_btn: Button
var _sp_event_label: Label


func _ready() -> void:
	UIKit.add_background(self, 0.55)

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

	var top := HBoxContainer.new()
	col.add_child(top)
	var back := UIKit.button("< Sảnh", Color("4a4f63"), 20, Vector2(120, 48))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	top.add_child(back)
	var title := UIKit.label("ĐIỂM DANH TÍCH LŨY", 32, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
	top.add_child(CoinBar.new())

	_summary = UIKit.label("", 20, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(_summary)
	var choice_row := HBoxContainer.new()
	choice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	choice_row.add_theme_constant_override("separation", 10)
	_sp_event_label = UIKit.label("", 15, Color("e8d39c"))
	choice_row.add_child(_sp_event_label)
	_sp_choice_select = OptionButton.new()
	for id in GameData.SP_CHOICE_CHEST_IDS:
		_sp_choice_select.add_item(GameData.char_name(id))
		_sp_choice_select.set_item_metadata(_sp_choice_select.item_count - 1, id)
	choice_row.add_child(_sp_choice_select)
	_sp_choice_btn = UIKit.button("NHẬN RƯƠNG SP", Color("8a4fd8"), 15, Vector2(210, 42))
	_sp_choice_btn.pressed.connect(_claim_sp_choice)
	choice_row.add_child(_sp_choice_btn)
	col.add_child(choice_row)

	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(center)
	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	center.add_child(_grid)

	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(bottom)
	_claim_btn = UIKit.button("", Color("d9392b"), 26, Vector2(520, 70))
	_claim_btn.pressed.connect(_on_claim)
	bottom.add_child(_claim_btn)

	_refresh()


func _refresh() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()

	var claimed: int = GameState.login_claimed_in_cycle()
	var can_claim: bool = GameState.can_claim_login()
	var next_day: int = GameState.login_next_day()

	for day in range(1, GameData.LOGIN_CYCLE + 1):
		var state := "future"
		if day <= claimed:
			state = "claimed"
		elif day == next_day and can_claim:
			state = "today"
		_grid.add_child(_make_cell(day, state))

	_summary.text = "Tổng số ngày đã điểm danh: %d   |   Vòng hiện tại: %d/%d ngày" % [
		GameState.login_total, claimed, GameData.LOGIN_CYCLE]
	_sp_event_label.text = "Điểm danh sự kiện: %d/3 ngày liên tiếp" % mini(GameState.login_event_streak, 3)
	if GameState.sp_choice_claimed:
		_sp_choice_btn.text = "ĐÃ NHẬN RƯƠNG"
		_sp_choice_btn.disabled = true
	else:
		_sp_choice_btn.disabled = GameState.login_event_streak < 3
		_sp_choice_btn.text = "NHẬN RƯƠNG SP" if GameState.login_event_streak >= 3 else "CÒN %d NGÀY" % (3 - GameState.login_event_streak)

	if can_claim:
		_claim_btn.disabled = false
		_claim_btn.text = "NHẬN QUÀ NGÀY %d  (+%d coin)" % [next_day, GameData.login_reward_for_day(next_day)]
	else:
		_claim_btn.disabled = true
		_claim_btn.text = "Hôm nay đã nhận - quay lại vào ngày mai"


func _make_cell(day: int, state: String) -> Control:
	var amount: int = GameData.login_reward_for_day(day)
	var big: bool = amount >= 500

	var bg := Color(0.08, 0.10, 0.17, 0.92)
	var border := Color(1, 1, 1, 0.12)
	var bw := 2
	if big:
		bg = Color(0.20, 0.14, 0.05, 0.95)
		border = Color("ffc83d")
	if state == "claimed":
		bg = Color(0.05, 0.12, 0.08, 0.9)
		border = Color(0.3, 0.7, 0.4, 0.6)
	elif state == "today":
		border = Color("ffffff")
		bw = 4

	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(100, 112)
	cell.add_theme_stylebox_override("panel", UIKit.style(bg, 10, border, bw, 6.0))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	cell.add_child(v)
	v.add_child(UIKit.label("Ngày %d" % day, 16, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(24, 24)
	coin.add_theme_stylebox_override("panel", UIKit.style(Color("ffc83d"), 12, Color("b8860b"), 3, 0.0))
	var coin_row := HBoxContainer.new()
	coin_row.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_row.add_child(coin)
	v.add_child(coin_row)

	v.add_child(UIKit.label(str(amount), 24 if big else 20, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER))

	var status := ""
	var status_color := UIKit.MUTED_COLOR
	if state == "claimed":
		status = "Đã nhận"
		status_color = Color("5df08a")
	elif state == "today":
		status = "Hôm nay"
		status_color = Color.WHITE
	v.add_child(UIKit.label(status, 15, status_color, HORIZONTAL_ALIGNMENT_CENTER))

	if state == "claimed":
		cell.modulate = Color(1, 1, 1, 0.65)
	return cell


func _on_claim() -> void:
	var res: Dictionary = GameState.claim_login()
	if res.is_empty():
		UIKit.toast(self, "Hôm nay bạn đã nhận rồi")
		return
	UIKit.toast(self, "Nhận quà ngày %d: +%d coin" % [res["day"], res["coins"]])
	_refresh()


func _claim_sp_choice() -> void:
	if _sp_choice_select.item_count == 0:
		return
	var id: String = String(_sp_choice_select.get_item_metadata(_sp_choice_select.selected))
	if GameState.claim_sp_choice(id):
		UIKit.toast(self, "Rương tự chọn: %s" % GameData.char_name(id))
		_refresh()
	else:
		UIKit.toast(self, "Cần đủ 3 ngày điểm danh liên tiếp.")
