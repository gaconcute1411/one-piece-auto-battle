extends Control
## Team companion demo: select one pet aura and invest coins in its level.

const PET_COLORS := [Color("56b8cf"), Color("7fa8e8"), Color("e87553")]


func _ready() -> void:
	UIKit.add_background(self, 0.58)
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 26
	root.offset_right = -26
	root.offset_top = 20
	root.offset_bottom = -22
	root.add_theme_constant_override("separation", 14)
	add_child(root)
	root.add_child(_header())
	root.add_child(UIKit.label("Pet đang hoạt động cộng chỉ số cho toàn đội trong mọi trận. Nâng cấp và chọn pet tại đây.", 16, UIKit.MUTED_COLOR))
	var grid := HBoxContainer.new()
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("separation", 16)
	root.add_child(grid)
	var i := 0
	for pet_id in GameData.PETS:
		grid.add_child(_pet_card(pet_id, PET_COLORS[i % PET_COLORS.size()]))
		i += 1


func _header() -> Control:
	var row := HBoxContainer.new()
	var back := UIKit.button("‹ Nhân vật", Color("3c465c"), 18, Vector2(145, 46))
	back.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_ROSTER))
	row.add_child(back)
	var title := UIKit.label("ĐỒNG HÀNH PET", 30, Color("a9dcff"), HORIZONTAL_ALIGNMENT_CENTER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	row.add_child(CoinBar.new())
	return row


func _pet_card(pet_id: String, accent: Color) -> Control:
	var pet: Dictionary = GameData.PETS[pet_id]
	var level: int = int(GameState.pet_levels.get(pet_id, 1))
	var panel := UIKit.panel(Color(0.05, 0.08, 0.14, 0.94), 18, accent, 3)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	panel.add_child(col)
	var portrait := Panel.new()
	portrait.custom_minimum_size = Vector2(150, 150)
	portrait.add_theme_stylebox_override("panel", UIKit.style(accent.darkened(0.55), 75, accent, 4, 0.0))
	var icon := UIKit.label(String(pet["name"]).substr(0, 1), 72, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	portrait.add_child(icon)
	col.add_child(portrait)
	col.add_child(UIKit.label(String(pet["name"]), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label("%s · cấp %d/%d" % [pet["role"], level, GameData.PET_MAX_LEVEL], 16, accent, HORIZONTAL_ALIGNMENT_CENTER))
	col.add_child(UIKit.label(String(pet["description"]), 15, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER))
	var bonus: Dictionary = pet["per_level"]
	var stats := "HP +%d   ATK +%d\nMAG +%d   DEF +%d" % [
		int(bonus["hp"]) * level, int(bonus["atk"]) * level,
		int(bonus["mag"]) * level, int(bonus["def"]) * level]
	col.add_child(UIKit.label(stats, 17, Color("a9e8d8"), HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var active := GameState.active_pet == pet_id
	var equip := UIKit.button("ĐANG ĐỒNG HÀNH" if active else "CHỌN PET", Color("2f8d75") if active else Color("425775"), 16, Vector2(260, 48))
	equip.disabled = active
	equip.pressed.connect(_choose_pet.bind(pet_id))
	col.add_child(equip)
	var cost: int = int(GameData.PET_UPGRADE_COST.get(level, 0))
	var upgrade := UIKit.button("NÂNG CẤP · %d coin" % cost if level < GameData.PET_MAX_LEVEL else "ĐÃ TỐI ĐA", Color("956d2c"), 16, Vector2(260, 46))
	upgrade.disabled = level >= GameData.PET_MAX_LEVEL
	upgrade.pressed.connect(_upgrade_pet.bind(pet_id))
	col.add_child(upgrade)
	return panel


func _choose_pet(pet_id: String) -> void:
	GameState.equip_pet(pet_id)
	SceneManager.change_scene(GameData.SCENE_PETS)


func _upgrade_pet(pet_id: String) -> void:
	var level: int = int(GameState.pet_levels.get(pet_id, 1))
	var cost: int = int(GameData.PET_UPGRADE_COST.get(level, 0))
	if not GameState.upgrade_pet(pet_id):
		UIKit.toast(self, "Không đủ coin hoặc pet đã đạt cấp tối đa. Cần %d coin." % cost)
		return
	SceneManager.change_scene(GameData.SCENE_PETS)
