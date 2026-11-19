extends Node
## Run with: godot --headless --path . res://tests/combat_power_test.tscn

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_reference_characters()
	_test_caps()
	_test_monotonic_stats()
	_test_team_sum_and_empty_slots()
	_print_character_table()
	await _smoke_test_cp_screens()
	if _failures == 0:
		print("Combat power tests passed.")
		get_tree().quit(0)
	else:
		push_error("%d combat power test(s) failed." % _failures)
		get_tree().quit(1)


func _test_reference_characters() -> void:
	var targets := {"shanks": 4200, "marco": 4174, "zoro": 3974, "jozu": 3400}
	for id in targets:
		var actual: int = GameState.calcCharacterCP(_base_character(id))
		_check(abs(actual - int(targets[id])) <= 1, "%s requested target %d ±1, literal formula gives %d" % [id, targets[id], actual])


func _test_caps() -> void:
	var crit_capped: Dictionary = _sample_character()
	crit_capped["crit_rate"] = 1.0
	var crit_over: Dictionary = crit_capped.duplicate(true)
	crit_over["crit_rate"] = 1.8
	_check(GameState.calcCharacterCP(crit_over) == GameState.calcCharacterCP(crit_capped), "CritRate above 100% must be capped")
	var evasion_capped: Dictionary = _sample_character()
	evasion_capped["evasion"] = 0.75
	var evasion_over: Dictionary = evasion_capped.duplicate(true)
	evasion_over["evasion"] = 1.0
	_check(GameState.calcCharacterCP(evasion_over) == GameState.calcCharacterCP(evasion_capped), "Evasion above 75% must be capped")


func _test_monotonic_stats() -> void:
	for stat in ["atk", "mag", "hp", "def", "spd"]:
		var character: Dictionary = _sample_character()
		var before: int = GameState.calcCharacterCP(character)
		character[stat] = float(character[stat]) + 100.0
		var after: int = GameState.calcCharacterCP(character)
		_check(after >= before, "%s increase must not reduce CP (%d -> %d)" % [stat, before, after])


func _test_team_sum_and_empty_slots() -> void:
	var zoro: Dictionary = _base_character("zoro")
	var marco: Dictionary = _base_character("marco")
	var team: Array = [zoro, {}, "", null, marco]
	var expected: int = GameState.calcCharacterCP(zoro) + GameState.calcCharacterCP(marco)
	_check(GameState.calcTeamCP(team) == expected, "Team CP must sum members and ignore empty slots")


func _base_character(id: String) -> Dictionary:
	var primary: Dictionary = GameData.BASE_STATS[id]
	var secondary: Dictionary = GameData.SECONDARY_STATS[id]
	return {
		"name": id,
		"role": GameData.CHARACTERS[id]["cp_role"],
		"hp": primary["hp"],
		"atk": primary["atk"],
		"mag": primary["mag"],
		"def": primary["def"],
		"crit_rate": secondary["crit"],
		"crit_dmg": secondary["crit_dmg"],
		"evasion": secondary["evasion"],
		"spd": secondary["spd"],
	}


func _print_character_table() -> void:
	print("Initial character CP (level 1, 1 star, base stats, no gear/support):")
	for id in GameData.sorted_ids():
		var value: int = GameState.calcCharacterCP(_base_character(String(id)))
		print("%s | %s | %d" % [String(GameData.CHARACTERS[id]["name"]), String(GameData.CHARACTERS[id]["cp_role"]), value])


func _smoke_test_cp_screens() -> void:
	GameState.selected_character = String(GameData.STARTER_TEAM[0])
	for scene_path in [GameData.SCENE_ROSTER, GameData.SCENE_FORMATION, GameData.SCENE_CHARACTER]:
		var packed: PackedScene = load(scene_path)
		_check(packed != null, "Could not load %s" % scene_path)
		if packed == null:
			continue
		var instance: Node = packed.instantiate()
		add_child(instance)
		await get_tree().process_frame
		instance.queue_free()
		await get_tree().process_frame


func _sample_character() -> Dictionary:
	return {"name": "sample", "role": "DPS", "hp": 12000.0, "atk": 1200.0, "mag": 900.0, "def": 500.0, "crit_rate": 0.2, "crit_dmg": 1.5, "evasion": 0.1, "spd": 100.0}


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures += 1
	push_error(message)
