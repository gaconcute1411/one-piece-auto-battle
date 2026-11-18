extends Control
## Hub for campaign stages, repeatable activities, and claimable daily missions.

const GOLD := Color("ffd36a")

func _ready() -> void:
	UIKit.add_background(self, 0.58)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 18
	root.offset_bottom = -18
	root.add_theme_constant_override("separation", 12)
	add_child(root)
	root.add_child(_header())
	root.add_child(UIKit.label("Chọn hành trình, chiến thắng để mở ải mới và nhận thêm vàng.", 17, UIKit.MUTED_COLOR))
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	root.add_child(content)
	content.add_child(_campaign_panel())
	content.add_child(_activities_panel())
	content.add_child(_quests_panel())


func _header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var back := UIKit.button("‹ Sảnh", Color("3c465c"), 18, Vector2(120, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	row.add_child(back)
	var title := UIKit.label("HẢI TRÌNH & HOẠT ĐỘNG", 30, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	return row


func _campaign_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.93), 16, Color("e8b95f"), 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UIKit.label("CHƯƠNG 1 · BIỂN ĐÔNG", 22, GOLD))
	col.add_child(UIKit.label("Vượt ải liên tiếp để mở khóa hải trình.", 14, UIKit.MUTED_COLOR))
	var progress := ProgressBar.new()
	progress.min_value = 0
	progress.max_value = 10
	progress.value = clampi(GameState.campaign_stage - 1, 0, 10)
	progress.show_percentage = false
	progress.custom_minimum_size.y = 12
	col.add_child(progress)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	col.add_child(grid)
	for stage in range(1, 11):
		var unlocked: bool = stage <= GameState.campaign_stage
		var button := UIKit.button("ẢI %02d\n%s" % [stage, "ĐÃ MỞ" if unlocked else "KHÓA"], Color("315f9d") if unlocked else Color("34394a"), 16, Vector2(128, 66))
		button.disabled = not unlocked or not _team_ready()
		button.pressed.connect(_launch.bind("campaign", stage))
		grid.add_child(button)
	var info := UIKit.label("Đội hình: %d/6\nKẻ địch tăng sức mạnh theo từng ải." % GameState.team.size(), 15, Color("aebbd0"))
	col.add_child(info)
	return panel


func _activities_panel() -> Control:
	var panel := UIKit.panel(Color(0.06, 0.08, 0.14, 0.93), 16, Color("8163cf"), 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	col.add_child(UIKit.label("HOẠT ĐỘNG", 22, Color("c7a6ff")))
	col.add_child(UIKit.label("Các trận thử thách và thủ lĩnh.", 14, UIKit.MUTED_COLOR))
	col.add_child(UIKit.label("Thử thách\nĐội địch cân bằng · thưởng 160 coin", 16))
	var trial := UIKit.button("VÀO THỬ THÁCH", Color("6849ac"), 18, Vector2(250, 54))
	trial.disabled = not _team_ready()
	trial.pressed.connect(_launch.bind("trial", 1))
	col.add_child(trial)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(gap)
	col.add_child(UIKit.label("Đại chiến thủ lĩnh\nKaido dẫn đầu · kẻ địch mạnh hơn\nThưởng 260 coin", 16, Color("f2d5a5")))
	var boss := UIKit.button("THÁCH ĐẤU KAIDO", Color("a83d39"), 18, Vector2(250, 54))
	boss.disabled = not _team_ready() or GameState.campaign_stage < 3
	boss.pressed.connect(_launch.bind("boss", GameState.campaign_stage))
	col.add_child(boss)
	if GameState.campaign_stage < 3:
		col.add_child(UIKit.label("Mở sau khi vượt ải 1-2.", 14, UIKit.MUTED_COLOR))
	return panel


func _quests_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.13, 0.93), 16, Color("55bca4"), 2)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	panel.add_child(col)
	col.add_child(UIKit.label("NHIỆM VỤ", 22, Color("75e2c7")))
	col.add_child(UIKit.label("Thắng trận để lấy coin thưởng.", 14, UIKit.MUTED_COLOR))
	_add_quest(col, "daily_1", "Thắng 1 trận hôm nay", GameState.daily_wins, 1, 80)
	_add_quest(col, "daily_3", "Thắng 3 trận hôm nay", GameState.daily_wins, 3, 200)
	_add_quest(col, "career_5", "Thắng 5 trận tổng cộng", GameState.total_wins, 5, 300)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	return panel


func _add_quest(parent: VBoxContainer, id: String, title: String, progress: int, target: int, reward: int) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.add_child(UIKit.label(title, 15))
	row.add_child(UIKit.label("Tiến độ %d/%d · Thưởng %d coin" % [mini(progress, target), target, reward], 13, UIKit.MUTED_COLOR))
	var claimed: bool = bool(GameState.quest_claimed.get(id, false))
	var button := UIKit.button("ĐÃ NHẬN" if claimed else ("NHẬN THƯỞNG" if progress >= target else "CHƯA HOÀN THÀNH"), Color("2f8d75") if progress >= target and not claimed else Color("374252"), 14, Vector2(220, 38))
	button.disabled = claimed or progress < target
	button.pressed.connect(_claim.bind(id, target, reward))
	row.add_child(button)
	parent.add_child(row)


func _claim(id: String, target: int, reward: int) -> void:
	if GameState.claim_quest(id, target, reward):
		UIKit.toast(self, "Đã nhận %d coin" % reward)
		SceneManager.change_scene(GameData.SCENE_ACTIVITIES)


func _launch(mode: String, stage: int) -> void:
	if not _team_ready():
		UIKit.toast(self, "Hãy chọn đủ 6 nhân vật trong mục Đội hình.")
		return
	GameState.begin_battle(mode, stage)


func _team_ready() -> bool:
	return GameState.team.size() == GameData.TEAM_SIZE_MAX


