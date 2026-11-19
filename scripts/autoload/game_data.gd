extends Node
## Dữ liệu tĩnh của game (autoload: GameData).
## Muốn cân bằng kinh tế / tỉ lệ gacha / phần thưởng thì chỉ cần sửa file này.
## Chỉ số chiến đấu của nhân vật vẫn nằm trong `roster` của battle.gd.

const GAME_TITLE := "ONE PIECE AUTO BATTLE"
const GAME_VERSION := "0.5.1"

# ---- Đường dẫn scene ----
const SCENE_TITLE := "res://scenes/title_screen.tscn"
const SCENE_LOBBY := "res://scenes/lobby.tscn"
const SCENE_GACHA := "res://scenes/gacha.tscn"
const SCENE_ROSTER := "res://scenes/roster.tscn"
const SCENE_FORMATION := "res://scenes/formation.tscn"
const SCENE_LOGIN := "res://scenes/login_rewards.tscn"
const SCENE_ACTIVITIES := "res://scenes/activities.tscn"
const SCENE_EVENTS := "res://scenes/events.tscn"
const SCENE_TRAINING := "res://scenes/training.tscn"
const SCENE_CHARACTER := "res://scenes/character_detail.tscn"
const SCENE_PETS := "res://scenes/pets.tscn"
const SCENE_EQUIPMENT := "res://scenes/equipment.tscn"
const SCENE_SHOP := "res://scenes/shop.tscn"
const SCENE_SUPPORT_FORMATION := "res://scenes/support_formation.tscn"
const SCENE_BATTLE := "res://battle.tscn"

# ---- Bậc nhân vật: thứ tự từ cao xuống thấp ----
const TIER_ORDER := ["UR", "SP", "SSR"]
const TIER_RANK := {"UR": 3, "SP": 2, "SSR": 1}

# Kích thước ảnh theo bảng tham khảo, quy đổi theo Zoro = 1.00 (~230 px).
const CHARACTER_ART_SCALE := {
	"chopper": 0.60,
	"zoro": 1.00, "reiju": 1.00, "ace": 1.00, "sabo": 1.00, "rayleigh": 1.00,
	"law": 1.00, "shanks": 1.00, "marco": 1.00, "teach": 1.00, "enel": 1.00,
	"sengoku": 1.25, "garp": 1.25, "aokiji": 1.25, "jinbei": 1.25, "kizaru": 1.25,
	"doflamingo": 1.25, "akainu": 1.25, "jozu": 1.25, "kuma": 1.25, "magellan": 1.25,
	"whitebeard": 1.40, "kaido": 1.40, "shirahoshi": 1.40,
}
const CHARACTER_ART_REFERENCE_HEIGHT := 230.0

# Tỉ lệ ra mỗi bậc (tổng = 1.0)
const TIER_RATES := {"UR": 0.02, "SP": 0.13, "SSR": 0.85}

# ---- Gacha ----
const PULL_COST_1 := 160
const PULL_COST_10 := 1500            # rẻ hơn 100 coin so với 10 lần đơn
const PITY_UR := 50                   # đủ 50 lượt không ra UR -> lượt thứ 50 chắc chắn UR
const TEN_PULL_MIN_TIER := "SP"       # lượt cuối của x10 ít nhất bậc này nếu chưa có
const MAX_STARS := 15
const MAX_CHARACTER_LEVEL := 100
const CHARACTER_LEVEL_UP_BASE_COST := 25
const CHARACTER_LEVEL_STAT_PER_STEP := {"hp": 220, "atk": 20, "mag": 20, "def": 14}

# Công thức chiến lực; tách riêng để tiện cân bằng mà không chạm chỉ số chiến đấu.
const CHARACTER_CP_CONFIG := {
	"defense_scale": 2000.0,
	"non_dps_role_multiplier": 0.9,
	"evasion_cap": 0.75,
	"crit_rate_cap": 1.0,
	"speed_scale": 200.0,
	"coefficient": 103.35,
	"exponent": 0.429,
}
# Bản sao cần để lên bậc sao kế tiếp, khóa theo số sao đích.
const STAR_COPY_COST := {2: 1, 3: 1, 4: 2, 5: 2, 6: 3, 7: 3, 8: 4, 9: 4, 10: 5, 11: 5, 12: 6, 13: 6, 14: 7, 15: 8}
const STAR_STAT_PER_STEP := {"hp": 650, "atk": 70, "mag": 70, "def": 45}

