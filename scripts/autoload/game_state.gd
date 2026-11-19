extends Node
## Trạng thái người chơi + lưu/tải (autoload: GameState).

signal coins_changed(value: int)
signal roster_changed
signal team_changed

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 5

var player_name: String = "Thuyền trưởng"
var coins: int = 0
var owned: Dictionary = {}          # id -> số sao (1..MAX_STARS)
var character_levels: Dictionary = {} # id -> cấp nhân vật (1..MAX_CHARACTER_LEVEL)
var character_copies: Dictionary = {} # id -> bản sao dùng nâng sao
var character_shards: Dictionary = {} # id -> mảnh riêng của nhân vật
var team: Array = []                # đội hình chiến đấu, tối đa 6 nhân vật
var pity_ur: int = 0                # số lượt triệu hồi liên tiếp chưa ra UR
var total_pulls: int = 0
var login_total: int = 0            # tổng số ngày đã nhận quà điểm danh
var last_login_date: String = ""    # "YYYY-MM-DD" ngày nhận gần nhất
var campaign_stage: int = 1
var total_wins: int = 0
var daily_wins: int = 0
var daily_date: String = ""
var quest_claimed: Dictionary = {}
var equipment: Dictionary = {}        # character_id -> slot -> equipment_id
var equipment_inventory: Dictionary = {} # equipment_id -> owned count (equipped items remain in this count)
var treasures: Dictionary = {}        # character_id -> treasure slot -> treasure_id
var gem_inventory: Dictionary = {}    # gem type -> counts for levels 1..10
var gems_equipped: Dictionary = {}    # character_id -> gem type -> level
var support_team: Array = []          # six non-combat supporters; each slot grants a stat bonus
var pet_levels: Dictionary = {}
var active_pet: String = "cove_cub"
var selected_character: String = ""
var login_event_streak: int = 0
var login_event_last_date: String = ""
var sp_choice_claimed: bool = false
var spend_event_total: int = 0
var spend_event_claimed: Dictionary = {}
var _cp_missing_role_warnings: Dictionary = {}

# --- Dữ liệu tạm, KHÔNG lưu ---
var pending_battle: Dictionary = {}     # {"team_a": [...], "team_b": [...]}
var login_popup_shown: bool = false     # tự mở màn điểm danh tối đa 1 lần / phiên


func _ready() -> void:
	if not load_game():
		new_game()
	_refresh_daily_quests()


