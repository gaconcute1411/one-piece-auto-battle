extends Control
## Event hub with horizontal fixed-size tabs and one detail view at a time.

const GOLD := Color("ffd36a")

var _selected_event: String = ""
var _tabs: Dictionary = {}
var _details: VBoxContainer
var _sp_choice_select: OptionButton


func _ready() -> void:
	UIKit.add_background(self, 0.56)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	root.add_child(_header())
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 12)
	tabs.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tabs.add_child(_make_tab("login", "Điểm danh 3 ngày"))
	tabs.add_child(_make_tab("spend", "Tích tiêu xu"))
	root.add_child(tabs)
	var detail_scroll := ScrollContainer.new()
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(detail_scroll)
	_details = VBoxContainer.new()
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override("separation", 10)
	detail_scroll.add_child(_details)
	_refresh_detail()


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var back := UIKit.button("‹ Sảnh", Color("3c465c"), 18, Vector2(120, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(back)
	var title := UIKit.label("SỰ KIỆN", 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	return row


func _make_tab(key: String, title: String) -> Button:
	var button := UIKit.button(title, Color("493b70"), 17, Vector2(220, 64))
	button.pressed.connect(_select_event.bind(key))
	_tabs[key] = button
	return button


func _select_event(key: String) -> void:
	_selected_event = key
	_refresh_detail()


func _refresh_detail() -> void:
	for child in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	for key in _tabs:
		var tab: Button = _tabs[key]
		var color := Color("9a6ae0") if key == _selected_event else Color("493b70")
		tab.add_theme_stylebox_override("normal", UIKit.style(color, 10, Color("d8c6ff") if key == _selected_event else Color(1, 1, 1, 0.15), 2))
		tab.add_theme_stylebox_override("hover", UIKit.style(color.lightened(0.12), 10, Color("d8c6ff"), 2))
		tab.add_theme_stylebox_override("pressed", UIKit.style(color.darkened(0.12), 10, Color("d8c6ff"), 2))
	if _selected_event == "login":
		_build_login_detail()
	elif _selected_event == "spend":
		_build_spend_detail()



func _detail_card() -> VBoxContainer:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 18, Color("8163cf"), 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	panel.add_child(content)
	return content


func _build_login_detail() -> void:
	var content := _detail_card()
	content.add_child(UIKit.label("ĐIỂM DANH 3 NGÀY LIÊN TIẾP", 24, Color("c7a6ff")))
	content.add_child(UIKit.label("Điểm danh mỗi ngày trong 3 ngày liên tiếp để nhận rương SP tự chọn.", 16, UIKit.MUTED_COLOR))
	content.add_child(UIKit.label("Tiến độ: %d/3 ngày liên tiếp" % mini(GameState.login_event_streak, 3), 18, Color("e8d39c")))
	var claim_login := UIKit.button("NHẬN ĐIỂM DANH HÔM NAY", Color("9a6ae0"), 16, Vector2(300, 48))
	claim_login.disabled = not GameState.can_claim_login()
	if not GameState.can_claim_login():
		claim_login.text = "ĐÃ ĐIỂM DANH HÔM NAY"
	claim_login.pressed.connect(_claim_daily_login)
	content.add_child(claim_login)
	content.add_child(HSeparator.new())
	content.add_child(UIKit.label("Rương SP tự chọn · Teach · Shirahoshi · Magellan · Enel · Aokiji", 16, Color("ffe08a")))
	var choice_row := HBoxContainer.new()
	choice_row.add_theme_constant_override("separation", 10)
	_sp_choice_select = OptionButton.new()
	_sp_choice_select.custom_minimum_size.x = 280
	for id in GameData.SP_CHOICE_CHEST_IDS:
		_sp_choice_select.add_item(GameData.char_name(id))
		_sp_choice_select.set_item_metadata(_sp_choice_select.item_count - 1, id)
	choice_row.add_child(_sp_choice_select)
	var claim_chest := UIKit.button("NHẬN RƯƠNG SP", Color("8a4fd8"), 16, Vector2(220, 48))
	claim_chest.disabled = not GameState.can_claim_sp_choice()
	if GameState.sp_choice_claimed:
		claim_chest.text = "ĐÃ NHẬN RƯƠNG"
	claim_chest.pressed.connect(_claim_sp_choice)
	choice_row.add_child(claim_chest)
	content.add_child(choice_row)


func _claim_daily_login() -> void:
	var result: Dictionary = GameState.claim_login()
	if result.is_empty():
		UIKit.toast(self, "Hôm nay bạn đã điểm danh rồi.")
	else:
		UIKit.toast(self, "Đã điểm danh · tiến độ sự kiện %d/3 ngày." % mini(GameState.login_event_streak, 3))
	_refresh_detail()


func _claim_sp_choice() -> void:
	if _sp_choice_select == null or _sp_choice_select.item_count == 0:
		return
	var id := String(_sp_choice_select.get_item_metadata(_sp_choice_select.selected))
	if GameState.claim_sp_choice(id):
		UIKit.toast(self, "Đã nhận rương: %s." % GameData.char_name(id))
	else:
		UIKit.toast(self, "Cần điểm danh đủ 3 ngày liên tiếp.")
	_refresh_detail()


func _build_spend_detail() -> void:
	var content := _detail_card()
	content.add_child(UIKit.label("TÍCH TIÊU XU", 24, Color("ffe08a")))
	content.add_child(UIKit.label("Tổng xu đã tiêu: %d" % GameState.spend_event_total, 18, UIKit.MUTED_COLOR))
	content.add_child(UIKit.label("Đạt mốc để nhận mảnh UR ngẫu nhiên. Mỗi mốc nhận một lần.", 15, UIKit.MUTED_COLOR))
	content.add_child(HSeparator.new())
	for milestone in GameData.SPEND_EVENT_MILESTONES:
		_add_spend_milestone(content, int(milestone["threshold"]), int(milestone["shards"]))


func _add_spend_milestone(parent: VBoxContainer, threshold: int, shards: int) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var claimed := bool(GameState.spend_event_claimed.get(str(threshold), false))
	var status := "ĐÃ NHẬN" if claimed else ("ĐỦ ĐIỀU KIỆN" if GameState.spend_event_total >= threshold else "CÒN %d XU" % (threshold - GameState.spend_event_total))
	var label := UIKit.label("Mốc %d xu · %d mảnh UR · %s" % [threshold, shards, status], 16, UIKit.TEXT_COLOR)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var button := UIKit.button("ĐÃ NHẬN" if claimed else "NHẬN", Color("8a4fd8"), 14, Vector2(130, 42))
	button.disabled = claimed or GameState.spend_event_total < threshold
	button.pressed.connect(_claim_spend_milestone.bind(threshold))
	row.add_child(button)
	parent.add_child(row)


func _claim_spend_milestone(threshold: int) -> void:
	var id := GameState.claim_spend_event_milestone(threshold)
	if id.is_empty():
		UIKit.toast(self, "Chưa đạt mốc tiêu xu này.")
		return
	var amount := 0
	for milestone in GameData.SPEND_EVENT_MILESTONES:
		if int(milestone["threshold"]) == threshold:
			amount = int(milestone["shards"])
			break
	UIKit.toast(self, "Nhận %d mảnh UR của %s." % [amount, GameData.char_name(id)])
	_refresh_detail()