const CHARACTER_SHARD_COST := {"SSR": 90, "SP": 120, "UR": 150}
const SP_CHOICE_CHEST_IDS := ["teach", "shirahoshi", "magellan", "enel", "aokiji"]
const SPEND_EVENT_MILESTONES := [
	{"threshold": 1000, "shards": 60}, {"threshold": 1500, "shards": 90},
	{"threshold": 2000, "shards": 120}, {"threshold": 3000, "shards": 180},
	{"threshold": 5000, "shards": 300},
]

# Cộng cố định từ trang bị demo; có thể đổi số tại đây để cân bằng.
const EQUIPMENT_SLOTS := ["Vũ khí", "Giáp", "Bùa", "Giày"]
const EQUIPMENT := {
	"iron_blade": {"name": "Kiếm thép", "slot": "Vũ khí", "stats": {"hp": 0, "atk": 180, "mag": 0, "def": 25}},
	"storm_staff": {"name": "Trượng giông", "slot": "Vũ khí", "stats": {"hp": 0, "atk": 0, "mag": 180, "def": 25}},
	"guardian_vest": {"name": "Giáp hộ vệ", "slot": "Giáp", "stats": {"hp": 900, "atk": 0, "mag": 0, "def": 90}},
	"captain_coat": {"name": "Áo thuyền trưởng", "slot": "Giáp", "stats": {"hp": 550, "atk": 80, "mag": 80, "def": 45}},
	"ruby_charm": {"name": "Bùa hồng ngọc", "slot": "Bùa", "stats": {"hp": 250, "atk": 90, "mag": 90, "def": 0}},
	"tide_charm": {"name": "Bùa thủy triều", "slot": "Bùa", "stats": {"hp": 600, "atk": 0, "mag": 0, "def": 60}},
	"swift_boots": {"name": "Giày lướt sóng", "slot": "Giày", "stats": {"hp": 200, "atk": 60, "mag": 60, "def": 20}},
	"anchor_boots": {"name": "Ủng mỏ neo", "slot": "Giày", "stats": {"hp": 500, "atk": 0, "mag": 0, "def": 70}},
}
const TREASURE_SLOTS := ["Bảo vật"]
const TREASURES := {
	"eternal_compass": {"name": "La bàn vĩnh cửu", "stats": {"hp": 500, "atk": 0, "mag": 0, "def": 45}},
	"phoenix_feather": {"name": "Lông phượng hoàng", "stats": {"hp": 300, "atk": 0, "mag": 130, "def": 0}},
	"conqueror_medal": {"name": "Huy chương Bá Vương", "stats": {"hp": 0, "atk": 130, "mag": 0, "def": 20}},
	"sea_prism": {"name": "Thạch biển sâu", "stats": {"hp": 250, "atk": 0, "mag": 80, "def": 35}},
	"ancient_map": {"name": "Bản đồ cổ đại", "stats": {"hp": 0, "atk": 70, "mag": 70, "def": 0}},
}
const GEM_LEVELS := 10
const GEMS := {
	"atk_crystal": {"name": "Ngọc ATK Pha Lê", "stat": "atk", "mode": "flat", "per_level": 25, "color": "ff9a32", "shape": "◆", "label": "ATK + cố định"},
	"atk_hex": {"name": "Ngọc ATK Lục Giác", "stat": "atk", "mode": "percent", "per_level": 0.012, "color": "ff9a32", "shape": "⬡", "label": "ATK +%"},
	"mag_crystal": {"name": "Ngọc MAG Pha Lê", "stat": "mag", "mode": "flat", "per_level": 25, "color": "b879ff", "shape": "◆", "label": "MAG + cố định"},
	"mag_hex": {"name": "Ngọc MAG Lục Giác", "stat": "mag", "mode": "percent", "per_level": 0.012, "color": "b879ff", "shape": "⬡", "label": "MAG +%"},
	"def_crystal": {"name": "Ngọc DEF Pha Lê", "stat": "def", "mode": "flat", "per_level": 18, "color": "59c978", "shape": "◆", "label": "DEF + cố định"},
	"def_hex": {"name": "Ngọc DEF Lục Giác", "stat": "def", "mode": "percent", "per_level": 0.012, "color": "59c978", "shape": "⬡", "label": "DEF +%"},
	"hp_crystal": {"name": "Ngọc HP Pha Lê", "stat": "hp", "mode": "flat", "per_level": 260, "color": "ef4d59", "shape": "◆", "label": "HP + cố định"},
	"hp_hex": {"name": "Ngọc HP Lục Giác", "stat": "hp", "mode": "percent", "per_level": 0.012, "color": "ef4d59", "shape": "⬡", "label": "HP +%"},
	"crit_crystal": {"name": "Ngọc Crit Rate Pha Lê", "stat": "crit", "mode": "flat", "per_level": 0.006, "color": "aeb8c3", "shape": "◆", "label": "Crit Rate + điểm %"},
	"crit_hex": {"name": "Ngọc Crit Rate Lục Giác", "stat": "crit", "mode": "percent", "per_level": 0.04, "color": "aeb8c3", "shape": "⬡", "label": "Crit Rate +% tương đối"},
	"crit_dmg_crystal": {"name": "Ngọc Crit Damage Pha Lê", "stat": "crit_dmg", "mode": "flat", "per_level": 0.03, "color": "373b42", "shape": "◆", "label": "Crit Damage + điểm %"},
	"crit_dmg_hex": {"name": "Ngọc Crit Damage Lục Giác", "stat": "crit_dmg", "mode": "percent", "per_level": 0.03, "color": "373b42", "shape": "⬡", "label": "Crit Damage +% tương đối"},
}
const SUPPORT_SLOT_STATS := ["hp", "hp", "atk", "mag", "def", "def"]
const SUPPORT_STAT_RATE := 0.05
const SHOP_EQUIPMENT_PRICES := {"iron_blade": 450, "storm_staff": 450, "guardian_vest": 520, "captain_coat": 480, "ruby_charm": 420, "tide_charm": 480, "swift_boots": 400, "anchor_boots": 450}
const SHOP_GEM_FLAT_PRICE := 120
const SHOP_GEM_PERCENT_PRICE := 180
const PET_MAX_LEVEL := 5
const PET_UPGRADE_COST := {1: 120, 2: 220, 3: 360, 4: 550}
const PETS := {
	"cove_cub": {"name": "Rái cá vịnh", "role": "Hộ vệ", "description": "Tăng sức bền cho cả đội.", "per_level": {"hp": 500, "atk": 0, "mag": 0, "def": 45}},
	"sky_gull": {"name": "Mòng biển xanh", "role": "Trinh sát", "description": "Tăng sức tấn công và phép thuật.", "per_level": {"hp": 0, "atk": 55, "mag": 55, "def": 15}},
	"ember_drake": {"name": "Rồng con hỏa", "role": "Đột kích", "description": "Tăng sát thương, kèm một ít sinh lực.", "per_level": {"hp": 250, "atk": 80, "mag": 80, "def": 0}},
}
const BASE_STATS := {
	"zoro": {"hp": 10400, "atk": 1480, "mag": 260, "def": 500}, "marco": {"hp": 13500, "atk": 260, "mag": 1720, "def": 600},
	"chopper": {"hp": 8800, "atk": 180, "mag": 1180, "def": 380}, "reiju": {"hp": 8800, "atk": 200, "mag": 1220, "def": 400},
	"shanks": {"hp": 11500, "atk": 1700, "mag": 320, "def": 560}, "sabo": {"hp": 10000, "atk": 260, "mag": 1460, "def": 470},
	"jinbei": {"hp": 12400, "atk": 950, "mag": 200, "def": 640}, "ace": {"hp": 9800, "atk": 260, "mag": 1480, "def": 450},
	"kaido": {"hp": 15500, "atk": 1350, "mag": 260, "def": 760}, "aokiji": {"hp": 10400, "atk": 260, "mag": 1350, "def": 500},
	"enel": {"hp": 9400, "atk": 250, "mag": 1440, "def": 420}, "akainu": {"hp": 11200, "atk": 300, "mag": 1680, "def": 520},
	"doflamingo": {"hp": 8900, "atk": 210, "mag": 1240, "def": 410}, "garp": {"hp": 13200, "atk": 1560, "mag": 280, "def": 700},
	"jozu": {"hp": 12200, "atk": 900, "mag": 180, "def": 700}, "rayleigh": {"hp": 11600, "atk": 1640, "mag": 320, "def": 570},
	"kizaru": {"hp": 8800, "atk": 1240, "mag": 200, "def": 400}, "law": {"hp": 10200, "atk": 240, "mag": 1340, "def": 480},
	"sengoku": {"hp": 15000, "atk": 1250, "mag": 280, "def": 800}, "whitebeard": {"hp": 13800, "atk": 1480, "mag": 280, "def": 700},
	"shirahoshi": {"hp": 11000, "atk": 200, "mag": 1380, "def": 460}, "magellan": {"hp": 11200, "atk": 260, "mag": 1380, "def": 520},
	"kuma": {"hp": 12000, "atk": 1000, "mag": 200, "def": 600}, "teach": {"hp": 10200, "atk": 260, "mag": 1480, "def": 480},
}