# ======================================================================
#  LƯU / TẢI
# ======================================================================
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func new_game() -> void:
	player_name = "Thuyền trưởng"
	coins = GameData.STARTING_COINS
	owned = {}
	character_levels = {}
	character_copies = {}
	character_shards = {}
	for id in GameData.STARTER_TEAM:
		owned[id] = 1
		character_levels[id] = 1
	team = GameData.STARTER_TEAM.duplicate()
	pity_ur = 0
	total_pulls = 0
	login_total = 0
	last_login_date = ""
	campaign_stage = 1
	total_wins = 0
	daily_wins = 0
	daily_date = today()
	quest_claimed = {}
	equipment = {}
	equipment_inventory = {}
	treasures = {}
	gem_inventory = {}
	for gem_type in GameData.GEMS:
		gem_inventory[gem_type] = [3, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	gems_equipped = {}
	support_team = ["", "", "", "", "", ""]
	pet_levels = {}
	for pet_id in GameData.PETS:
		pet_levels[pet_id] = 1
	active_pet = "cove_cub"
	selected_character = GameData.STARTER_TEAM[0]
	login_event_streak = 0
	login_event_last_date = ""
	sp_choice_claimed = false
	spend_event_total = 0
	spend_event_claimed = {}
	pending_battle = {}
	login_popup_shown = false
	save_game()
	coins_changed.emit(coins)
	roster_changed.emit()
	team_changed.emit()


func save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"player_name": player_name,
		"coins": coins,
		"owned": owned,
		"character_levels": character_levels,
		"character_copies": character_copies,
		"character_shards": character_shards,
		"team": team,
		"pity_ur": pity_ur,
		"total_pulls": total_pulls,
		"login_total": login_total,
		"last_login_date": last_login_date,
		"campaign_stage": campaign_stage,
		"total_wins": total_wins,
		"daily_wins": daily_wins,
		"daily_date": daily_date,
		"quest_claimed": quest_claimed,
		"equipment": equipment,
		"equipment_inventory": equipment_inventory,
		"treasures": treasures,
		"gem_inventory": gem_inventory,
		"gems_equipped": gems_equipped,
		"support_team": support_team,
		"pet_levels": pet_levels,
		"active_pet": active_pet,
		"login_event_streak": login_event_streak,
		"login_event_last_date": login_event_last_date,
		"sp_choice_claimed": sp_choice_claimed,
		"spend_event_total": spend_event_total,
		"spend_event_claimed": spend_event_claimed,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Không ghi được save: %s" % error_string(FileAccess.get_open_error()))
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("File save hỏng, tạo save mới.")
		return false
	var d: Dictionary = parsed
	player_name = String(d.get("player_name", "Thuyền trưởng"))
	coins = int(d.get("coins", 0))
	pity_ur = int(d.get("pity_ur", 0))
	total_pulls = int(d.get("total_pulls", 0))
	login_total = int(d.get("login_total", 0))
	login_event_streak = int(d.get("login_event_streak", 0))
	login_event_last_date = String(d.get("login_event_last_date", ""))
	sp_choice_claimed = bool(d.get("sp_choice_claimed", false))
	spend_event_total = int(d.get("spend_event_total", 0))
	spend_event_claimed = d.get("spend_event_claimed", {})
	last_login_date = String(d.get("last_login_date", ""))
	campaign_stage = maxi(1, int(d.get("campaign_stage", 1)))
	total_wins = maxi(0, int(d.get("total_wins", 0)))
	daily_wins = maxi(0, int(d.get("daily_wins", 0)))
	daily_date = String(d.get("daily_date", today()))
	quest_claimed = d.get("quest_claimed", {})
	equipment = d.get("equipment", {})
	equipment_inventory = {}
	var raw_equipment_inventory: Dictionary = d.get("equipment_inventory", {})
	for item_id in raw_equipment_inventory:
		if GameData.EQUIPMENT.has(item_id):
			equipment_inventory[item_id] = maxi(0, int(raw_equipment_inventory[item_id]))
	# Keep items already equipped in saves from before the shop was added.
	for character_id in equipment:
		for item_id in equipment[character_id].values():
			if GameData.EQUIPMENT.has(item_id):
				equipment_inventory[item_id] = maxi(equipment_item_use_count(String(item_id)), int(equipment_inventory.get(item_id, 0)))
	treasures = d.get("treasures", {})
	gems_equipped = {}
	var raw_equipped_gems: Dictionary = d.get("gems_equipped", {})
	for character_id in raw_equipped_gems:
		var migrated_gems: Dictionary = {}
		for gem_type in raw_equipped_gems[character_id]:
			var migrated_type: String = String(gem_type)
			if not GameData.GEMS.has(migrated_type) and GameData.GEMS.has(migrated_type + "_crystal"):
				migrated_type += "_crystal"
			if GameData.GEMS.has(migrated_type):
				migrated_gems[migrated_type] = int(raw_equipped_gems[character_id][gem_type])
		gems_equipped[character_id] = migrated_gems
	gem_inventory = {}
	var raw_gems: Dictionary = d.get("gem_inventory", {})
	for gem_type in GameData.GEMS:
		var legacy_type: String = String(gem_type).trim_suffix("_crystal")
		var raw_counts: Variant = raw_gems.get(gem_type, null)
		if raw_counts == null and String(gem_type).ends_with("_crystal"):
			raw_counts = raw_gems.get(legacy_type, null)
		var counts: Array = raw_counts.duplicate() if raw_counts is Array else [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
		while counts.size() < GameData.GEM_LEVELS:
			counts.append(0)
		if counts.size() > GameData.GEM_LEVELS:
			counts.resize(GameData.GEM_LEVELS)
		gem_inventory[gem_type] = counts
	pet_levels = d.get("pet_levels", {})
	for pet_id in GameData.PETS:
		if not pet_levels.has(pet_id):
			pet_levels[pet_id] = 1
	active_pet = String(d.get("active_pet", "cove_cub"))
	if not GameData.PETS.has(active_pet):
		active_pet = "cove_cub"
	owned = {}
	character_copies = {}
	character_shards = {}
	var raw_owned: Dictionary = d.get("owned", {})
	for id in raw_owned:
		# Bỏ nhân vật không còn tồn tại trong GameData (đề phòng bạn đổi tên id)
		if GameData.CHARACTERS.has(id):
			owned[id] = clampi(int(raw_owned[id]), 1, GameData.MAX_STARS)
	character_levels = {}
	var raw_levels: Dictionary = d.get("character_levels", {})
	for id in owned:
		character_levels[id] = clampi(int(raw_levels.get(id, 1)), 1, GameData.MAX_CHARACTER_LEVEL)
	var raw_copies: Dictionary = d.get("character_copies", {})
	for id in raw_copies:
		if GameData.CHARACTERS.has(id):
			character_copies[id] = maxi(0, int(raw_copies[id]))
	var raw_shards: Dictionary = d.get("character_shards", {})
	for id in raw_shards:
		if GameData.CHARACTERS.has(id):
			character_shards[id] = maxi(0, int(raw_shards[id]))
	# Nâng save cũ lên đội hình 6v6, vẫn giữ nguyên nhân vật và tài nguyên đã có.
	for id in GameData.STARTER_TEAM:
		if not owned.has(id):
			owned[id] = 1
		if not character_levels.has(id):
			character_levels[id] = 1
	team = []
	for id in d.get("team", []):
		if owned.has(id) and team.size() < GameData.TEAM_SIZE_MAX:
			team.append(String(id))
	for id in GameData.STARTER_TEAM:
		if team.size() >= GameData.TEAM_SIZE_MAX:
			break
		if owned.has(id) and not team.has(id):
			team.append(id)
	if team.is_empty():
		_fill_default_team()
	support_team = ["", "", "", "", "", ""]
	var raw_support: Array = d.get("support_team", [])
	for slot in range(mini(raw_support.size(), GameData.SUPPORT_SLOT_STATS.size())):
		var support_id: String = String(raw_support[slot])
		if support_id != "" and owned.has(support_id) and not support_team.has(support_id):
			support_team[slot] = support_id
	return true


func _fill_default_team() -> void:
	team = []
	for id in GameData.sorted_ids():
		if owned.has(id) and team.size() < GameData.TEAM_SIZE_MAX:
			team.append(id)


# ======================================================================
#  COIN
# ======================================================================
func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func spend_coins(amount: int) -> bool:
	if amount > coins:
		return false
	coins -= amount
	spend_event_total += amount
	coins_changed.emit(coins)
	return true


# ======================================================================
#  NHÂN VẬT & ĐỘI HÌNH
# ======================================================================
func stars_of(id: String) -> int:
	return int(owned.get(id, 0))


func level_of(id: String) -> int:
	return int(character_levels.get(id, 1))


func level_up_cost(id: String) -> int:
	return level_of(id) * GameData.CHARACTER_LEVEL_UP_BASE_COST


func level_up_character(id: String) -> bool:
	if not owned.has(id):
		return false
	var current_level: int = level_of(id)
	if current_level >= GameData.MAX_CHARACTER_LEVEL or not spend_coins(level_up_cost(id)):
		return false
	character_levels[id] = current_level + 1
	save_game()
	roster_changed.emit()
	return true


func character_flat_bonus(id: String) -> Dictionary:
	var result: Dictionary = GameData.star_bonus(stars_of(id))
	var level_steps: int = maxi(0, level_of(id) - 1)
	for stat in GameData.CHARACTER_LEVEL_STAT_PER_STEP:
		result[stat] = int(result.get(stat, 0)) + int(GameData.CHARACTER_LEVEL_STAT_PER_STEP[stat]) * level_steps
	var slots: Dictionary = equipment.get(id, {})
	for slot in slots:
		var item_id: String = String(slots[slot])
		if not GameData.EQUIPMENT.has(item_id):
			continue
		var item_stats: Dictionary = GameData.EQUIPMENT[item_id]["stats"]
		for stat in ["hp", "atk", "mag", "def"]:
			result[stat] = int(result[stat]) + int(item_stats.get(stat, 0))
	var treasure_slots: Dictionary = treasures.get(id, {})
	for treasure_slot in treasure_slots:
		var treasure_id: String = String(treasure_slots[treasure_slot])
		if not GameData.TREASURES.has(treasure_id):
			continue
		var treasure_stats: Dictionary = GameData.TREASURES[treasure_id]["stats"]
		for stat in ["hp", "atk", "mag", "def"]:
			result[stat] = int(result[stat]) + int(treasure_stats.get(stat, 0))
	var equipped_gems: Dictionary = gems_equipped.get(id, {})
	for gem_type in equipped_gems:
		if not GameData.GEMS.has(gem_type):
			continue
		var gem_level: int = clampi(int(equipped_gems[gem_type]), 0, GameData.GEM_LEVELS)
		var gem: Dictionary = GameData.GEMS[gem_type]
		var stat: String = String(gem["stat"])
		if String(gem["mode"]) == "flat" and result.has(stat):
			result[stat] = int(result[stat]) + int(gem["per_level"]) * gem_level
	if GameData.PETS.has(active_pet):
		var pet_data: Dictionary = GameData.PETS[active_pet]
		var level: int = int(pet_levels.get(active_pet, 1))
		var per_level: Dictionary = pet_data["per_level"]
		for stat in ["hp", "atk", "mag", "def"]:
			result[stat] = int(result[stat]) + int(per_level.get(stat, 0)) * level
	return result


func character_percent_bonus(id: String) -> Dictionary:
	var result: Dictionary = {"hp": 0.0, "atk": 0.0, "mag": 0.0, "def": 0.0, "crit": 0.0, "crit_dmg": 0.0}
	var equipped_gems: Dictionary = gems_equipped.get(id, {})
	for gem_type in equipped_gems:
		if not GameData.GEMS.has(gem_type):
			continue
		var gem: Dictionary = GameData.GEMS[gem_type]
		if String(gem["mode"]) != "percent":
			continue
		var stat: String = String(gem["stat"])
		var level: int = clampi(int(equipped_gems[gem_type]), 0, GameData.GEM_LEVELS)
		result[stat] = float(result.get(stat, 0.0)) + float(gem["per_level"]) * level
	return result


func character_secondary_flat_bonus(id: String) -> Dictionary:
	var result: Dictionary = {"crit": 0.0, "crit_dmg": 0.0}
	var equipped_gems: Dictionary = gems_equipped.get(id, {})
	for gem_type in equipped_gems:
		if not GameData.GEMS.has(gem_type):
			continue
		var gem: Dictionary = GameData.GEMS[gem_type]
		var stat: String = String(gem["stat"])
		if String(gem["mode"]) == "flat" and result.has(stat):
			result[stat] = float(result[stat]) + float(gem["per_level"]) * int(equipped_gems[gem_type])
	return result


func character_primary_stat(id: String, stat: String) -> float:
	if not GameData.BASE_STATS.has(id) or not ["hp", "atk", "mag", "def"].has(stat):
		return 0.0
	var base: Dictionary = GameData.BASE_STATS[id]
	var flat: Dictionary = character_flat_bonus(id)
	var pct: Dictionary = character_percent_bonus(id)
	return (float(base[stat]) + float(flat.get(stat, 0))) * (1.0 + float(pct.get(stat, 0.0)))


## Tính chiến lực trên chỉ số cuối cùng; nhận id hoặc dictionary chỉ số đã dựng sẵn.
func calcCharacterCP(character: Variant) -> int:
	var source: Dictionary = character if character is Dictionary else {}
	var id := String(character) if character is String else String(source.get("id", source.get("character_id", "")))
	var primary: Dictionary = {}
	var secondary: Dictionary = {}
	var role := String(source.get("cp_role", source.get("role", "")))
	if GameData.BASE_STATS.has(id):
		var base: Dictionary = GameData.BASE_STATS[id]
		var flat: Dictionary = character_flat_bonus(id)
		var percent: Dictionary = character_percent_bonus(id)
		var support: Dictionary = support_team_bonus() if team.has(id) else {}
		for stat in ["hp", "atk", "mag", "def"]:
			primary[stat] = maxf(0.0, (float(base.get(stat, 0)) + float(flat.get(stat, 0))) * (1.0 + float(percent.get(stat, 0.0))) + float(support.get(stat, 0)))
		secondary = GameData.SECONDARY_STATS.get(id, {})
		var secondary_flat: Dictionary = character_secondary_flat_bonus(id)
		var crit_percent: float = float(percent.get("crit", 0.0))
		var crit_dmg_percent: float = float(percent.get("crit_dmg", 0.0))
		secondary = secondary.duplicate(true)
		secondary["crit"] = float(secondary.get("crit", 0.0)) * (1.0 + crit_percent) + float(secondary_flat.get("crit", 0.0))
		secondary["crit_dmg"] = float(secondary.get("crit_dmg", 0.0)) * (1.0 + crit_dmg_percent) + float(secondary_flat.get("crit_dmg", 0.0))
		role = String(GameData.CHARACTERS.get(id, {}).get("cp_role", role))
	else:
		for stat in ["hp", "atk", "mag", "def"]:
			primary[stat] = maxf(0.0, float(source.get(stat, 0.0)))
		secondary = source
	var warning_key := id if not id.is_empty() else String(source.get("name", "unknown_character"))
	if role == "" or not ["DPS", "Tank", "Healer"].has(role):
		if not _cp_missing_role_warnings.has(warning_key):
			push_warning("Nhân vật %s thiếu role chiến lực hợp lệ; tạm dùng DPS." % warning_key)
			_cp_missing_role_warnings[warning_key] = true
		role = "DPS"
	var config: Dictionary = GameData.CHARACTER_CP_CONFIG
	var crit_rate: float = clampf(maxf(0.0, float(secondary.get("crit", source.get("crit_rate", 0.0)))), 0.0, float(config["crit_rate_cap"]))
	var crit_damage: float = maxf(0.0, float(secondary.get("crit_dmg", source.get("crit_dmg", 0.0))))
	var evasion: float = clampf(maxf(0.0, float(secondary.get("evasion", source.get("evasion", 0.0)))), 0.0, float(config["evasion_cap"]))
	var speed: float = maxf(0.0, float(secondary.get("spd", source.get("spd", source.get("speed", 0.0)))))
	var role_multiplier: float = 1.0 if role == "DPS" else float(config["non_dps_role_multiplier"])
	var main_stat: float = maxf(float(primary.get("atk", 0.0)), float(primary.get("mag", 0.0)))
	var main: float = main_stat * (1.0 + crit_rate * (crit_damage - 1.0)) * role_multiplier
	main = maxf(0.0, main)
	var hp: float = maxf(0.0, float(primary.get("hp", 0.0)))
	var defense: float = maxf(0.0, float(primary.get("def", 0.0)))
	var ehp: float = hp * (1.0 + defense / float(config["defense_scale"])) / (1.0 - evasion)
	var speed_factor: float = maxf(0.0, 1.0 + (speed - 100.0) / float(config["speed_scale"]))
	var raw: float = sqrt(maxf(0.0, main * ehp)) * speed_factor
	return maxi(0, int(round(float(config["coefficient"]) * pow(raw, float(config["exponent"])))))


func teamBonus(_team: Array) -> float:
	return 0.0


func calcTeamCP(characters: Array) -> int:
	var total: int = 0
	for character in characters:
		if character == null or (character is String and String(character).is_empty()) or (character is Dictionary and character.is_empty()):
			continue
		total += calcCharacterCP(character)
	return maxi(0, int(round(float(total) * (1.0 + teamBonus(characters)))))


func support_team_bonus() -> Dictionary:
	var result: Dictionary = {"hp": 0, "atk": 0, "mag": 0, "def": 0}
	var fractional: Dictionary = {"hp": 0.0, "atk": 0.0, "mag": 0.0, "def": 0.0}
	for slot in range(mini(support_team.size(), GameData.SUPPORT_SLOT_STATS.size())):
		var id: String = String(support_team[slot])
		if id == "" or not owned.has(id):
			continue
		var stat: String = String(GameData.SUPPORT_SLOT_STATS[slot])
		fractional[stat] = float(fractional[stat]) + character_primary_stat(id, stat) * GameData.SUPPORT_STAT_RATE
	for stat in fractional:
		result[stat] = int(round(float(fractional[stat])))
	return result


func raise_character_star(id: String) -> bool:
	if not owned.has(id):
		return false
	var current: int = stars_of(id)
	if current >= GameData.MAX_STARS:
		return false
	var next_star: int = current + 1
	var copy_cost: int = int(GameData.STAR_COPY_COST.get(next_star, 0))
	if copies_of(id) < copy_cost:
		return false
	character_copies[id] = copies_of(id) - copy_cost
	owned[id] = current + 1
	save_game()
	roster_changed.emit()
	return true


func equip_item(id: String, slot: String, item_id: String) -> bool:
	if not owned.has(id) or (item_id != "" and not GameData.EQUIPMENT.has(item_id)):
		return false
	if item_id != "" and String(GameData.EQUIPMENT[item_id]["slot"]) != slot:
		return false
	var slots: Dictionary = equipment.get(id, {}).duplicate(true)
	if item_id != "" and String(slots.get(slot, "")) != item_id and equipment_item_use_count(item_id) >= equipment_count(item_id):
		return false
	if item_id == "":
		slots.erase(slot)
	else:
		slots[slot] = item_id
	equipment[id] = slots
	save_game()
	roster_changed.emit()
	return true


func equipment_count(item_id: String) -> int:
	return int(equipment_inventory.get(item_id, 0))


func equipment_item_use_count(item_id: String) -> int:
	var count := 0
	for character_id in equipment:
		for equipped_id in equipment[character_id].values():
			if String(equipped_id) == item_id:
				count += 1
	return count


func buy_equipment(item_id: String) -> bool:
	if not GameData.EQUIPMENT.has(item_id):
		return false
	var price: int = int(GameData.SHOP_EQUIPMENT_PRICES.get(item_id, 0))
	if price <= 0 or not spend_coins(price):
		return false
	equipment_inventory[item_id] = equipment_count(item_id) + 1
	save_game()
	return true


func buy_gem(gem_type: String) -> bool:
	if not GameData.GEMS.has(gem_type):
		return false
	var gem: Dictionary = GameData.GEMS[gem_type]
	var price: int = GameData.SHOP_GEM_FLAT_PRICE if String(gem["mode"]) == "flat" else GameData.SHOP_GEM_PERCENT_PRICE
	if not spend_coins(price):
		return false
	if not gem_inventory.has(gem_type):
		gem_inventory[gem_type] = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
	var counts: Array = gem_inventory[gem_type]
	counts[0] = int(counts[0]) + 1
	gem_inventory[gem_type] = counts
	save_game()
	return true


func equip_treasure(id: String, slot: String, treasure_id: String) -> bool:
	if not owned.has(id) or not GameData.TREASURE_SLOTS.has(slot):
		return false
	if treasure_id != "" and not GameData.TREASURES.has(treasure_id):
		return false
	var slots: Dictionary = treasures.get(id, {}).duplicate(true)
	if treasure_id == "":
		slots.erase(slot)
	else:
		slots[slot] = treasure_id
	treasures[id] = slots
	save_game()
	roster_changed.emit()
	return true


func copies_of(id: String) -> int:
	return int(character_copies.get(id, 0))


func shards_of(id: String) -> int:
	return int(character_shards.get(id, 0))


func add_character_shards(id: String, amount: int) -> void:
	if not GameData.CHARACTERS.has(id) or amount <= 0:
		return
	character_shards[id] = shards_of(id) + amount
	save_game()
	roster_changed.emit()


func exchange_character_shards(id: String) -> bool:
	if not GameData.CHARACTERS.has(id):
		return false
	var tier: String = GameData.char_tier(id)
	var cost: int = int(GameData.CHARACTER_SHARD_COST[tier])
	if shards_of(id) < cost:
		return false
	character_shards[id] = shards_of(id) - cost
	if owned.has(id):
		character_copies[id] = copies_of(id) + 1
	else:
		owned[id] = 1
		character_levels[id] = 1
		if team.size() < GameData.TEAM_SIZE_MAX:
			team.append(id)
			team_changed.emit()
	save_game()
	roster_changed.emit()
	return true


func award_random_character_shards(tier: String, amount: int) -> String:
	var pool: Array = GameData.ids_by_tier(tier)
	if pool.is_empty():
		return ""
	var id: String = String(pool.pick_random())
	character_shards[id] = shards_of(id) + amount
	return id


func gem_count(gem_type: String, level: int) -> int:
	if not gem_inventory.has(gem_type) or level < 1 or level > GameData.GEM_LEVELS:
		return 0
	return int(gem_inventory[gem_type][level - 1])


func combine_gems(gem_type: String, level: int) -> bool:
	if not GameData.GEMS.has(gem_type) or level < 1 or level >= GameData.GEM_LEVELS:
		return false
	var counts: Array = gem_inventory[gem_type]
	if int(counts[level - 1]) < 3:
		return false
	counts[level - 1] = int(counts[level - 1]) - 3
	counts[level] = int(counts[level]) + 1
	gem_inventory[gem_type] = counts
	save_game()
	return true


func equip_gem(id: String, gem_type: String, level: int) -> bool:
	if not owned.has(id) or not GameData.GEMS.has(gem_type) or level < 0 or level > GameData.GEM_LEVELS:
		return false
	var equipped: Dictionary = gems_equipped.get(id, {}).duplicate(true)
	var previous: int = int(equipped.get(gem_type, 0))
	if previous == level:
		return true
	if level > 0 and gem_count(gem_type, level) <= 0:
		return false
	var counts: Array = gem_inventory[gem_type]
	if previous > 0:
		counts[previous - 1] = int(counts[previous - 1]) + 1
	if level > 0:
		counts[level - 1] = int(counts[level - 1]) - 1
		equipped[gem_type] = level
	else:
		equipped.erase(gem_type)
	gem_inventory[gem_type] = counts
	gems_equipped[id] = equipped
	save_game()
	roster_changed.emit()
	return true


func equip_pet(pet_id: String) -> bool:
	if not GameData.PETS.has(pet_id):
		return false
	active_pet = pet_id
	save_game()
	return true


func upgrade_pet(pet_id: String) -> bool:
	if not GameData.PETS.has(pet_id):
		return false
	var level: int = int(pet_levels.get(pet_id, 1))
	if level >= GameData.PET_MAX_LEVEL:
		return false
	var cost: int = int(GameData.PET_UPGRADE_COST.get(level, 0))
	if not spend_coins(cost):
		return false
	pet_levels[pet_id] = level + 1
	save_game()
	return true


## Thêm nhân vật vào kho. Trả về {is_new, star_up, stars, refund}.
func add_character(id: String) -> Dictionary:
	var res := {"is_new": false, "star_up": false, "copy": false, "stars": 1, "refund": 0}
	if not owned.has(id):
		owned[id] = 1
		character_levels[id] = 1
		res["is_new"] = true
		if team.size() < GameData.TEAM_SIZE_MAX:
			team.append(id)
			team_changed.emit()
	else:
		character_copies[id] = copies_of(id) + 1
		res["copy"] = true
	res["stars"] = int(owned[id])
	roster_changed.emit()
	return res


## Bật/tắt nhân vật trong đội. Đội có tối đa 6 người và luôn giữ ít nhất 1.
func toggle_team_member(id: String) -> bool:
	if not owned.has(id):
		return false
	if team.has(id):
		if team.size() <= 1:
			return false
		team.erase(id)
	else:
		if team.size() >= GameData.TEAM_SIZE_MAX:
			return false
		team.append(id)
	save_game()
	team_changed.emit()
	return true


## Gán nhân vật vào một vị trí cố định trong màn bố trận. Nếu nhân vật đã ở đội,
## hai vị trí sẽ đổi chỗ để luôn giữ đủ 6 người và không tạo bản trùng.
func assign_team_slot(slot: int, id: String) -> bool:
	if slot < 0 or slot >= GameData.TEAM_SIZE_MAX or not owned.has(id):
		return false
	var normalized: Array = []
	for current_id in team:
		if owned.has(current_id) and not normalized.has(current_id) and normalized.size() < GameData.TEAM_SIZE_MAX:
			normalized.append(current_id)
	for candidate in GameData.sorted_ids():
		if normalized.size() >= GameData.TEAM_SIZE_MAX:
			break
		if owned.has(candidate) and not normalized.has(candidate):
			normalized.append(candidate)
	if normalized.size() < GameData.TEAM_SIZE_MAX:
		return false
	team = normalized
	var existing_slot: int = team.find(id)
	if existing_slot == slot:
		save_game()
		team_changed.emit()
		return true
	var displaced_id: String = String(team[slot])
	team[slot] = id
	if existing_slot >= 0:
		team[existing_slot] = displaced_id
	save_game()
	team_changed.emit()
	return true


func set_support_slot(slot: int, id: String) -> bool:
	if slot < 0 or slot >= GameData.SUPPORT_SLOT_STATS.size():
		return false
	if id != "" and not owned.has(id):
		return false
	var existing_slot: int = support_team.find(id) if id != "" else -1
	if existing_slot == slot:
		return true
	var displaced_id: String = String(support_team[slot])
	support_team[slot] = id
	if existing_slot >= 0:
		support_team[existing_slot] = displaced_id
	save_game()
	roster_changed.emit()
	return true


# ======================================================================
#  ĐIỂM DANH TÍCH LŨY
# ======================================================================
func today() -> String:
	return Time.get_date_string_from_system()


func can_claim_login() -> bool:
	return last_login_date != today()


## Số ngày đã nhận trong vòng 30 ngày hiện tại (0..30).
func login_claimed_in_cycle() -> int:
	var pos: int = login_total % GameData.LOGIN_CYCLE
	if pos == 0 and login_total > 0 and not can_claim_login():
		return GameData.LOGIN_CYCLE    # vừa nhận xong ngày 30
	return pos


## Ngày (1..30) sẽ nhận nếu bấm nhận lúc này.
func login_next_day() -> int:
	return (login_total % GameData.LOGIN_CYCLE) + 1


## Nhận quà hôm nay. Trả về {day, coins} hoặc {} nếu hôm nay đã nhận.
func claim_login() -> Dictionary:
	if not can_claim_login():
		return {}
	var day: int = login_next_day()
	var amount: int = GameData.login_reward_for_day(day)
	login_total += 1
	last_login_date = today()
	var today_unix: int = int(Time.get_unix_time_from_datetime_string(today() + "T00:00:00"))
	var previous_unix: int = int(Time.get_unix_time_from_datetime_string(login_event_last_date + "T00:00:00")) if not login_event_last_date.is_empty() else 0
	if previous_unix > 0 and today_unix - previous_unix == 86400:
		login_event_streak += 1
	else:
		login_event_streak = 1
	login_event_last_date = today()
	add_coins(amount)
	save_game()
	return {"day": day, "coins": amount, "event_streak": login_event_streak}


func claim_sp_choice(character_id: String) -> bool:
	if sp_choice_claimed or login_event_streak < 3 or not GameData.SP_CHOICE_CHEST_IDS.has(character_id):
		return false
	sp_choice_claimed = true
	add_character(character_id)
	save_game()
	return true


func can_claim_sp_choice() -> bool:
	return login_event_streak >= 3 and not sp_choice_claimed


func has_claimable_spend_event() -> bool:
	for milestone in GameData.SPEND_EVENT_MILESTONES:
		var threshold: int = int(milestone["threshold"])
		if spend_event_total >= threshold and not bool(spend_event_claimed.get(str(threshold), false)):
			return true
	return false


func claim_spend_event_milestone(threshold: int) -> String:
	if spend_event_total < threshold or bool(spend_event_claimed.get(str(threshold), false)):
		return ""
	var shards: int = 0
	for milestone in GameData.SPEND_EVENT_MILESTONES:
		if int(milestone["threshold"]) == threshold:
			shards = int(milestone["shards"])
			break
	if shards <= 0:
		return ""
	var id: String = award_random_character_shards("UR", shards)
	spend_event_claimed[str(threshold)] = true
	save_game()
	return id


# ======================================================================
#  TRẬN ĐẤU
# ======================================================================
## Mở trận giao hữu 6v6; các chế độ chiến dịch và hoạt động gọi begin_battle trực tiếp.
func start_battle() -> void:
	begin_battle("skirmish", 1)


func begin_training_battle(selected_ids: Array) -> bool:
	if selected_ids.is_empty() or selected_ids.size() > GameData.TEAM_SIZE_MAX:
		return false
	var seen: Dictionary = {}
	for id_variant in selected_ids:
		var id := String(id_variant)
		if not GameData.CHARACTERS.has(id) or seen.has(id):
			return false
		seen[id] = true
	var dummies: Array = []
	for i in range(GameData.TEAM_SIZE_MAX):
		dummies.append("training_dummy")
	pending_battle = {
		"team_a": selected_ids.duplicate(),
		"team_b": dummies,
		"mode": "training",
		"training": true,
	}
	SceneManager.change_scene(GameData.SCENE_BATTLE)
	return true


func begin_battle(mode: String, stage: int = 1) -> void:
	if team.size() != GameData.TEAM_SIZE_MAX:
		return
	var enemies: Array = ["chopper", "jinbei", "reiju", "zoro", "sabo", "ace", "shanks", "kaido"]
	var enemy_team: Array = []
	var offset: int = posmod((stage - 1) * 2, enemies.size())
	for i in range(GameData.TEAM_SIZE_MAX):
		enemy_team.append(enemies[(offset + i) % enemies.size()])
	if mode == "boss":
		enemy_team = ["kaido", "kaido", "shanks", "sabo", "ace", "reiju"]
	pending_battle = {
		"team_a": team.duplicate(),
		"team_b": enemy_team,
		"mode": mode,
		"stage": stage,
		"enemy_scale": 1.0 + float(stage - 1) * 0.07 if mode == "campaign" else (1.25 if mode == "boss" else 1.0),
	}
	SceneManager.change_scene(GameData.SCENE_BATTLE)


func open_activities() -> void:
	SceneManager.change_scene(GameData.SCENE_ACTIVITIES)


func _refresh_daily_quests() -> void:
	if daily_date != today():
		daily_date = today()
		daily_wins = 0
		for quest_id in quest_claimed.duplicate().keys():
			if String(quest_id).begins_with("daily_"):
				quest_claimed.erase(quest_id)
		save_game()


func claim_quest(quest_id: String, target: int, reward: int) -> bool:
	if bool(quest_claimed.get(quest_id, false)):
		return false
	var progress: int = daily_wins if quest_id.begins_with("daily_") else total_wins
	if progress < target:
		return false
	quest_claimed[quest_id] = true
	add_coins(reward)
	save_game()
	return true


## Gọi khi trận kết thúc. outcome: "win" | "lose" | "draw". Trả về số coin nhận.
func finish_battle(outcome: String) -> int:
	var reward: int = GameData.BATTLE_LOSE_COINS
	if outcome == "win":
		reward = GameData.BATTLE_WIN_COINS
	elif outcome == "draw":
		reward = GameData.BATTLE_DRAW_COINS
	var mode: String = String(pending_battle.get("mode", "skirmish"))
	if outcome == "win":
		total_wins += 1
		daily_wins += 1
		match mode:
			"campaign":
				var completed_stage := int(pending_battle.get("stage", 1))
				reward = 100 + completed_stage * 20
				campaign_stage = maxi(campaign_stage, completed_stage + 1)
			"trial":
				reward = 160
			"boss":
				reward = 260
			"skirmish":
				reward = GameData.BATTLE_WIN_COINS
	add_coins(reward)
	save_game()
	return reward
