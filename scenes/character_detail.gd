extends Control
## Character profile demo: fixed star bonuses, team assignment, and four gear slots.

const GOLD := Color("ffd36a")
var character_id: String
var team_button: Button
var skill_profiles: Dictionary = {}


func _ready() -> void:
	character_id = GameState.selected_character
	var parsed_profiles = JSON.parse_string(FileAccess.get_file_as_string("res://data/character_skills_v2.json"))
	if parsed_profiles is Dictionary:
		skill_profiles = parsed_profiles
	if not GameState.owned.has(character_id):
		character_id = GameState.STARTER_TEAM[0]
		GameState.selected_character = character_id
	UIKit.add_background(self, 0.57)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 24
	root.offset_right = -24
	root.offset_top = 16
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 10)
	add_child(root)
	root.add_child(_header())
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)
	body.add_child(_portrait_panel())
	var right_scroll := ScrollContainer.new()
	right_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(right_scroll)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	right_scroll.add_child(right)
	right.add_child(_stats_panel())
	right.add_child(_star_panel())
	right.add_child(_equipment_panel())
	right.add_child(_treasure_panel())
	right.add_child(_gem_panel())
	right.add_child(_skill_panel())


func _header() -> Control:
	var row := HBoxContainer.new()
	var back := UIKit.button("‹ Nhân vật", Color("3c465c"), 18, Vector2(145, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_ROSTER))
	row.add_child(back)
	var title := UIKit.label("HỒ SƠ NHÂN VẬT", 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	return row


func _portrait_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 16, UIKit.tier_color(GameData.char_tier(character_id)), 2)
	panel.custom_minimum_size = Vector2(330, 0)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UIKit.tier_badge(GameData.char_tier(character_id), 18))
	col.add_child(UIKit.character_view(character_id, 255.0, Vector2(290, 290)))
	col.add_child(UIKit.label(GameData.char_name(character_id), 30, UIKit.TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label(String(GameData.CHARACTERS[character_id]["role"]), 15, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	team_button = UIKit.button("", Color("367d62"), 17, Vector2(270, 48))
	team_button.pressed.connect(_toggle_team)
	col.add_child(team_button)
	var pet_button := UIKit.button("THÚ CƯNG ĐỘI", Color("7250a7"), 16, Vector2(270, 44))
	pet_button.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_PETS))
	col.add_child(pet_button)
	var equipment_button := UIKit.button("KHO TRANG BỊ", Color("397b52"), 16, Vector2(270, 44))
	equipment_button.pressed.connect(_open_equipment)
	col.add_child(equipment_button)
	_refresh_team_button()
	return panel


func _open_equipment() -> void:
	GameState.selected_character = character_id
	SceneManager.change_scene(GameData.SCENE_EQUIPMENT)


func _refresh_team_button() -> void:
	if team_button:
		team_button.text = "BỎ KHỎI ĐỘI" if GameState.team.has(character_id) else "ĐƯA VÀO ĐỘI"
		team_button.disabled = not GameState.team.has(character_id) and GameState.team.size() >= GameData.TEAM_SIZE_MAX


func _toggle_team() -> void:
	if not GameState.toggle_team_member(character_id):
		UIKit.toast(self, "Đội đã đủ 6 người hoặc cần giữ ít nhất 1 nhân vật.")
		return
	_refresh_team_button()


func _stats_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 14, Color("46698f"), 2)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	panel.add_child(col)
	col.add_child(UIKit.label("CHỈ SỐ CHIẾN ĐẤU", 20, Color("a9d4ff")))
	var base: Dictionary = GameData.BASE_STATS[character_id]
	var bonus: Dictionary = GameState.character_flat_bonus(character_id)
	var stars := GameState.stars_of(character_id)
	var source_bonus: Dictionary = GameData.star_bonus(stars)
	var percent_bonus: Dictionary = GameState.character_percent_bonus(character_id)
	var support_bonus: Dictionary = GameState.support_team_bonus() if GameState.team.has(character_id) else {"hp": 0, "atk": 0, "mag": 0, "def": 0}
	var gear_pet_bonus: Dictionary = {}
	for stat in ["hp", "atk", "mag", "def"]:
		gear_pet_bonus[stat] = int(bonus[stat]) - int(source_bonus[stat])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	for stat in ["hp", "atk", "mag", "def"]:
		var col_stat := VBoxContainer.new()
		col_stat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col_stat.add_child(UIKit.label(_stat_name(stat), 13, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
		var after_percent: int = int(round((float(base[stat]) + float(bonus[stat])) * (1.0 + float(percent_bonus[stat]))))
		var final_value: int = after_percent + int(support_bonus[stat])
		col_stat.add_child(UIKit.label(_fmt(final_value), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
		col_stat.add_child(UIKit.label("+%d cố định · +%.1f%%" % [int(gear_pet_bonus[stat]), float(percent_bonus[stat]) * 100.0], 11, Color("86d8bf"), HORIZONTAL_ALIGNMENT_CENTER))
		if int(support_bonus[stat]) > 0:
			col_stat.add_child(UIKit.label("+%d đội cổ vũ" % int(support_bonus[stat]), 10, Color("d4c1ff"), HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(col_stat)
	col.add_child(row)
	var secondary: Dictionary = GameData.SECONDARY_STATS[character_id]
	var gem_secondary: Dictionary = GameState.character_secondary_flat_bonus(character_id)
	var gem_percent: Dictionary = GameState.character_percent_bonus(character_id)
	var total_crit: float = (float(secondary["crit"]) * (1.0 + float(gem_percent["crit"]))) + float(gem_secondary["crit"])
	var total_crit_dmg: float = (float(secondary["crit_dmg"]) * (1.0 + float(gem_percent["crit_dmg"]))) + float(gem_secondary["crit_dmg"])
	col.add_child(UIKit.label("Tốc độ %d   ·   Crit %.1f%% / %.1f%%   ·   Chính xác %.0f%%   ·   Né %.0f%%   ·   Kháng hiệu ứng %.0f%%" % [int(secondary["spd"]), total_crit * 100.0, total_crit_dmg * 100.0, float(secondary["accuracy"]) * 100.0, float(secondary["evasion"]) * 100.0, float(secondary["effect_res"]) * 100.0], 14, Color("e8d39c"), HORIZONTAL_ALIGNMENT_CENTER))
	var skill_names: Array = GameData.SKILL_NAMES.get(character_id, [])
	if not skill_names.is_empty():
		var skill_label := UIKit.label("Chiêu thức: %s" % " · ".join(skill_names), 12, UIKit.MUTED_COLOR)
		skill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(skill_label)
	return panel


func _star_panel() -> Control:
	var panel := UIKit.panel(Color(0.08, 0.07, 0.11, 0.95), 14, Color("bd8d3b"), 2)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	var current: int = GameState.stars_of(character_id)
	col.add_child(UIKit.label("NÂNG SAO · %d/%d" % [current, GameData.MAX_STARS], 20, GOLD))
	col.add_child(UIKit.label("Dùng bản sao của chính nhân vật để nâng sao. Mỗi bậc cộng chỉ số cố định.", 13, UIKit.MUTED_COLOR))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 2)
	for label_text in ["Sao", "HP", "ATK", "MAG", "DEF"]:
		grid.add_child(UIKit.label(label_text, 12, Color("d3c7ae"), HORIZONTAL_ALIGNMENT_CENTER))
	for star in range(1, GameData.MAX_STARS + 1):
		var values: Dictionary = GameData.star_bonus(star)
		var tint: Color = GOLD if star == current else UIKit.MUTED_COLOR
		grid.add_child(UIKit.label("%d★" % star, 13, tint, HORIZONTAL_ALIGNMENT_CENTER))
		for stat in ["hp", "atk", "mag", "def"]:
			grid.add_child(UIKit.label("+%s" % _fmt(int(values[stat])), 12, tint, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(grid)
	var next_star: int = current + 1
	var next_cost: int = int(GameData.STAR_COPY_COST.get(next_star, 0))
	col.add_child(UIKit.label("Bản sao hiện có: %d" % GameState.copies_of(character_id), 14, Color("e8d39c")))
	var upgrade_text := "TỐI ĐA 15 SAO" if current >= GameData.MAX_STARS else "NÂNG LÊN %d SAO · %d bản sao" % [next_star, next_cost]
	var upgrade := UIKit.button(upgrade_text, Color("9b7028"), 15, Vector2(300, 42))
	upgrade.disabled = current >= GameData.MAX_STARS
	if current < GameData.MAX_STARS and GameState.copies_of(character_id) < next_cost:
		upgrade.disabled = true
	upgrade.pressed.connect(_upgrade_star)
	col.add_child(upgrade)
	return panel


func _upgrade_star() -> void:
	var old_stars: int = GameState.stars_of(character_id)
	if old_stars >= GameData.MAX_STARS:
		UIKit.toast(self, "Nhân vật đã đạt tối đa 15 sao.")
		return
	if not GameState.raise_character_star(character_id):
		var cost: int = int(GameData.STAR_COPY_COST.get(old_stars + 1, 0))
		UIKit.toast(self, "Chưa đủ bản sao của %s · cần %d." % [GameData.char_name(character_id), cost])
		return
	await _show_star_up_transition(old_stars, GameState.stars_of(character_id))
	SceneManager.change_scene(GameData.SCENE_CHARACTER)


func _show_star_up_transition(old_stars: int, new_stars: int) -> void:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.04, 0.03, 0.08, 0.0)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var stack := VBoxContainer.new()
	stack.alignment = BoxContainer.ALIGNMENT_CENTER
	stack.add_theme_constant_override("separation", 18)
	center.add_child(stack)
	var title := UIKit.label("THỨC TỈNH SỨC MẠNH", 34, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(title)
	var stars_label := UIKit.label("★ %d  →  ★ %d" % [old_stars, new_stars], 48, Color("fff1a8"), HORIZONTAL_ALIGNMENT_CENTER)
	stack.add_child(stars_label)
	var continue_button := UIKit.button("TIẾP TỤC", Color("9b7028"), 20, Vector2(260, 58))
	continue_button.disabled = true
	
	stack.add_child(continue_button)
	var tween := create_tween()
	tween.tween_property(dim, "color:a", 0.86, 0.25)
	stars_label.scale = Vector2(0.65, 0.65)
	tween.parallel().tween_property(stars_label, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.8).timeout
	continue_button.disabled = false
	await continue_button.pressed
	overlay.queue_free()


func _equipment_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 14, Color("65749a"), 2)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	panel.add_child(col)
	col.add_child(UIKit.label("TRANG BỊ", 20, Color("c3d1ff")))
	var equipped: Dictionary = GameState.equipment.get(character_id, {})
	for slot in GameData.EQUIPMENT_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var slot_label := UIKit.label(slot, 14, UIKit.MUTED_COLOR)
		slot_label.custom_minimum_size.x = 88
		row.add_child(slot_label)
		var options: Array = [""]
		var select := OptionButton.new()
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.add_item("Trống · chọn vật phẩm")
		select.set_item_metadata(0, "")
		select.select(0)
		for item_id in GameData.equipment_ids_for_slot(slot):
			if GameState.equipment_count(item_id) <= 0:
				continue
			options.append(item_id)
			var item: Dictionary = GameData.EQUIPMENT[item_id]
			select.add_item("%s · túi %d · %s" % [item["name"], GameState.equipment_count(item_id), _gear_summary(item["stats"])])
			select.set_item_metadata(select.item_count - 1, item_id)
		var selected_id: String = String(equipped.get(slot, ""))
		for i in range(select.item_count):
			if String(select.get_item_metadata(i)) == selected_id:
				select.select(i)
				break
		select.item_selected.connect(_on_equipment_selected.bind(character_id, slot, options))
		row.add_child(select)
		col.add_child(row)
	return panel


func _treasure_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 14, Color("c99c55"), 2)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)
	col.add_child(UIKit.label("BẢO VẬT", 20, Color("f0d08a")))
	var equipped: Dictionary = GameState.treasures.get(character_id, {})
	for slot in GameData.TREASURE_SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var slot_label := UIKit.label(slot, 14, UIKit.MUTED_COLOR)
		slot_label.custom_minimum_size.x = 88
		row.add_child(slot_label)
		var select := OptionButton.new()
		select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		select.add_item("Trống · chọn bảo vật")
		select.set_item_metadata(0, "")
		for treasure_id in GameData.TREASURES:
			var treasure: Dictionary = GameData.TREASURES[treasure_id]
			select.add_item("%s · %s" % [treasure["name"], _gear_summary(treasure["stats"])])
			select.set_item_metadata(select.item_count - 1, treasure_id)
		var selected: String = String(equipped.get(slot, ""))
		for index in range(select.item_count):
			if String(select.get_item_metadata(index)) == selected:
				select.select(index)
				break
		select.item_selected.connect(_on_treasure_selected.bind(character_id, slot, select))
		row.add_child(select)
		col.add_child(row)
	return panel


func _gem_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 14, Color("55bca4"), 2)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 7)
	panel.add_child(col)
	col.add_child(UIKit.label("NGỌC · 10 CẤP · 2 NHÓM CHỈ SỐ", 20, Color("75e2c7")))
	var description := UIKit.label("Pha lê: cộng cố định. Lục giác: cộng theo phần trăm. Ghép 3 viên cùng loại cấp thấp thành 1 viên cấp kế tiếp.", 12, UIKit.MUTED_COLOR)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(description)
	var equipped: Dictionary = GameState.gems_equipped.get(character_id, {})
	for group_mode in ["flat", "percent"]:
		var group_name := "NGỌC PHA LÊ · CHỈ SỐ CỐ ĐỊNH" if group_mode == "flat" else "NGỌC LỤC GIÁC · CHỈ SỐ THEO %"
		col.add_child(UIKit.label(group_name, 14, Color("ffe08a") if group_mode == "flat" else Color("a9d4ff")))
		for gem_type in GameData.GEMS:
			var data: Dictionary = GameData.GEMS[gem_type]
			if String(data["mode"]) != group_mode:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var tint := Color("#" + String(data["color"]))
			var text_tint := tint.lightened(0.55) if String(data["stat"]) == "crit_dmg" else tint
			var name_label := UIKit.label("%s %s" % [String(data["shape"]), String(data["name"])], 12, text_tint)
			name_label.custom_minimum_size.x = 158
			row.add_child(name_label)
			var strength := UIKit.label(_gem_strength_text(data), 10, UIKit.MUTED_COLOR)
			strength.custom_minimum_size.x = 104
			row.add_child(strength)
			var select := OptionButton.new()
			select.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			select.add_item("Không trang bị")
			select.set_item_metadata(0, 0)
			var selected_level: int = int(equipped.get(gem_type, 0))
			for level in range(1, GameData.GEM_LEVELS + 1):
				select.add_item("Cấp %d · túi %d" % [level, GameState.gem_count(gem_type, level)])
				select.set_item_metadata(select.item_count - 1, level)
				if selected_level == level:
					select.select(level)
			select.item_selected.connect(_on_gem_selected.bind(character_id, gem_type, select))
			row.add_child(select)
			var low_level := 0
			for level in range(1, GameData.GEM_LEVELS):
				if GameState.gem_count(gem_type, level) >= 3:
					low_level = level
					break
			var combine_text := "Ghép ×3 → %d" % (low_level + 1) if low_level > 0 else "Thiếu ngọc"
			var combine := UIKit.button(combine_text, Color("357f70"), 11, Vector2(116, 36))
			combine.disabled = low_level == 0
			combine.pressed.connect(_combine_gem.bind(gem_type, low_level))
			row.add_child(combine)
			col.add_child(row)
	return panel


func _on_treasure_selected(index: int, id: String, slot: String, select: OptionButton) -> void:
	var treasure_id: String = String(select.get_item_metadata(index))
	if GameState.equip_treasure(id, slot, treasure_id):
		SceneManager.change_scene(GameData.SCENE_CHARACTER)


func _on_gem_selected(index: int, id: String, gem_type: String, select: OptionButton) -> void:
	var level: int = int(select.get_item_metadata(index))
	if GameState.equip_gem(id, gem_type, level):
		SceneManager.change_scene(GameData.SCENE_CHARACTER)
	else:
		UIKit.toast(self, "Không có viên ngọc đó trong túi.")


func _combine_gem(gem_type: String, level: int) -> void:
	if GameState.combine_gems(gem_type, level):
		SceneManager.change_scene(GameData.SCENE_CHARACTER)
	else:
		UIKit.toast(self, "Cần 3 viên %s cấp %d." % [GameData.GEMS[gem_type]["name"], level])


func _skill_panel() -> Control:
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 14, Color("8a69a8"), 2)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	panel.add_child(col)
	col.add_child(UIKit.label("KỸ NĂNG THEO TÀI LIỆU V2", 20, Color("d8b8ff")))
	var profile: Dictionary = skill_profiles.get(character_id, {})
	var labels := {"passive": "Nội tại", "basic": "Đánh thường", "s1": "Kỹ năng 1", "s2": "Kỹ năng 2", "ult": "Tuyệt kỹ"}
	for key in ["passive", "basic", "s1", "s2", "ult"]:
		var item: Dictionary = profile.get(key, {})
		if item.is_empty():
			continue
		col.add_child(UIKit.label("%s · %s" % [labels[key], String(item.get("title", ""))], 15, Color("ffe0a1")))
		var body_text := UIKit.label(String(item.get("description", "")), 13, UIKit.TEXT_COLOR)
		body_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(body_text)
	return panel


func _on_equipment_selected(index: int, id: String, slot: String, options: Array) -> void:
	if index < 0 or index >= options.size():
		return
	var item_id: String = String(options[index])
	if GameState.equip_item(id, slot, item_id):
		SceneManager.change_scene(GameData.SCENE_CHARACTER)


func _stat_name(stat: String) -> String:
	return {"hp": "HP", "atk": "ATK", "mag": "MAG", "def": "DEF"}.get(stat, stat.to_upper())


func _fmt(value: int) -> String:
	return str(value)


func _gear_summary(stats: Dictionary) -> String:
	var parts: Array[String] = []
	for stat in ["hp", "atk", "mag", "def"]:
		if int(stats.get(stat, 0)) > 0:
			parts.append("%s +%s" % [_stat_name(stat), _fmt(int(stats[stat]))])
	return " / ".join(parts)


func _gem_strength_text(gem: Dictionary) -> String:
	var stat: String = String(gem["stat"]).to_upper()
	if stat in ["CRIT", "CRIT_DMG"]:
		if String(gem["mode"]) == "flat":
			return "+%.1f điểm %%/cấp" % (float(gem["per_level"]) * 100.0)
		return "+%.0f%% tương đối/cấp" % (float(gem["per_level"]) * 100.0)
	if String(gem["mode"]) == "flat":
		return "+%d %s/cấp" % [int(gem["per_level"]), stat]
	return "+%.1f%% %s/cấp" % [float(gem["per_level"]) * 100.0, stat]