# ---- Kinh tế khởi đầu & chiến đấu ----
const STARTING_COINS := 1600          # vừa đủ 1 lần x10
const STARTER_TEAM := ["chopper", "jinbei", "reiju", "zoro", "sabo", "ace"]
const TEAM_SIZE_MAX := 6
const BATTLE_WIN_COINS := 150
const BATTLE_DRAW_COINS := 60
const BATTLE_LOSE_COINS := 40

# ---- Điểm danh tích lũy (không cần liên tục), 30 ngày rồi lặp lại ----
const LOGIN_CYCLE := 30
const LOGIN_REWARDS := [
	100, 100, 150, 150, 200, 200, 500,      # ngày 1-7
	150, 150, 200, 200, 250, 250, 600,      # ngày 8-14
	200, 200, 250, 250, 300, 300, 800,      # ngày 15-21
	250, 250, 300, 300, 350, 350, 1000,     # ngày 22-28
	500, 2000,                              # ngày 29-30
]

# ---- Danh sách nhân vật: bậc + thông tin hiển thị ----
# Phân bậc dưới đây là GỢI Ý tạm, bạn đổi tùy ý.
const CHARACTERS := {
	"kaido":   {"name": "Kaido",   "tier": "UR",  "role": "Đỡ đòn / Diện rộng", "cp_role": "Tank"},
	"shanks":  {"name": "Shanks",  "tier": "UR",  "role": "Sát thương / Chí mạng", "cp_role": "DPS"},
	"zoro":    {"name": "Zoro",    "tier": "SP",  "role": "Sát thương đơn mục tiêu", "cp_role": "DPS"},
	"ace":     {"name": "Ace",     "tier": "SP",  "role": "Phép lửa / Phản đòn", "cp_role": "DPS"},
	"sabo":    {"name": "Sabo",    "tier": "SP",  "role": "Phép lửa diện rộng", "cp_role": "DPS"},
	"chopper": {"name": "Chopper", "tier": "SSR", "role": "Hồi máu / Hỗ trợ", "cp_role": "Healer"},
	"jinbei":  {"name": "Jinbei",  "tier": "SSR", "role": "Đỡ đòn / Phản công", "cp_role": "Tank"},
	"reiju":   {"name": "Reiju",   "tier": "SSR", "role": "Độc / Giảm hồi máu", "cp_role": "DPS"},
	"marco": {"name": "Marco", "tier": "UR", "role": "Hồi máu / Hộ vệ", "cp_role": "Healer"},
	"aokiji": {"name": "Aokiji", "tier": "SP", "role": "Đóng băng / Khống chế", "cp_role": "DPS"},
	"enel": {"name": "Enel", "tier": "SP", "role": "Điện / Tốc độ", "cp_role": "DPS"},
	"akainu": {"name": "Akainu", "tier": "UR", "role": "Dung nham / Sát thương diện rộng", "cp_role": "DPS"},
	"doflamingo": {"name": "Doflamingo", "tier": "SSR", "role": "Điều khiển / Chảy máu", "cp_role": "DPS"},
	"garp": {"name": "Garp", "tier": "UR", "role": "Phá giáp / Đơn mục tiêu", "cp_role": "DPS"},
	"jozu": {"name": "Jozu", "tier": "SSR", "role": "Đỡ đòn / Phản sát thương", "cp_role": "Tank"},
	"rayleigh": {"name": "Rayleigh", "tier": "UR", "role": "Haki / Đấu sĩ", "cp_role": "DPS"},
	"kizaru": {"name": "Kizaru", "tier": "SP", "role": "Tốc độ / Ám sát", "cp_role": "DPS"},
	"law": {"name": "Law", "tier": "SP", "role": "Hồi máu / Lá chắn", "cp_role": "Healer"},
	"sengoku": {"name": "Sengoku", "tier": "UR", "role": "Đỡ đòn / Hỗ trợ đội", "cp_role": "Tank"},
	"whitebeard": {"name": "Whitebeard", "tier": "UR", "role": "Chấn động / Đấu sĩ", "cp_role": "DPS"},
	"shirahoshi": {"name": "Shirahoshi", "tier": "SP", "role": "Hồi máu / Hải Vương", "cp_role": "Healer"},
	"magellan": {"name": "Magellan", "tier": "SP", "role": "Độc / Diện rộng", "cp_role": "DPS"},
	"kuma": {"name": "Kuma", "tier": "SSR", "role": "Đỡ đòn / Khống chế", "cp_role": "Tank"},
	"teach": {"name": "Teach", "tier": "SP", "role": "Hắc ám / Phá buff", "cp_role": "DPS"},
}

const SKILL_NAMES := {
	"zoro": ["Oni Giri", "Tatsu Maki", "Shishi Sonson", "Three Thousand Worlds"],
	"chopper": ["Hoof Roseo", "Injection Shot", "Guard Point", "Cherry Blossom Miracle"],
	"reiju": ["Pink Hornet", "Venom Breath", "Toxic Sting", "Vinsmoke Venom Storm"],
	"shanks": ["Gryphon Slash", "Conqueror's Pressure", "Haki Flash", "Divine Departure"],
	"sabo": ["Dragon Claw Fist", "Hiken", "Dragon's Breath", "Flaming Dragon King"],
	"jinbei": ["Five Thousand Tile True Punch", "Vagabond Drill", "Shark Brick Fist", "Ocean Current Shoulder Throw"],
	"ace": ["Higan", "Hotarubi: Hidaruma", "Cross Fire", "Great Flame Commandment: Flame Emperor"],
	"kaido": ["Kanabo Smash", "Bolo Breath", "Dragon Scales", "Flame Dragon Torch"],
	"marco": ["Phoenix Brand", "Blue Bird", "Blue Flame Regeneration", "Phoenix Rebirth"],
	"aokiji": ["Ice Saber", "Ice Block: Partisan", "Ice Ball", "Ice Age"],
	"enel": ["30 Million Volt: Hino", "El Thor", "60 Million Volt: Jamboule", "200 Million Volt: Amaru"],
	"akainu": ["Magma Fist", "Inugami Guren", "Meigo", "Ryusei Kazan"],
	"doflamingo": ["Five Color Strings", "Parasite", "Overheat", "Divine String Execution"],
	"garp": ["Iron Fist Smash", "Meteor Fist Shower", "Blue Hole", "Galaxy Impact"],
	"jozu": ["Diamond Punch", "Brilliant Punk", "Diamond Bastion", "Glacier Toss"],
	"rayleigh": ["Sword of the Dark King", "Advanced Armament Haki", "Conqueror's Haki", "Dark King: Haki Severance"],
	"kizaru": ["Laser Beam", "Yata no Kagami", "Ama no Murakumo", "Yasakani no Magatama"],
	"law": ["Scalpel", "Shambles", "Injection Shot", "Gamma Knife & Curtain"],
	"sengoku": ["Palm Thrust", "Golden Guard", "Buddha's Judgment", "Infinite Shockwave"],
	"whitebeard": ["Murakumogiri Slash", "Gekishin", "Kabutowari", "Seaquake"],
	"shirahoshi": ["Tidal Blessing", "Ocean's Embrace", "Sea King's Roar", "Awakening of Poseidon"],
	"magellan": ["Hydra", "Venom Road", "Chloro Ball", "Venom Demon: Hydra's Wrath"],
	"kuma": ["Pad Cannon", "Tsuppari Pad Cannon", "Pain Extraction", "Ursus Shock"],
	"teach": ["Black Vortex", "Kurouzu", "Black Hole", "Gura Gura no Mi: Shima Yurashi"],
}

const SECONDARY_STATS := {
	"zoro": {"spd":110,"crit":0.17,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.06,"effect_res":0.10}, "marco":{"spd":106,"crit":0.05,"crit_dmg":1.30,"accuracy":0.10,"evasion":0.05,"effect_res":0.18}, "chopper":{"spd":104,"crit":0.05,"crit_dmg":1.30,"accuracy":0.08,"evasion":0.06,"effect_res":0.12}, "reiju":{"spd":100,"crit":0.12,"crit_dmg":1.40,"accuracy":0.12,"evasion":0.05,"effect_res":0.10},
	"shanks":{"spd":110,"crit":0.16,"crit_dmg":1.50,"accuracy":0.12,"evasion":0.06,"effect_res":0.14}, "sabo":{"spd":102,"crit":0.15,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.05,"effect_res":0.10}, "jinbei":{"spd":90,"crit":0.05,"crit_dmg":1.30,"accuracy":0.08,"evasion":0.02,"effect_res":0.15}, "ace":{"spd":106,"crit":0.16,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.06,"effect_res":0.10},
	"kaido":{"spd":96,"crit":0.10,"crit_dmg":1.40,"accuracy":0.08,"evasion":0.02,"effect_res":0.18}, "aokiji":{"spd":100,"crit":0.10,"crit_dmg":1.40,"accuracy":0.14,"evasion":0.05,"effect_res":0.14}, "enel":{"spd":113,"crit":0.14,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.08,"effect_res":0.10}, "akainu":{"spd":100,"crit":0.15,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.04,"effect_res":0.10},
	"doflamingo":{"spd":104,"crit":0.14,"crit_dmg":1.45,"accuracy":0.12,"evasion":0.06,"effect_res":0.10}, "garp":{"spd":98,"crit":0.12,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.03,"effect_res":0.14}, "jozu":{"spd":86,"crit":0.05,"crit_dmg":1.30,"accuracy":0.08,"evasion":0.01,"effect_res":0.14}, "rayleigh":{"spd":108,"crit":0.17,"crit_dmg":1.50,"accuracy":0.12,"evasion":0.05,"effect_res":0.12},
	"kizaru":{"spd":120,"crit":0.16,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.08,"effect_res":0.10}, "law":{"spd":108,"crit":0.08,"crit_dmg":1.30,"accuracy":0.10,"evasion":0.06,"effect_res":0.16}, "sengoku":{"spd":94,"crit":0.08,"crit_dmg":1.30,"accuracy":0.08,"evasion":0.02,"effect_res":0.16}, "whitebeard":{"spd":92,"crit":0.10,"crit_dmg":1.40,"accuracy":0.08,"evasion":0.02,"effect_res":0.15},
	"shirahoshi":{"spd":96,"crit":0.05,"crit_dmg":1.30,"accuracy":0.08,"evasion":0.04,"effect_res":0.16}, "magellan":{"spd":94,"crit":0.10,"crit_dmg":1.40,"accuracy":0.12,"evasion":0.03,"effect_res":0.18}, "kuma":{"spd":92,"crit":0.05,"crit_dmg":1.30,"accuracy":0.08,"evasion":0.03,"effect_res":0.16}, "teach":{"spd":97,"crit":0.14,"crit_dmg":1.50,"accuracy":0.10,"evasion":0.04,"effect_res":0.12},
}


func char_name(id: String) -> String:
	return String(CHARACTERS[id]["name"])


func char_tier(id: String) -> String:
	return String(CHARACTERS[id]["tier"])


func character_display_height(id: String) -> float:
	return CHARACTER_ART_REFERENCE_HEIGHT * float(CHARACTER_ART_SCALE.get(id, 1.0))


func star_bonus(stars: int) -> Dictionary:
	var steps: int = clampi(stars, 1, MAX_STARS) - 1
	var bonus: Dictionary = {}
	for stat in STAR_STAT_PER_STEP:
		bonus[stat] = int(STAR_STAT_PER_STEP[stat]) * steps
	return bonus


func equipment_ids_for_slot(slot: String) -> Array:
	var ids: Array = []
	for id in EQUIPMENT:
		if String(EQUIPMENT[id]["slot"]) == slot:
			ids.append(id)
	return ids


func ids_by_tier(tier: String) -> Array:
	var out: Array = []
	for id in CHARACTERS:
		if CHARACTERS[id]["tier"] == tier:
			out.append(id)
	return out


## Danh sách id sắp xếp: bậc cao trước, cùng bậc thì theo tên.
func sorted_ids() -> Array:
	var ids: Array = CHARACTERS.keys()
	ids.sort_custom(func(a, b):
		var ra: int = TIER_RANK[CHARACTERS[a]["tier"]]
		var rb: int = TIER_RANK[CHARACTERS[b]["tier"]]
		if ra != rb:
			return ra > rb
		return String(CHARACTERS[a]["name"]) < String(CHARACTERS[b]["name"]))
	return ids


func login_reward_for_day(day: int) -> int:
	return int(LOGIN_REWARDS[(day - 1) % LOGIN_CYCLE])
