extends Node2D
# Auto-battle 6v6 - Godot 4.x
# Có đủ nội tại + Skill 1 + Skill 2 + Ultimate theo bản nháp demo_character.docx
# CÁCH HOẠT ĐỘNG CỦA MỖI LƯỢT
#  - Đầu lượt: +25 năng lượng, giảm hồi chiêu, nhận sát thương theo thời gian (độc/cháy/chảy máu).
#  - Chọn kỹ năng theo thứ tự ưu tiên: Ultimate (đủ 100 năng lượng) > Skill 2 > Skill 1 > đánh thường.
#  - Bị đánh trúng được +10 năng lượng.
#  - Hiệu ứng giảm 1 lượt khi kết thúc lượt của chủ sở hữu.

const CHARACTER_ANIMATIONS = preload("res://scripts/character_animations.gd")
# Set to false to restore the original static PNG sprites without changing combat mechanics.
const USE_CHARACTER_ANIMATIONS: bool = true
const BACKGROUND_PATH = "res://background.jpg"
const BAR_W = 100.0

const MAX_ROUNDS = 40

# --- SÂN ĐẤU / VỊ TRÍ RA CHIÊU ---
# Godot viewport 1152 x 648; đây là vị trí CHÂN nhân vật ở giữa sân.
const ARENA_CAST_CENTER := Vector2(576.0, 398.0)
# Cách mục tiêu một khoảng để nhân vật không đè trực tiếp lên nhau.
const CAST_SINGLE_GAP_MIN := 83.0
const CAST_SINGLE_GAP_MAX := 115.0
# Thời gian di chuyển có giới hạn, không quá chậm với các slot ở xa.
const CAST_MOVE_PIXELS_PER_SECOND := 1150.0
# Approach speed and recoil by character (in viewport pixels, not texture pixels).
# The actor's texture scale is never touched by the movement system.
const MOTION_DEFAULT := {"windup": 0.095, "pullback": 7.0, "speed": 1250.0,
	"return_speed": 1500.0, "hit_push": 8.0, "backstep": 17.0}
const MOTION_SPECIAL := {
	"zoro": {"windup": 0.075, "pullback": 12.0, "speed": 2050.0,
		"return_speed": 1850.0, "hit_push": 14.0, "backstep": 30.0},
	"shanks": {"windup": 0.105, "pullback": 14.0, "speed": 1900.0,
		"return_speed": 1770.0, "hit_push": 15.0, "backstep": 32.0},
	"kaido": {"windup": 0.18, "pullback": 7.0, "speed": 925.0,
		"return_speed": 900.0, "hit_push": 12.0, "backstep": 20.0},
}


# Công thức sát thương theo thời gian (bản nháp chưa ghi số, bạn chỉnh tại đây)
const BLEED_PCT = 0.30    # Chảy máu mỗi lượt = 30% ATK của người gây
const BURN_PCT = 0.30     # Bản v2: Burn lấy 30% chỉ số chính, tùy kỹ năng có thể ghi đè.
const FEAR_PCT = 0.40     # Sợ hãi: sát thương gây ra giảm 40%

const STACK_NAMES = {"ashura": "Ashura", "haki": "Haki", "flame": "Lửa", "water": "Thủy"}

# --- DỮ LIỆU NHÂN VẬT ---
# h: chiều cao hiển thị | faces_right: ảnh gốc nhìn sang phải | pixel: ảnh pixel art
# main: chỉ số chính dùng cho đánh thường | crit: tỉ lệ chí mạng | spd: tốc độ (tự gán)
# Kỹ năng: hits = danh sách hệ số sát thương mỗi đòn (1.0 = 100% ATK/MAG)
var roster = {
	"zoro": {
		"name": "Zoro", "hp": 22000, "atk": 3800, "mag": 800, "def": 1500, "spd": 12,
		"main": "atk", "crit": 0.25,
		"h": 150, "color": Color(0.3, 0.7, 0.3), "faces_right": true, "pixel": true,
		"skills": {
			"basic": {"name": "Chém thường", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Oni Giri", "cd": 2, "target": "enemy", "hits": [0.8, 0.8, 0.8],
				"on_hit": [{"t": "bleed", "chance": 0.3, "turns": 2}],
				"color": Color(0.5, 1.0, 0.6, 0.6)},
			"s2": {"name": "Rengoku Onigiri", "cd": 4, "target": "enemy", "hits": [2.8],
				"ignore_def": 0.25, "bonus_if": {"if": "bleed", "pct": 0.3},
				"color": Color(0.5, 1.0, 0.6, 0.6)},
			"ult": {"name": "ASHURA: Nine Sword Style", "target": "enemy", "hits": [1.0, 1.0, 1.0, 1.0, 2.5],
				"extra_turn_on_kill": true, "color": Color(0.7, 1.0, 0.4, 0.7)},
		},
	},
	"chopper": {
		"name": "Chopper", "hp": 27000, "atk": 900, "mag": 2400, "def": 2200, "spd": 15,
		"main": "mag", "crit": 0.10,
		"h": 100, "color": Color(0.9, 0.5, 0.6), "faces_right": false, "pixel": true,
		"skills": {
			"basic": {"name": "Đòn thường", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Emergency Treatment", "cd": 2, "target": "ally_low", "cond": "need_hurt",
				"heal": {"pct": 0.18, "cleanse": 1}, "color": Color(0.4, 1.0, 0.5, 0.6)},
			"s2": {"name": "Rumble Ball: Guard Point", "cd": 4, "target": "ally_all",
				"shield": {"pct": 0.12, "to": "allies"},
				"team_fx": [{"t": "mod", "stat": "def", "pct": 0.15, "turns": 2, "label": "DEF+15%"}],
				"color": Color(0.5, 0.8, 1.0, 0.6)},
			"ult": {"name": "Monster Point: Medical Overdrive", "target": "ally_all", "cond": "need_hurt",
				"heal": {"pct": 0.25, "cleanse": 2},
				"team_fx": [{"t": "mod", "stat": "def", "pct": 0.20, "turns": 2, "label": "DEF+20%"}],
				"color": Color(0.4, 1.0, 0.5, 0.7)},
		},
	},
	"reiju": {
		"name": "Reiju", "hp": 20000, "atk": 1000, "mag": 3400, "def": 1300, "spd": 11,
		"main": "mag", "crit": 0.10,
		"h": 150, "color": Color(0.9, 0.4, 0.7), "faces_right": true, "pixel": true,
		"skills": {
			"basic": {"name": "Đòn thường", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Pink Poison", "cd": 2, "target": "enemy", "hits": [1.6],
				"on_hit": [{"t": "poison", "stacks": 2}], "color": Color(0.8, 0.3, 0.9, 0.6)},
			"s2": {"name": "Poison Absorption", "cd": 4, "target": "enemy_poisoned", "cond": "need_poison",
				"hits": [1.0], "lifesteal": 0.3, "color": Color(0.8, 0.3, 0.9, 0.6)},
			"ult": {"name": "Poison Pink: Venom Storm", "target": "enemy_all", "hits": [2.3],
				"on_hit": [{"t": "poison", "stacks": 2},
					{"t": "mod", "stat": "heal_in", "pct": -0.25, "turns": 2, "label": "Giảm hồi"}],
				"color": Color(0.8, 0.3, 0.9, 0.7)},
		},
	},
	"shanks": {
		"name": "Shanks", "hp": 24000, "atk": 4000, "mag": 1200, "def": 1700, "spd": 14,
		"main": "atk", "crit": 0.30,
		"h": 150, "color": Color(0.8, 0.2, 0.2), "faces_right": true, "pixel": true,
		"skills": {
			"basic": {"name": "Chém thường", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Divine Departure", "cd": 2, "target": "enemy", "hits": [2.2],
				"on_hit": [{"t": "stun", "chance": 0.3, "turns": 1}], "color": Color(1.0, 0.3, 0.3, 0.6)},
			"s2": {"name": "Observation Haki", "cd": 4, "target": "self", "set_next_bonus": 1.0,
				"self_fx": [{"t": "mod", "stat": "evasion", "pct": 0.3, "turns": 2, "label": "Né+30%", "counter": true}],
				"color": Color(1.0, 0.8, 0.3, 0.5)},
			"ult": {"name": "Kamusari", "target": "enemy_all", "hits": [3.5],
				"t_hp_below": {"hp": 0.3, "pct": 0.5},
				"on_hit": [{"t": "fear", "chance": 0.5, "turns": 1}], "color": Color(1.0, 0.2, 0.2, 0.7)},
		},
	},
	"sabo": {
		"name": "Sabo", "hp": 22000, "atk": 1100, "mag": 3700, "def": 1400, "spd": 13,
		"main": "mag", "crit": 0.10,
		"h": 150, "color": Color(0.9, 0.6, 0.2), "faces_right": true, "pixel": true,
		"skills": {
			"basic": {"name": "Đòn thường", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Dragon Claw", "cd": 2, "target": "enemy", "hits": [1.8],
				"on_hit": [{"t": "mod", "stat": "def", "pct": -0.15, "turns": 2, "label": "DEF-15%"}],
				"color": Color(1.0, 0.6, 0.2, 0.6)},
			"s2": {"name": "Fire Fist", "cd": 4, "target": "enemy", "hits": [2.2], "splash": 1.0, "fire": true,
				"on_hit": [{"t": "burn", "chance": 0.4, "turns": 2}], "color": Color(1.0, 0.5, 0.1, 0.7)},
			"ult": {"name": "Mera Mera: Flame Emperor", "target": "enemy_all", "hits": [3.2], "fire": true,
				"flame_bonus": 0.08, "on_hit": [{"t": "burn", "turns": 2}], "color": Color(1.0, 0.4, 0.1, 0.7)},
		},
	},
	"jinbei": {
		"name": "Jinbei", "hp": 38000, "atk": 2000, "mag": 1000, "def": 3500, "spd": 8,
		"main": "atk", "crit": 0.10,
		"h": 140, "color": Color(0.3, 0.5, 0.9), "faces_right": true, "pixel": true,
		"skills": {
			"basic": {"name": "Đòn thường", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Fish-Man Karate", "cd": 2, "target": "enemy", "hits": [1.3],
				"on_hit": [{"t": "mod", "stat": "atk", "pct": -0.15, "turns": 2, "label": "ATK-15%"}],
				"color": Color(0.3, 0.7, 1.0, 0.6)},
			"s2": {"name": "Ocean Current Shoulder Throw", "cd": 4, "target": "self",
				"team_fx": [{"t": "mod", "stat": "taken", "pct": -0.30, "turns": 1, "label": "Giảm ST 30%"}],
				"self_fx": [{"t": "counter", "mult": 0.8, "turns": 1, "label": "Phản công"}],
				"color": Color(0.3, 0.7, 1.0, 0.5)},
			"ult": {"name": "Vagabond Drill", "target": "enemy", "hits": [3.0], "splash": 1.2,
				"shield": {"pct": 0.15, "to": "allies"}, "color": Color(0.3, 0.7, 1.0, 0.7)},
		},
	},
	"ace": {
		"name": "Ace", "hp": 21000, "atk": 1000, "mag": 3900, "def": 1300, "spd": 14,
		"main": "mag", "crit": 0.10,
		"h": 150, "color": Color(1.0, 0.5, 0.1), "faces_right": false, "pixel": true,
		"skills": {
			"basic": {"name": "Đòn thường", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Hiken", "cd": 2, "target": "enemy", "hits": [1.8],
				"on_hit": [{"t": "burn", "turns": 2}], "color": Color(1.0, 0.5, 0.1, 0.6)},
			"s2": {"name": "Flame Mirror", "cd": 4, "target": "self",
				"self_fx": [{"t": "mod", "stat": "mag", "pct": 0.2, "turns": 2, "label": "MAG+20%"},
					{"t": "reflect", "pct": 0.5, "turns": 2, "label": "Phản lửa"}],
				"color": Color(1.0, 0.5, 0.1, 0.5)},
			"ult": {"name": "Dai Enkai: Entei", "target": "enemy", "hits": [4.0], "splash": 1.8,
				"bonus_if": {"if": "burn", "pct": 0.25}, "color": Color(1.0, 0.3, 0.0, 0.7)},
		},
	},
	"kaido": {
		"name": "Kaido", "hp": 48000, "atk": 3300, "mag": 1500, "def": 3800, "spd": 7,
		"main": "atk", "crit": 0.10,
		"h": 185, "color": Color(0.5, 0.3, 0.7), "faces_right": true, "pixel": true,
		"skills": {
			"basic": {"name": "Vung chùy", "target": "enemy", "hits": [1.0]},
			"s1": {"name": "Thunder Bagua", "cd": 2, "target": "enemy", "hits": [2.3],
				"on_hit": [{"t": "stun", "chance": 0.3, "turns": 1}], "color": Color(0.9, 0.9, 0.3, 0.6)},
			"s2": {"name": "Dragon Scales", "cd": 4, "target": "self",
				"shield": {"pct": 0.25, "to": "self"},
				"self_fx": [{"t": "mod", "stat": "def", "pct": 0.25, "turns": 2, "label": "DEF+25%"},
					{"t": "reflect", "pct": 0.5, "turns": 2, "label": "Phản đòn"}],
				"color": Color(0.5, 0.5, 1.0, 0.5)},
			"ult": {"name": "Blast Breath", "target": "enemy_all", "hits": [3.5],
				"self_hp_below": {"hp": 0.5, "pct": 0.3},
				"on_hit": [{"t": "burn", "turns": 2}], "color": Color(1.0, 0.4, 0.1, 0.7)},
		},
	},
}

# Chọn đội hình (đổi id ở đây để thử các đội khác nhau)
var team_a_ids = ["kaido"]
var team_b_ids = ["sabo", "jinbei", "shanks"]

var units: Array = []
var log_lines: Array = []
var log_label: Label
var banner_label: Label
var result_label: Label
var restart_button: Button
var speed_button: Button
var next_uid: int = 0
var current_uid: int = -1
var action_id: int = 0

# =========================
# ULTIMATE CUT-IN
# =========================
var ulti_cutin_layer: CanvasLayer = null
var ulti_cutin_dim: ColorRect = null
var ulti_cutin_root: Node2D = null
var ulti_cutin_panel: Polygon2D = null
var ulti_cutin_glow: Line2D = null
var ulti_cutin_portrait: Polygon2D = null
var ulti_cutin_name: Label = null

const ULT_CUTIN_IN_TIME := 0.18
const ULT_CUTIN_HOLD_TIME := 0.62
const ULT_CUTIN_OUT_TIME := 0.20

func _ready() -> void:
	initialize_character_roster()
	# [META] Nhận đội hình từ sảnh. Nếu chạy battle.tscn trực tiếp (F6) thì dùng đội mặc định ở trên.
	if GameState.pending_battle.has("team_a"):
		team_a_ids = GameState.pending_battle["team_a"].duplicate()
		team_b_ids = GameState.pending_battle["team_b"].duplicate()

	# Giữ tốc độ đã chọn nếu vào từ trận trước; time_scale lỡ kẹt ở mức hit-stop thì về x1
	game_speed = clampi(int(round(Engine.time_scale)), 1, 3)
	Engine.time_scale = float(game_speed)

	build_background()
	build_ui()

	# So nhan vat thuc su tham chien
	var count_a: int = team_a_ids.size()
	var count_b: int = team_b_ids.size()

	if count_a < 1 or count_b < 1:
		push_error("Moi doi phai co it nhat 1 nhan vat!")
		return

	# Tạo đội hình linh hoạt đến 6v6
	for i in range(maxi(count_a, count_b)):
		if i < count_a:
			units.append(
				make_unit(team_a_ids[i], 0, i, count_a)
			)

		if i < count_b:
			units.append(
				make_unit(team_b_ids[i], 1, i, count_b)
			)

	apply_start_passives()

	for u in units:
		refresh_unit(u)

	add_log("Tran dau sap bat dau...")

	await get_tree().create_timer(1.0).timeout
	await run_battle()



# ======================================================================
#  GIAO DIỆN
# ======================================================================
func build_background() -> void:
	var bg = ColorRect.new()
	bg.size = Vector2(1152, 648)
	bg.color = Color(0.12, 0.13, 0.18)
	bg.z_index = -100
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	if ResourceLoader.exists(BACKGROUND_PATH):
		var pic = TextureRect.new()
		pic.texture = load(BACKGROUND_PATH)
		pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		pic.size = Vector2(1152, 648)
		pic.z_index = -99
		pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(pic)
	else:
		var line = ColorRect.new()
		line.size = Vector2(4, 648)
		line.position = Vector2(574, 0)
		line.color = Color(0.25, 0.27, 0.35)
		add_child(line)
		push_warning("Không tìm thấy background.jpg")


func build_ui() -> void:
	var title = Label.new()
	title.text = ("HUẤN LUYỆN %d vs %d" if _is_training() else "AUTO BATTLE %d vs %d") % [
		team_a_ids.size(),
		team_b_ids.size()
	]
	title.position = Vector2(440, 8)
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_constant_override("outline_size", 6)
	add_child(title)

	banner_label = Label.new()
	banner_label.position = Vector2(0, 48)
	banner_label.size = Vector2(1152, 50)
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.add_theme_constant_override("outline_size", 8)
	banner_label.modulate.a = 0.0
	banner_label.z_index = 20
	add_child(banner_label)

	log_label = Label.new()
	log_label.position = Vector2(20, 568)
	log_label.add_theme_font_size_override("font_size", 15)
	log_label.add_theme_constant_override("outline_size", 5)
	add_child(log_label)

	result_label = Label.new()
	result_label.position = Vector2(340, 250)
	result_label.add_theme_font_size_override("font_size", 56)
	result_label.add_theme_constant_override("outline_size", 10)
	result_label.z_index = 30
	result_label.visible = false
	add_child(result_label)

	restart_button = Button.new()
	restart_button.text = "Chơi lại"
	restart_button.size = Vector2(160, 50)
	restart_button.position = Vector2(496, 380)
	restart_button.z_index = 30
	restart_button.visible = false
	restart_button.pressed.connect(func(): get_tree().reload_current_scene())
	add_child(restart_button)

	speed_button = Button.new()
	speed_button.text = "Tốc độ: x%d" % game_speed
	speed_button.size = Vector2(130, 36)
	speed_button.position = Vector2(1000, 8)
	speed_button.z_index = 30
	speed_button.pressed.connect(on_speed_pressed)
	add_child(speed_button)
	if _is_training():
		var leave_button := Button.new()
		leave_button.text = "KẾT THÚC HUẤN LUYỆN"
		leave_button.size = Vector2(180, 36)
		leave_button.position = Vector2(800, 8)
		leave_button.z_index = 30
		leave_button.pressed.connect(_leave_training)
		add_child(leave_button)


var game_speed: int = 1   # toc do nguoi choi chon (1..3), khong bi hit-stop lam sai lech

func on_speed_pressed() -> void:
	game_speed = game_speed % 3 + 1
	# Dang hit-stop thi de hit-stop tu khoi phuc ve game_speed khi xong
	if not hit_stop_active:
		Engine.time_scale = float(game_speed)
	speed_button.text = "Tốc độ: x%d" % game_speed


func add_log(text: String) -> void:
	log_lines.append(text)
	if log_lines.size() > 3:
		log_lines.pop_front()
	log_label.text = "\n".join(log_lines)


func show_banner(u: Dictionary, sk: Dictionary, is_ult: bool) -> void:
	banner_label.text = "%s - %s" % [u["name"], sk["name"]]
	banner_label.add_theme_font_size_override("font_size", 36 if is_ult else 26)
	banner_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2) if is_ult else Color.WHITE)
	banner_label.modulate.a = 1.0
	var tw = create_tween()
	tw.tween_interval(0.9)
	tw.tween_property(banner_label, "modulate:a", 0.0, 0.4)


func float_text(pos: Vector2, text: String, color: Color, size: int = 24) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.modulate = color
	lbl.z_index = 10
	add_child(lbl)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(lbl, "position:y", pos.y - 45, 0.8)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(lbl.queue_free)

func show_slash(a: Dictionary, dir: int, crit: bool) -> void:
	var slash = Line2D.new()

	slash.width = 9.0 if crit else 5.0
	slash.default_color = Color(1, 0.85, 0.1) if crit else Color.WHITE
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	slash.z_index = 15

	var h = float(a["h"])

	slash.points = PackedVector2Array([
		Vector2(-35 * dir, -h * 0.35),
		Vector2(10 * dir, -h * 0.85),
		Vector2(40 * dir, -h * 0.45)
	])

	a["node"].add_child(slash)

	var tw = create_tween()
	tw.tween_property(slash, "modulate:a", 0.0, 0.2)
	tw.tween_callback(slash.queue_free)
	
func start_hit_recoil(t: Dictionary, dir: int, crit: bool) -> void:
	if not t["alive"]:
		return

	var root: Node2D = t["node"] as Node2D
	var body: CanvasItem = t["body"] as CanvasItem

	if root == null or body == null:
		return

	# Hủy phản ứng cũ nếu đang nhận nhiều hit
	var old_recoil = t.get("hit_recoil_tween", null)
	if old_recoil is Tween and old_recoil.is_running():
		old_recoil.kill()

	var old_flash = t.get("hit_flash_tween", null)
	if old_flash is Tween and old_flash.is_running():
		old_flash.kill()

	# Không đẩy vị trí gốc khi nhân vật đang tung chiêu
	# hoặc đã rời đội hình.
	var home: Vector2 = t["home"]
	var can_recoil: bool = (
		root.position.distance_to(home) < 45.0
		and not bool(t.get("casting_animation", false))
	)

	# 1. Giật lùi theo hướng đòn đánh
	if can_recoil:
		var distance: float = 42.0 if crit else 26.0
		var recoil_x: float = home.x + float(dir) * distance
		var rebound_x: float = home.x - float(dir) * 4.0

		var recoil_tw: Tween = create_tween()
		t["hit_recoil_tween"] = recoil_tw

		# Bị đẩy ra sau
		recoil_tw.tween_property(
			root, "position:x", recoil_x,
			0.085 if crit else 0.065
		).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)

		# Bật ngược lại một chút
		recoil_tw.tween_property(
			root, "position:x", rebound_x, 0.09
		).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

		# Trở về vị trí đội hình
		recoil_tw.tween_property(
			root, "position:x", home.x, 0.12
		).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	else:
		t["hit_recoil_tween"] = null

	# 2. Nhấp nháy khi nhận sát thương
	var flash_tw: Tween = create_tween()
	t["hit_flash_tween"] = flash_tw

	body.modulate = Color(1.0, 0.30, 0.30)

	flash_tw.tween_property(
		body, "modulate", Color.WHITE, 0.14
	)

	# 3. Critical có thêm một lần lóe vàng
	if crit:
		flash_tw.tween_property(
			body,
			"modulate",
			Color(1.0, 0.85, 0.35),
			0.045
		)

		flash_tw.tween_property(
			body, "modulate", Color.WHITE, 0.11
	)



func popup_pos(u: Dictionary) -> Vector2:
	return u["node"].position + Vector2(randf_range(-35, 35) - 10, -float(u["h"]) - 15)


func spawn_burst(pos: Vector2, color: Color, radius: float) -> void:
	var b = Burst.new()
	b.position = pos
	b.tint = color
	b.z_index = 5
	add_child(b)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(b, "radius", radius, 0.35)
	tw.tween_property(b, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(b.queue_free)


func burst_on(u: Dictionary, color: Color, radius: float = 60.0) -> void:
	spawn_burst(u["node"].position + Vector2(0, -float(u["h"]) * 0.5), color, radius)


func flash(u: Dictionary, color: Color = Color(1, 0.4, 0.4)) -> void:
	u["body"].modulate = color
	var tw = create_tween()
	tw.tween_property(u["body"], "modulate", Color.WHITE, 0.25)


func shake(u: Dictionary) -> void:
	var base: Vector2 = u["body_base"]
	var tw = create_tween()
	tw.tween_property(u["body"], "position:x", base.x + 10, 0.04)
	tw.tween_property(u["body"], "position:x", base.x - 10, 0.04)
	tw.tween_property(u["body"], "position:x", base.x, 0.04)


# ======================================================================
#  TẠO NHÂN VẬT
# ======================================================================

func make_visual(id: String, d: Dictionary, team: int) -> CanvasItem:
	if id == "training_dummy":
		return make_training_dummy_visual()
	var sprite: AnimatedSprite2D = CHARACTER_ANIMATIONS.create_sprite(
		id,
		GameData.character_display_height(id),
		team
	)
	if sprite != null:
		return sprite
	# Fallback artwork is used only when an animation library is missing.
	var art_path: String = "res://assets/characters_static/%s.png" % id
	if ResourceLoader.exists(art_path):
		var texture := load(art_path) as Texture2D
		if texture != null:
			var still := Sprite2D.new()
			still.name = "StaticCharacterArt_" + id
			still.texture = texture
			still.centered = false
			still.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			still.flip_h = team == 1
			var image_scale: float = GameData.character_display_height(id) / texture.get_height()
			still.scale = Vector2.ONE * image_scale
			still.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
			return still
	# Missing art remains readable as a silhouette placeholder.
	var placeholder := Polygon2D.new()
	placeholder.polygon = PackedVector2Array([
		Vector2(-19, -88), Vector2(19, -88), Vector2(29, -54), Vector2(20, -15),
		Vector2(34, 0), Vector2(22, 5), Vector2(9, -3), Vector2(4, 0),
		Vector2(12, 38), Vector2(7, 48), Vector2(-7, 48), Vector2(-12, 38),
		Vector2(-4, 0), Vector2(-9, -3), Vector2(-22, 5), Vector2(-34, 0),
		Vector2(-20, -15), Vector2(-29, -54),
	])
	placeholder.color = Color(d.get("color", Color("8fa4c8")))
	return placeholder


func make_training_dummy_visual() -> Node2D:
	var dummy := Node2D.new()
	var shadow := Polygon2D.new()
	var shadow_points := PackedVector2Array()
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		shadow_points.append(Vector2(cos(angle) * 38.0, sin(angle) * 7.0 + 2.0))
	shadow.polygon = shadow_points
	shadow.color = Color(0.02, 0.02, 0.04, 0.55)
	dummy.add_child(shadow)
	var post := Polygon2D.new()
	post.polygon = PackedVector2Array([Vector2(-5, -64), Vector2(5, -64), Vector2(7, 0), Vector2(-7, 0)])
	post.color = Color("62452f")
	dummy.add_child(post)
	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([Vector2(-24, -120), Vector2(24, -120), Vector2(30, -65), Vector2(20, -47), Vector2(-20, -47), Vector2(-30, -65)])
	torso.color = Color("b77a3b")
	dummy.add_child(torso)
	var head := Polygon2D.new()
	var head_points := PackedVector2Array()
	for i in range(16):
		var angle := TAU * float(i) / 16.0
		head_points.append(Vector2(cos(angle) * 18.0, sin(angle) * 16.0) + Vector2(0, -137))
	head.polygon = head_points
	head.color = Color("c58e4c")
	dummy.add_child(head)
	var arms := Line2D.new()
	arms.points = PackedVector2Array([Vector2(-43, -107), Vector2(0, -94), Vector2(43, -107)])
	arms.width = 12.0
	arms.default_color = Color("936136")
	dummy.add_child(arms)
	for direction in [-1.0, 1.0]:
		var band := Line2D.new()
		band.points = PackedVector2Array([Vector2(-22, -111 if direction < 0.0 else -57), Vector2(22, -57 if direction < 0.0 else -111)])
		band.width = 5.0
		band.default_color = Color("e0b56a")
		dummy.add_child(band)
	return dummy


func initialize_character_roster() -> void:
	for id in GameData.CHARACTERS:
		if not roster.has(id):
			roster[id] = build_extra_character(id)
		var base: Dictionary = GameData.BASE_STATS[id]
		var secondary: Dictionary = GameData.SECONDARY_STATS[id]
		var entry: Dictionary = roster[id]
		for stat in ["hp", "atk", "mag", "def"]:
			entry[stat] = int(base[stat])
		entry["spd"] = int(secondary["spd"])
		entry["crit"] = float(secondary["crit"])
		entry["crit_dmg"] = float(secondary["crit_dmg"])
		entry["accuracy"] = float(secondary["accuracy"])
		entry["evasion"] = float(secondary["evasion"])
		entry["effect_res"] = float(secondary["effect_res"])
		entry["main"] = "atk" if int(base["atk"]) > int(base["mag"]) else "mag"
		entry["h"] = GameData.character_display_height(id)
		if GameData.SKILL_NAMES.has(id):
			var skill_keys := ["basic", "s1", "s2", "ult"]
			for i in range(skill_keys.size()):
				entry["skills"][skill_keys[i]]["name"] = GameData.SKILL_NAMES[id][i]
		apply_v2_skill_tuning(id, entry["skills"])
	roster["training_dummy"] = {
		"name": "Hình nộm", "hp": 250000, "atk": 0, "mag": 0, "def": 0,
		"spd": 1, "main": "atk", "crit": 0.0, "crit_dmg": 1.0,
		"accuracy": 1.0, "evasion": 0.0, "effect_res": 0.0, "h": 150.0,
		"color": Color("b77a3b"), "faces_right": true, "pixel": true, "skills": {},
	}


func apply_v2_skill_tuning(id: String, skills: Dictionary) -> void:
	# Core multipliers/cooldowns from v2 replace the older prototype values.
	match id:
		"zoro":
			skills["basic"]["hits"] = [0.9]
			skills["s1"]["hits"] = [0.75, 0.75, 0.75]
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 4, "target": "enemy_row", "hits": [1.7], "ignore_def": 0.2, "bonus_if": {"if": "bleed", "pct": 0.2}, "pre_fx": [{"t": "mod", "stat": "crit", "pct": 0.2, "turns": 1, "label": "Crit Rate+20%"}, {"t": "mod", "stat": "crit_dmg", "pct": 2.0, "turns": 1, "label": "Crit Damage+200%"}], "color": Color(0.5, 1.0, 0.6, 0.6)}
			skills["ult"]["target"] = "enemy_low"
			skills["ult"]["hits"] = [1.1, 1.1, 1.1, 1.1, 1.1, 1.1]
			skills["ult"]["force_crit_last"] = true
			skills["ult"]["last_crit_dmg_bonus"] = 2.5
			skills["ult"]["extra_turn_on_kill"] = true
		"chopper":
			skills["basic"]["hits"] = [0.7]
			skills["basic"]["heal_lowest_ally"] = 0.4
			skills["basic"]["heal_lowest_ally_scale"] = "mag"
			skills["s1"] = {"name": GameData.SKILL_NAMES[id][1], "cd": 2, "target": "ally_low_two", "heal": {"pct": 1.2, "scale": "mag"}, "cond": "need_hurt"}
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 3, "target": "ally_all", "shield": {"pct": 0.7, "scale": "mag", "to": "allies"}, "team_fx": [{"t": "mod", "stat": "def", "pct": 0.1, "turns": 1, "label": "DEF+10%"}]}
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "ally_all", "heal": {"pct": 2.3, "scale": "mag", "cleanse": 1}, "team_fx": [{"t": "mod", "stat": "heal_out", "pct": 0.15, "turns": 2, "label": "Hồi phục liên tục"}]}
		"reiju":
			skills["basic"]["hits"] = [0.8]
			skills["basic"]["on_hit"] = [{"t": "poison", "turns": 2, "chance": 0.5, "stacks": 1}]
			skills["s1"] = {"name": GameData.SKILL_NAMES[id][1], "cd": 2, "target": "enemy_front", "hits": [1.2], "on_hit": [{"t": "poison", "turns": 2, "chance": 0.7, "stacks": 1}, {"t": "mod", "stat": "def", "pct": -0.12, "turns": 2, "label": "DEF-12%"}]}
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 3, "target": "enemy_poisoned", "hits": [2.1], "bonus_if": {"if": "poison", "pct": 0.2}, "cond": "need_poison", "detonate_poison": true}
			skills["s2"]["cd"] = 3
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "enemy_all", "hits": [2.1], "on_hit": [{"t": "poison", "turns": 2, "stacks": 1}, {"t": "mod", "stat": "heal_in", "pct": -0.2, "turns": 2, "label": "Giảm hồi phục"}]}
		"marco":
			skills["basic"]["hits"] = [0.7]
			skills["basic"]["heal_lowest_ally"] = 0.7
			skills["basic"]["heal_lowest_ally_scale"] = "mag"
			skills["s1"] = {"name": GameData.SKILL_NAMES[id][1], "cd": 2, "target": "ally_all", "heal": {"pct": 1.2, "scale": "mag"}, "team_fx": [{"t": "mod", "stat": "def", "pct": 0.15, "turns": 2, "label": "DEF+15%"}]}
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 3, "target": "ally_high_atk_and_low_hp", "heal": {"pct": 0.8, "scale": "mag"}, "shield": {"pct": 0.15, "to": "targets"}}
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "ally_all", "heal": {"pct": 3.8, "scale": "mag", "cleanse": 99}, "team_fx": [{"t": "mod", "stat": "def", "pct": 0.1, "turns": 2, "label": "DEF+10%"}]}
		"shanks":
			skills["basic"]["hits"] = [0.9]
			skills["s1"] = {"name": GameData.SKILL_NAMES[id][1], "cd": 2, "target": "enemy", "hits": [2.1], "on_hit": [{"t": "silence", "turns": 1, "chance": 0.4}]}
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 4, "target": "enemy_column", "hits": [1.8], "ignore_def": 0.2, "pre_fx": [{"t": "mod", "stat": "crit_dmg", "pct": 1.6, "turns": 1, "label": "Haki Flash"}]}
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "enemy", "hits": [5.1], "ignore_def": 0.3, "splash": 1.4, "splash_if_kill": true}
		"sabo":
			skills["basic"]["hits"] = [0.8]
			skills["s1"] = {"name": GameData.SKILL_NAMES[id][1], "cd": 2, "target": "enemy_row", "hits": [1.1], "on_hit": [{"t": "burn", "turns": 2, "chance": 0.7}]}
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 3, "target": "enemy_all", "hits": [1.2], "bonus_if": {"if": "burn", "pct": 0.2}}
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "enemy_all", "hits": [2.4], "on_hit": [{"t": "burn", "turns": 2}, {"t": "mod", "stat": "def", "pct": -0.15, "turns": 2, "label": "DEF-15%"}]}
		"jinbei":
			skills["basic"]["hits"] = [0.7]
			skills["s1"]["hits"] = [1.3]
			skills["s1"]["cd"] = 2
			skills["s1"]["on_hit"] = [{"t": "taunt", "turns": 1, "chance": 0.75}]
			skills["s1"]["self_fx"] = [{"t": "mod", "stat": "def", "pct": 0.15, "turns": 2, "label": "DEF+15%"}]
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 3, "target": "ally_all", "shield": {"pct": 0.11, "to": "allies"}, "cleanse_self": true}
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "enemy_all", "hits": [1.55], "on_hit": [{"t": "stun", "chance": 0.5, "turns": 1}], "self_heal": 0.15}
		"ace":
			skills["basic"]["hits"] = [0.8]
			skills["basic"]["on_hit"] = [{"t": "burn", "chance": 0.6, "turns": 2}]
			skills["s1"]["hits"] = [1.8]
			skills["s1"]["target"] = "enemy"
			skills["s1"]["on_hit"] = [{"t": "burn", "chance": 0.75, "turns": 2}]
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 3, "target": "enemy_front", "hits": [1.3], "bonus_if": {"if": "burn", "pct": 0.2}, "ignore_def": 0.15}
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "enemy", "hits": [3.2], "splash": 1.3, "bonus_if": {"if": "burn", "pct": 0.2}}
		"kaido":
			skills["basic"]["hits"] = [0.9]
			skills["s1"] = {"name": GameData.SKILL_NAMES[id][1], "cd": 2, "target": "enemy_all", "hits": [1.1], "on_hit": [{"t": "burn", "chance": 0.6, "turns": 2}]}
			skills["s2"] = {"name": GameData.SKILL_NAMES[id][2], "cd": 3, "target": "self", "shield": {"pct": 0.1, "to": "self"}, "self_fx": [{"t": "mod", "stat": "def", "pct": 0.15, "turns": 2, "label": "Vảy rồng"}]}
			skills["ult"] = {"name": GameData.SKILL_NAMES[id][3], "target": "enemy_all", "hits": [2.0], "on_hit": [{"t": "burn", "turns": 2}], "shield": {"pct": 0.15, "to": "self"}}


func build_extra_character(id: String) -> Dictionary:
	var base: Dictionary = GameData.BASE_STATS[id]
	var secondary: Dictionary = GameData.SECONDARY_STATS[id]
	var names: Array = GameData.SKILL_NAMES[id]
	var main_stat: String = "atk" if int(base["atk"]) > int(base["mag"]) else "mag"
	var accent := Color(0.45, 0.68, 0.88)
	var status: Dictionary = {"t": "stun", "turns": 1, "chance": 0.35}
	if id in ["akainu", "sabo", "ace"]:
		status = {"t": "burn", "turns": 2, "chance": 0.55}
	elif id in ["magellan", "reiju"]:
		status = {"t": "poison", "turns": 2, "chance": 0.65, "stacks": 1}
	elif id == "doflamingo":
		status = {"t": "bleed", "turns": 2, "chance": 0.5}
	var skills := {
		"basic": {"name": names[0], "target": "enemy", "hits": [0.85]},
		"s1": {"name": names[1], "cd": 2, "target": "enemy_all", "hits": [1.05], "on_hit": [status.duplicate()], "color": Color(0.4, 0.8, 1.0, 0.6)},
		"s2": {"name": names[2], "cd": 3, "target": "enemy", "hits": [1.7], "ignore_def": 0.12, "on_hit": [status.duplicate()], "color": Color(0.8, 0.55, 1.0, 0.6)},
		"ult": {"name": names[3], "target": "enemy_all", "hits": [2.25], "on_hit": [status.duplicate()], "color": Color(1.0, 0.55, 0.25, 0.7)},
	}
	if id in ["marco", "chopper", "law", "shirahoshi"]:
		skills["s1"] = {"name": names[1], "cd": 2, "target": "ally_all", "heal": {"pct": 0.10}, "team_fx": [{"t": "mod", "stat": "def", "pct": 0.08, "turns": 2, "label": "DEF+8%"}], "color": Color(0.4, 1.0, 0.65, 0.6)}
		skills["s2"] = {"name": names[2], "cd": 3, "target": "ally_all", "shield": {"pct": 0.08, "to": "allies"}, "color": Color(0.45, 0.8, 1.0, 0.6)}
		skills["ult"] = {"name": names[3], "target": "ally_all", "heal": {"pct": 0.24, "cleanse": 1}, "team_fx": [{"t": "mod", "stat": "def", "pct": 0.12, "turns": 2, "label": "DEF+12%"}], "color": Color(0.5, 1.0, 0.75, 0.7)}
	elif id in ["jinbei", "kaido", "jozu", "sengoku", "kuma"]:
		skills["s2"] = {"name": names[2], "cd": 3, "target": "self", "shield": {"pct": 0.18, "to": "allies"}, "self_fx": [{"t": "mod", "stat": "taken", "pct": -0.1, "turns": 2, "label": "Giảm ST"}], "color": Color(0.45, 0.8, 1.0, 0.6)}
	return {"name": GameData.char_name(id), "hp": base["hp"], "atk": base["atk"], "mag": base["mag"], "def": base["def"], "spd": secondary["spd"], "main": main_stat, "crit": secondary["crit"], "crit_dmg": secondary["crit_dmg"], "accuracy": secondary["accuracy"], "evasion": secondary["evasion"], "effect_res": secondary["effect_res"], "h": 150, "color": accent, "faces_right": true, "pixel": true, "skills": skills}


func formation_position(team: int, slot: int, team_size: int) -> Vector2:
	if team_size > 3:
		var column: int = slot % 3
		var row: int = int(slot / 3)
		var x: float = 118.0 + float(column) * 130.0 if team == 0 else 1034.0 - float(column) * 130.0
		var y: float = 250.0 if row == 0 else 430.0
		return Vector2(x, y)
	var x: float = 235.0 if team == 0 else 920.0
	var y: float = 400.0

	match team_size:
		1:
			y = 400.0
		2:
			y = 310.0 + float(slot) * 175.0
		3:
			y = 215.0 + float(slot) * 150.0

	return Vector2(x, y)

func make_unit(id: String, team: int, slot: int, team_size: int) -> Dictionary:
	var d = roster[id]
	var u = d.duplicate()
	if id == "training_dummy":
		u["name"] = "Hình nộm %d" % (slot + 1)
	# [META] Cộng chỉ số theo số sao (chỉ đội người chơi, chỉ khi vào trận từ sảnh)
	if team == 0 and GameState.pending_battle.has("team_a"):
		var bonus: Dictionary = GameState.character_flat_bonus(id)
		for k in ["hp", "atk", "mag", "def"]:
			u[k] = int(d[k]) + int(bonus.get(k, 0))
	elif team == 1 and GameState.pending_battle.has("enemy_scale"):
		var enemy_scale: float = float(GameState.pending_battle.get("enemy_scale", 1.0))
		for k in ["hp", "atk", "mag", "def"]:
			u[k] = int(round(float(d[k]) * enemy_scale))
	u["h"] = float(d["h"])
	u["id"] = id
	u["uid"] = next_uid
	next_uid += 1
	u["team"] = team
	u["slot"] = slot
	u["max_hp"] = u["hp"]
	u["alive"] = true
	u["fx"] = []
	u["stacks"] = {}
	if id == "zoro":
		u["stacks"]["ashura"] = 1
	u["saved_once"] = false
	u["shield"] = 0
	u["energy"] = 0
	u["cd"] = {"s1": 0, "s2": 2}
	u["extra_turn"] = false
	u["repeat_ult"] = false
	u["ult_repeated"] = false
	u["next_bonus"] = 0.0
	u["passive_count"] = 0
	u["guard_triggered"] = false
	u["phoenix_flames"] = 0
	u["low_flag"] = false
	u["casting_animation"] = false
	u["hit_recoil_tween"] = null
	u["strike_tween"] = null

	var root = Node2D.new()
	root.position = formation_position(team, slot, team_size)
	add_child(root)

	var body = make_visual(id, u, team)
	root.add_child(body)

	var name_label = Label.new()
	name_label.text = u["name"]
	name_label.position = Vector2(-BAR_W / 2, -float(u["h"]) - 26)
	name_label.add_theme_constant_override("outline_size", 5)
	root.add_child(name_label)

	var bar_bg = ColorRect.new()
	bar_bg.size = Vector2(BAR_W, 8)
	bar_bg.position = Vector2(-BAR_W / 2, 6)
	bar_bg.color = Color(0.2, 0.2, 0.2)
	root.add_child(bar_bg)

	var bar = ColorRect.new()
	bar.size = Vector2(BAR_W, 8)
	bar.position = bar_bg.position
	bar.color = Color(0.3, 0.9, 0.3)
	root.add_child(bar)

	var shield_bar = ColorRect.new()
	shield_bar.size = Vector2(0, 3)
	shield_bar.position = Vector2(-BAR_W / 2, 2)
	shield_bar.color = Color(0.6, 0.85, 1.0)
	root.add_child(shield_bar)

	var energy_bar = ColorRect.new()
	energy_bar.size = Vector2(0, 4)
	energy_bar.position = Vector2(-BAR_W / 2, 16)
	energy_bar.color = Color(1.0, 0.8, 0.2)
	root.add_child(energy_bar)

	var status_label = Label.new()
	status_label.size = Vector2(BAR_W * 2, 16)
	status_label.position = Vector2(-BAR_W, 21)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 12)
	status_label.add_theme_constant_override("outline_size", 4)
	root.add_child(status_label)

	u["node"] = root
	u["body"] = body
	u["body_base"] = body.position
	u["bar"] = bar
	u["shield_bar"] = shield_bar
	u["energy_bar"] = energy_bar
	u["status_label"] = status_label
	u["home"] = root.position
	return u


func refresh_unit(u: Dictionary) -> void:
	u["bar"].size.x = BAR_W * float(u["hp"]) / float(u["max_hp"])
	u["shield_bar"].size.x = BAR_W * minf(1.0, float(u["shield"]) / float(u["max_hp"]))
	u["energy_bar"].size.x = BAR_W * float(u["energy"]) / 100.0
	if not u["alive"]:
		u["status_label"].text = ""
		return
	var parts = []
	for f in u["fx"]:
		if f.get("hidden", false):
			continue
		if f["t"] == "poison":
			parts.append("Độc x%d" % f["stacks"])
		else:
			parts.append(str(f.get("label", f["t"])))
	for k in u["stacks"]:
		if u["stacks"][k] > 0:
			parts.append("%s x%d" % [STACK_NAMES.get(k, k), u["stacks"][k]])
	if u["shield"] > 0:
		parts.append("Khiên")
	u["status_label"].text = " ".join(parts)


func refresh_all() -> void:
	for u in units:
		refresh_unit(u)


# ======================================================================
#  TIỆN ÍCH
# ======================================================================
func hp_frac(u: Dictionary) -> float:
	return float(u["hp"]) / float(u["max_hp"])


func stack(u: Dictionary, key: String) -> int:
	return int(u["stacks"].get(key, 0))


func alive_units(team: int) -> Array:
	return units.filter(func(x): return x["alive"] and x["team"] == team)


func team_alive(team: int) -> int:
	return alive_units(team).size()


func has_fx(u: Dictionary, kind: String) -> bool:
	for f in u["fx"]:
		if f["t"] == kind:
			return true
	return false


func fx_sum(u: Dictionary, stat: String) -> float:
	var s = 0.0
	for f in u["fx"]:
		if f["t"] == "mod" and f["stat"] == stat:
			s += float(f["pct"])
	return s


func is_negative(f: Dictionary) -> bool:
	var k = f["t"]
	if k == "bleed" or k == "burn" or k == "poison" or k == "stun" or k == "taunt":
		return true
	if k == "mod":
		var p = float(f["pct"])
		if f["stat"] == "taken" or f["stat"] == "taken_phys":
			return p > 0.0
		return p < 0.0
	return false


# Chỉ số thực tế = chỉ số gốc + hiệu ứng + nội tại
func get_stat(u: Dictionary, stat: String) -> float:
	var pct = fx_sum(u, stat)
	var lost = 1.0 - hp_frac(u)
	var lost_steps = int(floor(lost / 0.1 + 0.0001))   # mỗi 10% HP đã mất
	if u["id"] == "zoro" and stat == "atk":
		pct += 0.05 * stack(u, "ashura")
	elif u["id"] == "zoro" and stat == "def":
		pct += 0.03 * stack(u, "ashura")
	elif u["id"] == "sabo" and stat == "mag":
		pct += 0.04 * stack(u, "flame")
	elif u["id"] == "jinbei" and stat == "def":
		pct += 0.05 * stack(u, "water")
	elif u["id"] == "ace" and stat == "mag":
		pct += 0.03 * mini(5, lost_steps)
	elif u["id"] == "kaido" and stat == "atk":
		pct += 0.04 * lost_steps
		if hp_frac(u) < 0.3:
			pct += 0.2
	return float(u[stat]) * maxf(0.1, 1.0 + pct)


func lowest_hp(list: Array) -> Dictionary:
	var best = list[0]
	for x in list:
		if x["hp"] < best["hp"]:
			best = x
	return best


func lowest_ratio(list: Array) -> Dictionary:
	var best = list[0]
	for x in list:
		if hp_frac(x) < hp_frac(best):
			best = x
	return best


func pick_enemy(enemies: Array, random_pick: bool) -> Dictionary:
	if random_pick:
		return enemies.pick_random()
	return lowest_hp(enemies)


func move_to(u: Dictionary, pos: Vector2, t: float) -> void:
	var tw = create_tween()
	tw.tween_property(u["node"], "position", pos, t).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


# Xác định skill ảnh hưởng nhiều đối tượng (kể cả skill có target="enemy"
# nhưng thêm splash, ví dụ Entei của Ace và Vagabond Drill của Jinbei).
func cast_is_area(sk: Dictionary, targets: Array) -> bool:
	var target_type: String = str(sk.get("target", "enemy"))
	if target_type in ["enemy_all", "ally_all", "enemy_row", "enemy_column", "enemy_front", "enemy_back", "ally_low_two", "ally_high_atk_and_low_hp"]:
		return true
	if sk.has("splash"):
		return true
	if target_type == "enemy_poisoned" and targets.size() > 1:
		return true
	return false


# Target đơn => tiến sát người được chọn; AoE và self-buff => giữa sân.
# Ally đơn => tiến gần đồng đội về phía giữa sân, tránh chạy ra ngoài viewport.

func cast_destination(u: Dictionary, sk: Dictionary, targets: Array) -> Vector2:
	var target_type: String = str(sk.get("target", "enemy"))

	# Tat ca ky nang hoi mau deu ra giua san
	# Nguoi duoc hoi mau van do AI lua chon
	if sk.has("heal"):
		return ARENA_CAST_CENTER

	# AoE, buff ban than va buff ca doi ra giua san
	if cast_is_area(sk, targets) or target_type == "self":
		return ARENA_CAST_CENTER

	if targets.is_empty():
		return u["home"]

	var target: Dictionary = targets[0]

	# Ky nang don muc tieu nhung chon chinh minh
	if int(target["uid"]) == int(u["uid"]):
		return ARENA_CAST_CENTER

	var side: float = 1.0 if int(u["team"]) == 0 else -1.0

	var gap: float = clampf(
		(float(u["h"]) + float(target["h"])) * 0.40,
		CAST_SINGLE_GAP_MIN,
		CAST_SINGLE_GAP_MAX
	)

	var target_position: Vector2 = target["node"].position

	# Ho tro don muc tieu khac (neu co)
	if target_type == "ally_low":
		return target_position + Vector2(side * gap, 0.0)

	# Don tan cong: ap sat doi thu
	return target_position - Vector2(side * gap, 0.0)


func cast_motion_profile(u: Dictionary, sk: Dictionary, key: String, targets: Array) -> Dictionary:
	var motion: Dictionary = MOTION_DEFAULT.duplicate()
	if MOTION_SPECIAL.has(u["id"]):
		motion.merge(MOTION_SPECIAL[u["id"]], true)
	var is_area: bool = cast_is_area(sk, targets) or str(sk.get("target", "")) == "self"
	var is_support: bool = not sk.has("hits")
	motion["is_area"] = is_area
	motion["is_support"] = is_support
	motion["afterimage"] = (u["id"] == "zoro" or u["id"] == "shanks") and not is_support and not is_area
	if is_area or is_support:
		# AoE and buffs move into the arena deliberately rather than dashing
		# all the way into an enemy formation.
		motion["speed"] = minf(float(motion["speed"]), 1250.0)
		motion["pullback"] = float(motion["pullback"]) * 0.50
		motion["backstep"] = float(motion["backstep"]) * 0.55
	if key == "basic":
		motion["windup"] = 0.06
		motion["hit_push"] = 8.0
		motion["afterimage"] = false
	return motion


func cast_windup(u: Dictionary, motion: Dictionary) -> void:
	if not u["alive"]:
		return
	var body: Node2D = u["body"] as Node2D
	if body == null:
		return
	var facing: float = 1.0 if int(u["team"]) == 0 else -1.0
	var body_home: Vector2 = u["body_base"]
	var duration: float = float(motion["windup"])
	var pullback: float = float(motion["pullback"])
	# Do not modify Sprite2D.scale: all animations retain the same apparent size.
	var tw := create_tween()
	tw.tween_property(body, "position", body_home + Vector2(-facing * pullback, 3.0), duration * 0.62).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "position", body_home, duration * 0.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tw.finished


func cast_dash_afterimage(u: Dictionary) -> void:
	var sprite: AnimatedSprite2D = u["body"] as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var ghost := Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.centered = sprite.centered
	ghost.offset = sprite.offset
	ghost.flip_h = sprite.flip_h
	ghost.scale = sprite.scale
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ghost.modulate = Color(0.76, 0.9, 1.0, 0.34) if u["id"] == "zoro" else Color(1.0, 0.52, 0.58, 0.34)
	ghost.z_index = 4
	add_child(ghost)
	ghost.global_position = sprite.global_position
	var tw := create_tween()
	tw.tween_property(ghost, "modulate:a", 0.0, 0.19)
	tw.tween_callback(ghost.queue_free)


func cast_approach(u: Dictionary, destination: Vector2, motion: Dictionary) -> void:
	if not u["alive"]:
		return
	# A previous hit may still be finishing its short recoil tween.
	# Cancel it before starting this unit's own movement.
	var recoil = u.get("hit_recoil_tween", null)
	if recoil is Tween and recoil.is_running():
		recoil.kill()
		var root: Node2D = u["node"] as Node2D
		var formation: Vector2 = u["home"]
		if root != null:
			root.position.x = formation.x
	await cast_windup(u, motion)
	if not u["alive"]:
		return
	var current: Vector2 = u["node"].position
	var distance: float = current.distance_to(destination)
	if distance < 2.0:
		return
	var speed: float = float(motion["speed"])
	var duration: float = clampf(distance / speed, 0.10, 0.55)
	if bool(motion["afterimage"]):	
		cast_dash_afterimage(u)
	var tw := create_tween()
	var transition: Tween.TransitionType = Tween.TRANS_QUART
	var ease_type: Tween.EaseType = Tween.EASE_OUT
	if u["id"] == "kaido":
		transition = Tween.TRANS_QUAD
		ease_type = Tween.EASE_IN_OUT
	elif bool(motion["is_support"]):
		transition = Tween.TRANS_SINE
		ease_type = Tween.EASE_IN_OUT
	tw.tween_property(u["node"], "position", destination, duration).set_trans(transition).set_ease(ease_type)
	await tw.finished


func cast_strike_motion(u: Dictionary, motion: Dictionary) -> void:
	if not u["alive"]:
		return
	var body: Node2D = u["body"] as Node2D
	if body == null:
		return
	var facing: float = 1.0 if int(u["team"]) == 0 else -1.0
	var body_home: Vector2 = u["body_base"]
	var dx: float = float(motion["hit_push"])
	if bool(motion["is_area"]) or bool(motion["is_support"]):
		dx *= 0.40
	# The damage occurs at the peak of the strike, while the body continues
	# to ease back. Cancel any earlier motion on the next hit in a combo.
	var previous = u.get("strike_tween", null)
	if previous is Tween and previous.is_running():
		previous.kill()
	body.position = body_home
	var tw := create_tween()
	u["strike_tween"] = tw
	tw.tween_property(body, "position", body_home + Vector2(facing * dx, -4.0), 0.045).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(body, "position", body_home, 0.078).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await get_tree().create_timer(0.045).timeout


func cast_recover(u: Dictionary, home: Vector2, motion: Dictionary) -> void:
	if not u["alive"]:
		return
	var node: Node2D = u["node"]
	var body: Node2D = u["body"] as Node2D
	var strike = u.get("strike_tween", null)
	if strike is Tween and strike.is_running():
		strike.kill()
	if body != null:
		body.position = u["body_base"]
	var distance: float = node.position.distance_to(home)
	if distance < 2.0:
		node.position = home
		return
	# Fast swordsmen spring backwards, while Kaido takes one heavy retreating
	# step before returning to formation. All end at the exact saved home.
	var facing: float = 1.0 if int(u["team"]) == 0 else -1.0
	var backstep: float = float(motion["backstep"])
	var hop_target: Vector2 = node.position + Vector2(-facing * backstep, -5.0)
	var duration: float = clampf(distance / float(motion["return_speed"]), 0.16, 0.58)
	var tw := create_tween()
	tw.tween_property(node, "position", hop_target, 0.11 if u["id"] != "kaido" else 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "position", home, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	node.position = home


# ======================================================================
#  HIỆU ỨNG TRẠNG THÁI
# ======================================================================
func add_fx(t: Dictionary, fx: Dictionary) -> void:
	var turns = int(fx["turns"])
	if t["uid"] == current_uid:
		turns += 1   # buff tự thêm lên mình trong lượt của mình: tính từ lượt kế
	fx["turns"] = turns
	var key = str(fx["t"]) + str(fx.get("stat", "")) + str(fx.get("label", ""))
	fx["key"] = key
	for f in t["fx"]:
		if f["key"] == key:
			f["turns"] = maxi(int(f["turns"]), turns)
			if fx.has("dmg"):
				f["dmg"] = maxi(int(f["dmg"]), int(fx["dmg"]))
			if fx.has("pct"):
				f["pct"] = fx["pct"]
			return
	t["fx"].append(fx)


func apply_poison(a: Dictionary, t: Dictionary, n: int) -> void:
	var cap_pct: float = 0.75 if a["id"] == "reiju" else 0.60
	var dmg: int = int(minf(float(t["max_hp"]) * 0.04, float(get_stat(a, "mag")) * cap_pct))
	var extra = 1 if t["uid"] == current_uid else 0
	for f in t["fx"]:
		if f["t"] == "poison":
			f["stacks"] = mini(3, int(f["stacks"]) + n)
			f["turns"] = 2 + extra
			f["dmg"] = maxi(int(f["dmg"]), dmg)
			float_text(popup_pos(t), "Độc x%d" % f["stacks"], Color(0.8, 0.4, 1.0), 18)
			return
	t["fx"].append({"t": "poison", "stacks": mini(3, n), "turns": 2 + extra, "dmg": dmg,
		"label": "Độc", "key": "poison"})
	float_text(popup_pos(t), "Độc x%d" % mini(3, n), Color(0.8, 0.4, 1.0), 18)


func apply_status(a: Dictionary, t: Dictionary, st: Dictionary) -> void:
	if not t["alive"]:
		return
	if st.has("chance"):
		var hit_chance: float = clampf(float(st["chance"]) + float(a.get("accuracy", 0.0)) - float(t.get("effect_res", 0.0)), 0.05, 0.95)
		if randf() > hit_chance:
			return
	var kind = st["t"]
	if kind == "bleed" or kind == "burn":
		if kind == "burn" and t["id"] in ["marco", "sabo", "ace", "akainu"]:
			float_text(popup_pos(t), "Miễn nhiễm Burn", Color(1, 0.7, 0.3), 18)
			return
		var dmg: int
		if kind == "bleed":
			dmg = int(float(t["max_hp"]) * 0.05)
		else:
			dmg = int(get_stat(a, a["main"]) * float(st.get("pct", BURN_PCT)))
		var label = "Chảy máu" if kind == "bleed" else "Thiêu đốt"
		add_fx(t, {"t": kind, "turns": st["turns"], "dmg": dmg, "label": label})
		float_text(popup_pos(t), label, Color(1, 0.5, 0.3), 18)
	elif kind == "poison":
		if t["id"] in ["reiju", "magellan"]:
			float_text(popup_pos(t), "Miễn nhiễm Độc", Color(1, 0.7, 0.3), 18)
			return
		apply_poison(a, t, int(st["stacks"]))
	elif kind == "stun":
		add_fx(t, {"t": "stun", "turns": st["turns"], "label": "Choáng"})
		float_text(popup_pos(t), "Choáng!", Color(1, 1, 0.3), 22)
	elif kind == "taunt":
		add_fx(t, {"t": "taunt", "turns": st["turns"], "source_uid": a["uid"], "label": "Khiêu khích"})
		float_text(popup_pos(t), "Khiêu khích!", Color(1.0, 0.65, 0.35), 20)
	elif kind == "fear":
		add_fx(t, {"t": "mod", "stat": "dealt", "pct": -FEAR_PCT, "turns": st["turns"], "label": "Sợ hãi"})
		float_text(popup_pos(t), "Sợ hãi!", Color(0.8, 0.6, 1.0), 22)
	else:
		add_fx(t, st.duplicate())   # mod, reflect, counter...


func cleanse(t: Dictionary, n: int) -> void:
	var removed = 0
	var i = 0
	while removed < n and i < t["fx"].size():
		if is_negative(t["fx"][i]):
			t["fx"].remove_at(i)
			removed += 1
		else:
			i += 1
	if removed > 0:
		float_text(popup_pos(t), "Giải hiệu ứng", Color(0.7, 1, 0.9), 18)


func heal_unit(src: Dictionary, t: Dictionary, amount: float) -> int:
	if not t["alive"]:
		return 0
	var passive_heal_bonus: float = 0.2 if src["id"] == "marco" else 0.12 if src["id"] == "chopper" else 0.15 if src["id"] == "shirahoshi" else 0.0
	var amt = amount * (1.0 + passive_heal_bonus + fx_sum(src, "heal_out")) * maxf(0.0, 1.0 + fx_sum(t, "heal_in"))
	var gained = mini(int(amt), t["max_hp"] - t["hp"])
	t["hp"] += gained
	refresh_unit(t)
	float_text(popup_pos(t), "+%d" % gained, Color(0.4, 1.0, 0.5), 24)
	return gained


func add_shield(t: Dictionary, amount: int) -> void:
	if not t["alive"]:
		return
	t["shield"] += amount
	refresh_unit(t)
	float_text(popup_pos(t), "Khiên +%d" % amount, Color(0.6, 0.85, 1.0), 20)


# ======================================================================
#  SÁT THƯƠNG
# ======================================================================
func apply_damage(t: Dictionary, amount: int, ignore_shield: bool) -> void:
	var rem = amount
	if not ignore_shield and t["shield"] > 0:
		var absorbed = mini(t["shield"], rem)
		t["shield"] -= absorbed
		rem -= absorbed
	if rem > 0 and t["id"] == "zoro":
		t["stacks"]["ashura"] = mini(3, stack(t, "ashura") + 1)
		if t["stacks"]["ashura"] > 1:
			float_text(popup_pos(t), "Ý chí x%d" % t["stacks"]["ashura"], Color(0.5, 1.0, 0.6), 16)
	if rem > 0 and t["id"] == "marco" and int(t.get("phoenix_flames", 0)) > 0:
		t["phoenix_flames"] -= 1
		var phoenix_heal: int = int(round(float(rem) * 0.08))
		rem = 0
		heal_unit(t, t, phoenix_heal)
		float_text(popup_pos(t), "Phoenix Flame", Color(0.4, 0.9, 1.0), 18)
	if rem >= int(t["hp"]) and t["id"] == "zoro" and not t.get("saved_once", false):
		t["saved_once"] = true
		rem = maxi(0, int(t["hp"]) - 1)
		t["energy"] = mini(100, int(t["energy"]) + 50)
		cleanse(t, 99)
		add_log("Zoro kích hoạt Unbreakable Will, giữ lại 1 HP!")
	t["hp"] = maxi(0, t["hp"] - rem)
	if _is_training() and t["id"] == "training_dummy" and t["hp"] <= 0:
		t["hp"] = t["max_hp"]
		t["shield"] = 0
		t["fx"].clear()
		t["stacks"].clear()
		refresh_unit(t)
		return
	if t["hp"] <= 0 and t["alive"]:
		t["alive"] = false  # Quan trọng: loại khỏi đội sống và không chọn làm mục tiêu nữa.
		animate_death(t)
	refresh_unit(t)


func animate_death(t: Dictionary) -> void:
	var node = t["node"]

	var tw = create_tween()
	tw.set_parallel(true)

	tw.tween_property(
		node,
		"modulate:a",
		0.0,
		0.6
	)

	tw.tween_property(
		node,
		"rotation",
		deg_to_rad(15),
		0.6
	)

	tw.tween_property(
		node,
		"position:y",
		node.position.y + 35,
		0.6
	)

	tw.tween_property(
		node,
		"scale",
		Vector2(0.7, 0.7),
		0.6
	)

	tw.chain().tween_callback(func():
		node.visible = false
	)


func on_crit(a: Dictionary) -> void:
	if a["id"] == "shanks":
		a["stacks"]["haki"] = mini(4, stack(a, "haki") + 1)
		float_text(popup_pos(a), "Haki x%d" % stack(a, "haki"), Color(1, 0.4, 0.4), 16)


# a đánh t. stat_key: "atk" hoặc "mag". opts: {"extra": true} = đòn phụ (phản đòn...), không né/chí mạng/kích nội tại
func deal_damage(a: Dictionary, t: Dictionary, stat_key: String, mult: float, ign: float, opts: Dictionary) -> int:
	if not t["alive"]:
		return 0
	var is_extra = opts.get("extra", false)

	# Né tránh
	if not is_extra:
		var ev: float = clampf(float(t.get("evasion", 0.0)) + fx_sum(t, "evasion") - float(a.get("accuracy", 0.0)), 0.0, 0.8)
		if ev > 0.0 and randf() < ev:
			float_text(popup_pos(t), "NÉ!", Color(0.6, 0.9, 1.0), 26)
			try_dodge_counter(t, a)
			return 0

	var power = get_stat(a, stat_key) * mult
	var def_eff = get_stat(t, "def") * (1.0 - clampf(ign, 0.0, 0.9))
	var dmg = power * (1.0 - def_eff / (def_eff + 4000.0))
	var dealt = 1.0 + fx_sum(a, "dealt") + 0.05 * stack(a, "haki")
	var taken = 1.0 + fx_sum(t, "taken")
	if stat_key == "atk":
		taken += fx_sum(t, "taken_phys")
	dmg *= maxf(dealt, 0.1) * maxf(taken, 0.1)

	var crit = false
	var crit_chance: float = clampf(float(a["crit"]) + fx_sum(a, "crit"), 0.0, 1.0)
	if bool(opts.get("force_crit", false)) or randf() < crit_chance:
		crit = true
		dmg *= maxf(1.0, float(a.get("crit_dmg", 1.5)) + fx_sum(a, "crit_dmg") + float(opts.get("crit_dmg_bonus", 0.0)))
		on_crit(a)

	# Hiệu ứng chém kiếm ở người ra đòn (đòn phép dùng VFX riêng tại mục tiêu).
	if not is_extra and a["main"] == "atk" and not a.get("casting_animation", false):
		var dir = 1 if a["team"] == 0 else -1
		show_slash(a, dir, crit)
	dmg *= randf_range(0.95, 1.05)
	var final_dmg = maxi(1, int(dmg))

	apply_damage(t, final_dmg, false)
	float_text(popup_pos(t), str(final_dmg) + (" !" if crit else ""),
		Color(1, 0.9, 0.2) if crit else Color.WHITE, 34 if crit else 24)
	
	
	# Phản ứng nhận sát thương
	if not is_extra and t["alive"]:
		var dir: int = 1 if a["team"] == 0 else -1
		start_hit_recoil(t, dir, crit)
	else:
		# Phản đòn hoặc đòn kết liễu: chỉ nhấp nháy
		flash(t)

	t["energy"] = mini(100, t["energy"] + 10)
	refresh_unit(t)

	if not is_extra:
		react_to_hit(a, t, final_dmg)
	return final_dmg


# Phản ứng sau khi t bị a đánh trúng
func react_to_hit(a: Dictionary, t: Dictionary, dmg: int) -> void:
	# Reiju: 25% gây độc khi đánh trúng
	if a["id"] == "reiju" and t["alive"] and randf() < 0.25:
		apply_poison(a, t, 1)
	if not t["alive"]:
		return
	# Jinbei: 20% nhận 1 tầng Water Guard khi bị đánh
	if t["id"] == "jinbei" and randf() < 0.2:
		t["stacks"]["water"] = mini(3, stack(t, "water") + 1)
		float_text(popup_pos(t), "Water Guard x%d" % stack(t, "water"), Color(0.4, 0.8, 1.0), 16)
	for f in t["fx"].duplicate():
		if not a["alive"]:
			break
		if f["t"] == "reflect":
			var rd = int(dmg * float(f["pct"]))
			if rd > 0:
				apply_damage(a, rd, false)
				float_text(popup_pos(a), str(rd), Color(1, 0.5, 0.2), 20)
				flash(a, Color(1, 0.6, 0.2))
		elif f["t"] == "counter" and int(f.get("last", -1)) != action_id:
			f["last"] = action_id
			float_text(popup_pos(t), "Phản công!", Color(0.5, 0.9, 1.0), 22)
			deal_damage(t, a, "atk", float(f["mult"]), 0.0, {"extra": true})


# Shanks né thành công -> phản công
func try_dodge_counter(t: Dictionary, a: Dictionary) -> void:
	for f in t["fx"]:
		if f["t"] == "mod" and f.get("counter", false) and int(f.get("last", -1)) != action_id and a["alive"]:
			f["last"] = action_id
			float_text(popup_pos(t), "Phản công!", Color(1, 0.8, 0.3), 22)
			deal_damage(t, a, "atk", 1.0, 0.0, {"extra": true})
			break


func skill_mult(u: Dictionary, t: Dictionary, sk: Dictionary, base: float) -> float:
	var m = base
	if sk.has("bonus_if") and has_fx(t, sk["bonus_if"]["if"]):
		m *= 1.0 + float(sk["bonus_if"]["pct"])
	if sk.has("t_hp_below") and hp_frac(t) < float(sk["t_hp_below"]["hp"]):
		m *= 1.0 + float(sk["t_hp_below"]["pct"])
	if sk.has("self_hp_below") and hp_frac(u) < float(sk["self_hp_below"]["hp"]):
		m *= 1.0 + float(sk["self_hp_below"]["pct"])
	if sk.has("flame_bonus"):
		m *= 1.0 + float(sk["flame_bonus"]) * stack(u, "flame")
	return m


# ======================================================================
#  VÒNG LẶP TRẬN ĐẤU
# ======================================================================
func apply_start_passives() -> void:
	for u in units:
		if u["id"] == "kaido":
			add_fx(u, {"t": "mod", "stat": "taken", "pct": -0.2, "turns": 999, "hidden": true, "label": "Kaido"})
		elif u["id"] == "jinbei":
			add_fx(u, {"t": "mod", "stat": "taken_phys", "pct": -0.15, "turns": 999, "hidden": true, "label": "Jinbei"})
		elif u["id"] == "shanks":
			add_log("Haki Bá Vương của Shanks làm đối thủ run sợ!")
			for e in units:
				if e["team"] != u["team"]:
					add_fx(e, {"t": "mod", "stat": "atk", "pct": -0.1, "turns": 1, "label": "ATK-10%"})


func run_battle() -> void:
	var round_num = 1
	while round_num <= MAX_ROUNDS or _is_training():
		add_log("--- Lượt %d ---" % round_num)
		var order = units.filter(func(x): return x["alive"])
		order.sort_custom(func(a, b): return a["spd"] > b["spd"])
		for u in order:
			if not u["alive"]:
				continue
			if team_alive(0) == 0 or team_alive(1) == 0:
				break
			await take_turn(u)
			if check_end():
				return
		round_num += 1
	result_label.text = "HÒA!"
	result_label.visible = true
	restart_button.visible = true
	if GameState.pending_battle.has("team_a"):
		show_battle_rewards("draw")


func take_turn(u: Dictionary) -> void:
	if _is_training() and int(u["team"]) == 1:
		await get_tree().create_timer(0.2).timeout
		return
	current_uid = u["uid"]
	if u["id"] == "marco":
		u["phoenix_flames"] = mini(3, int(u.get("phoenix_flames", 0)) + 1)
	if team_alive(1 - u["team"]) == 0:
		return
	u["energy"] = mini(100, u["energy"] + 25)
	for k in ["s1", "s2"]:
		if u["cd"][k] > 0:
			u["cd"][k] -= 1
	tick_dots(u)
	if not u["alive"]:
		passive_checks()
		return
	refresh_unit(u)

	if has_fx(u, "stun"):
		float_text(popup_pos(u), "Choáng!", Color(1, 1, 0.3), 28)
		add_log("%s bị choáng, mất lượt!" % u["name"])
		await get_tree().create_timer(0.6).timeout
		end_turn(u)
		return

	await perform(u, choose_action(u))
	if u["alive"] and u["extra_turn"] and team_alive(1 - u["team"]) > 0:
		u["extra_turn"] = false
		add_log("%s nhận thêm một lượt!" % u["name"])
		await get_tree().create_timer(0.4).timeout
		if u.get("repeat_ult", false):
			await perform(u, "ult")
		else:
			await perform(u, choose_action(u))
	u["extra_turn"] = false
	end_turn(u)


func end_turn(u: Dictionary) -> void:
	var keep = []
	for f in u["fx"]:
		f["turns"] = int(f["turns"]) - 1
		if f["turns"] > 0:
			keep.append(f)
	u["fx"] = keep
	refresh_unit(u)
	current_uid = -1


func tick_dots(u: Dictionary) -> void:
	for f in u["fx"].duplicate():
		if f["t"] == "bleed" or f["t"] == "burn" or f["t"] == "poison":
			var dmg = int(f["dmg"]) * int(f.get("stacks", 1))
			apply_damage(u, dmg, true)
			var col = Color(1, 0.4, 0.4)
			if f["t"] == "burn":
				col = Color(1, 0.6, 0.2)
			elif f["t"] == "poison":
				col = Color(0.8, 0.4, 1.0)
			float_text(popup_pos(u), str(dmg), col, 20)
			flash(u, col)
			if not u["alive"]:
				return


func skill_ok(u: Dictionary, sk: Dictionary) -> bool:
	var cond = sk.get("cond", "")
	if cond == "need_poison":
		for e in alive_units(1 - u["team"]):
			if has_fx(e, "poison"):
				return true
		return false
	if cond == "need_hurt":
		for a in alive_units(u["team"]):
			if hp_frac(a) < 0.9:
				return true
			for f in a["fx"]:
				if is_negative(f):
					return true
		return false
	return true


func choose_action(u: Dictionary) -> String:
	var sk = u["skills"]
	if has_fx(u, "silence"):
		return "basic"
	if u["energy"] >= 100 and skill_ok(u, sk["ult"]):
		return "ult"
	if u["cd"]["s2"] == 0 and skill_ok(u, sk["s2"]):
		return "s2"
	if u["cd"]["s1"] == 0 and skill_ok(u, sk["s1"]):
		return "s1"
	return "basic"


func perform(u: Dictionary, key: String) -> void:
	var sk = u["skills"][key]
	u["repeat_ult_scale"] = 0.3 if key == "ult" and u.get("repeat_ult", false) else 1.0
	if key == "ult" and u.get("repeat_ult", false):
		u["repeat_ult"] = false
	action_id += 1
	if key == "s1" or key == "s2":
		u["cd"][key] = sk["cd"]
	if key == "ult":
		u["energy"] = 0
		refresh_unit(u)
	if key != "basic":
		show_banner(u, sk, key == "ult")
		add_log("%s dùng %s" % [u["name"], sk["name"]])
		await get_tree().create_timer(0.8 if key == "ult" else 0.5).timeout
	await cast(u, key)
	passive_checks()
	refresh_all()

func cast(u: Dictionary, key: String) -> void:
	var sk = u["skills"][key]
	var enemies = alive_units(1 - u["team"])
	var allies = alive_units(u["team"])
	var tgt = sk.get("target", "enemy")
	var main = {}
	var targets = []

	if tgt == "enemy":
		if enemies.is_empty():
			return
		main = pick_enemy(enemies, key == "basic")
		for fx in u["fx"]:
			if fx["t"] == "taunt":
				for enemy in enemies:
					if int(enemy["uid"]) == int(fx.get("source_uid", -1)):
						main = enemy
						break
		targets = [main]
	elif tgt == "enemy_all":
		targets = enemies.duplicate()
	elif tgt == "enemy_front" or tgt == "enemy_back":
		var wanted_row: int = 0 if tgt == "enemy_front" else 1
		for e in enemies:
			if floori(float(int(e.get("slot", 0))) / 3.0) == wanted_row:
				targets.append(e)
		if targets.is_empty():
			targets = enemies.duplicate()
	elif tgt == "enemy_row" or tgt == "enemy_column":
		if enemies.is_empty():
			return
		main = lowest_hp(enemies)
		for e in enemies:
			var same_axis: bool = floori(float(int(e.get("slot", 0))) / 3.0) == floori(float(int(main.get("slot", 0))) / 3.0) if tgt == "enemy_row" else int(e.get("slot", 0)) % 3 == int(main.get("slot", 0)) % 3
			if same_axis:
				targets.append(e)
	elif tgt == "enemy_high_atk":
		main = enemies[0]
		for e in enemies:
			if get_stat(e, "atk") > get_stat(main, "atk"):
				main = e
		targets = [main]
	elif tgt == "enemy_low":
		main = lowest_ratio(enemies)
		targets = [main]
	elif tgt == "enemy_poisoned":
		var most_poisoned: Dictionary = {}
		var highest_stacks: int = -1
		for e in enemies:
			for effect in e["fx"]:
				if effect["t"] == "poison" and int(effect.get("stacks", 1)) > highest_stacks:
					most_poisoned = e
					highest_stacks = int(effect.get("stacks", 1))
		if not most_poisoned.is_empty():
			main = most_poisoned
			targets = [main]
	elif tgt == "ally_low":
		main = lowest_ratio(allies)
		targets = [main]
	elif tgt == "ally_low_two":
		var sorted_allies := allies.duplicate()
		sorted_allies.sort_custom(func(a: Dictionary, b: Dictionary): return hp_frac(a) < hp_frac(b))
		targets = sorted_allies.slice(0, mini(2, sorted_allies.size()))
	elif tgt == "ally_high_atk_and_low_hp":
		if allies.is_empty():
			return
		var highest_attack: Dictionary = allies[0]
		main = lowest_ratio(allies)
		for ally in allies:
			if get_stat(ally, "atk") > get_stat(highest_attack, "atk"):
				highest_attack = ally
		targets = [highest_attack]
		if int(main["uid"]) != int(highest_attack["uid"]):
			targets.append(main)
	elif tgt == "ally_all":
		targets = allies.duplicate()
	else:
		targets = [u]

	if targets.is_empty():
		return

	# Hien Ultimate Cut-in truoc khi nhan vat di chuyen ra chieu
	if key == "ult":
		await play_ultimate_cutin(u)

		if not u["alive"]:
			return

	var fx_color = sk.get("color", Color(1, 1, 1, 0.6))

	var home = u["home"]

	# --- di chuyển theo VÙNG ẢNH HƯỞNG, không theo loại projectile ---
	# Skill đơn: áp sát mục tiêu (địch hoặc đồng đội).
	# AoE, splash, buff self/team: ra đúng giữa sân.
	var destination: Vector2 = cast_destination(u, sk, targets)
	var motion: Dictionary = cast_motion_profile(u, sk, key, targets)
	u["node"].z_index = 8  # Ensure foreground during approach and attack.
	await cast_approach(u, destination, motion)
	if not u["alive"]:
		u["casting_animation"] = false
		u["node"].z_index = 0
		return

	# --- chuẩn bị skill: aura được phát trước khi tính damage ---
	await play_skill_charge(u, key, sk)
	if not u["alive"]:
		u["casting_animation"] = false
		u["node"].z_index = 0
		return
	for pre_effect in sk.get("pre_fx", []):
		apply_status(u, u, pre_effect)

	# --- gây sát thương ---

	var damaged = []
	var damaged_ids = {}
	var total = 0

	# Một kỹ năng chỉ kích hoạt cinematic impact một lần.
	var cinematic_hit_used: bool = false

	if sk.has("hits"):
		var stat_key = u["main"]
		var ign = float(sk.get("ignore_def", 0.0))
		var extra = float(u["next_bonus"])
		u["next_bonus"] = 0.0
		var hits = sk["hits"]
		for i in hits.size():
			if not u["alive"]:
				break
			await wait_for_hit_frame(u, key, i, hits.size())
			if not u["alive"]:
				break
			await cast_strike_motion(u, motion)
			
			# Ghi nhận lượng damage trước hit hiện tại
			var damage_before_hit: int = total
			
			var base_mult = float(hits[i]) * float(u.get("repeat_ult_scale", 1.0))
			if i == 0:
				base_mult += extra
			var hit_any = false
			for t in targets:
				if not t["alive"]:
					continue
				hit_any = true
				await play_skill_impact(u, t, key, sk, i)
				if not u["alive"] or not t["alive"]:
					continue
				var hit_opts: Dictionary = {}
				if bool(sk.get("force_crit_last", false)) and i == hits.size() - 1:
					hit_opts["force_crit"] = true
					hit_opts["crit_dmg_bonus"] = float(sk.get("last_crit_dmg_bonus", 0.0))
				total += deal_damage(u, t, stat_key, skill_mult(u, t, sk, base_mult), ign, hit_opts)
				if sk.get("detonate_poison", false) and i == 0:
					for effect in t["fx"]:
						if effect["t"] == "poison":
							var poison_burst: int = int(effect.get("dmg", 0)) * int(effect.get("stacks", 1))
							apply_damage(t, poison_burst, true)
							float_text(popup_pos(t), "Kích nổ độc %d" % poison_burst, Color(0.85, 0.45, 1.0), 20)
							break

				if not damaged_ids.has(t["uid"]):
					damaged_ids[t["uid"]] = true
					damaged.append(t)
			var splash_condition_met: bool = not bool(sk.get("splash_if_kill", false)) or (not main.is_empty() and not main["alive"])
			if i == 0 and sk.has("splash") and u["alive"] and splash_condition_met:
				for o in enemies:
					if o["uid"] == main["uid"] or not o["alive"]:
						continue
					await play_skill_impact(u, o, key, sk, 0)
					if not u["alive"] or not o["alive"]:
						continue
					total += deal_damage(u, o, stat_key, skill_mult(u, o, sk, float(sk["splash"])), ign, {})
					if not damaged_ids.has(o["uid"]):
						damaged_ids[o["uid"]] = true
						damaged.append(o)
						
						
			# Chỉ tạo cinematic impact khi hit thực sự gây damage.
			if total > damage_before_hit and not cinematic_hit_used:

				if key == "ult":
					cinematic_hit_used = true
					
					if u["id"] == "kaido":
						# Xác định tâm vụ nổ giữa các mục tiêu
						var blast_center: Vector2 = Vector2.ZERO

						for target in targets:
							blast_center += unit_center(target)

						if not targets.is_empty():
							blast_center /= float(targets.size())
						else:
							blast_center = ARENA_CAST_CENTER

						# Hiệu ứng va chạm lớn tại vị trí mục tiêu
						spawn_skill_vfx(
							blast_center,
							"impact",
							Color(1.0, 0.55, 0.15, 0.95),
							155.0,
							0.32
						)

						# Kaido: rung mạnh, khựng lâu hơn
						shake_screen(16.0)
						await play_hit_stop(0.11, 0.04)

					else:
						# Ultimate các nhân vật khác giữ nguyên
						shake_screen(10.0)
						await play_hit_stop(0.075, 0.07)

				elif key == "s2" and u["id"] in ["zoro", "shanks", "kaido"]:
					cinematic_hit_used = true

					# Skill 2 của ba nhân vật này có va chạm nhẹ hơn.
					shake_screen(4.5)
					await play_hit_stop(0.035, 0.16)

			if not hit_any:
				break

			if not has_character_animation(u, key):
				await get_tree().create_timer(0.15).timeout

		for t in damaged:
			if t["alive"] and u["alive"]:
				for st in sk.get("on_hit", []):
					apply_status(u, t, st)
		if sk.has("lifesteal") and total > 0 and u["alive"]:
			heal_unit(u, u, total * float(sk["lifesteal"]))
		if sk.get("extra_turn_on_kill", false) and tgt in ["enemy", "enemy_low"] and not main["alive"] and not u.get("ult_repeated", false):
			u["extra_turn"] = true
			u["repeat_ult"] = true
			u["ult_repeated"] = true

	# Counter/reflect can kill the caster during a multi-hit skill.
	# Stop the action without allowing a dead unit to apply heals or buffs.
	if not u["alive"]:
		u["casting_animation"] = false
		u["node"].z_index = 0
		return

	# Support skills do not have damage hit frames, but still need a casting beat.
	if not sk.has("hits") and u["alive"]:
		await cast_strike_motion(u, motion)

	# --- hồi máu / giải hiệu ứng ---
	if sk.has("heal"):
		var hl = sk["heal"]
		for t in targets:
			if not t["alive"]:
				continue
			spawn_skill_vfx(unit_center(t), "heal", fx_color, 75.0, 0.42)
			var heal_basis: float = float(t["max_hp"])
			if hl.has("scale"):
				heal_basis = float(get_stat(u, String(hl["scale"])))
			heal_unit(u, t, heal_basis * float(hl["pct"]))
			cleanse(t, int(hl.get("cleanse", 0)))
	if sk.has("self_heal") and u["alive"]:
		heal_unit(u, u, float(u["max_hp"]) * float(sk["self_heal"]))
	if sk.has("heal_lowest_ally") and not allies.is_empty():
		var heal_target: Dictionary = lowest_ratio(allies)
		var heal_stat: String = String(sk.get("heal_lowest_ally_scale", "mag"))
		heal_unit(u, heal_target, get_stat(u, heal_stat) * float(sk["heal_lowest_ally"]))
	if sk.get("cleanse_self", false):
		cleanse(u, 1)

	# --- khiên ---
	if sk.has("shield"):
		var sh = sk["shield"]
		var shield_basis: float = float(u["max_hp"])
		if sh.has("scale"):
			shield_basis = float(get_stat(u, String(sh["scale"])))
		var amt = int(shield_basis * float(sh["pct"]))
		var recips = allies if sh.get("to", "self") == "allies" else targets if sh.get("to", "self") == "targets" else [u]
		for t in recips:
			if not t["alive"]:
				continue
			spawn_skill_vfx(unit_center(t), "shield", Color(0.5, 0.8, 1.0, 0.8), 82.0, 0.48)
			add_shield(t, amt)

	# --- buff bản thân / cả đội ---
	if u["alive"]:
		for st in sk.get("self_fx", []):
			apply_status(u, u, st)
		if sk.has("self_fx") or sk.has("team_fx"):
			spawn_skill_vfx(unit_center(u), "aura", fx_color, 72.0, 0.48)
	for t in allies:
		if t["alive"]:
			for st in sk.get("team_fx", []):
				apply_status(u, t, st)

	if sk.has("set_next_bonus"):
		u["next_bonus"] = float(sk["set_next_bonus"])
		float_text(popup_pos(u), "Sẵn sàng!", Color(1, 0.8, 0.3), 20)
	if sk.get("fire", false):
		u["stacks"]["flame"] = mini(5, stack(u, "flame") + 1)

	if has_character_animation(u, key):
		await finish_character_animation(u, key)
	else:
		await get_tree().create_timer(0.2).timeout
	u["casting_animation"] = false
	if u["alive"]:
		await cast_recover(u, home, motion)
	# Always reset layering, including if death happened while returning.
	u["node"].z_index = 0

# ======================================================================
#  VFX TUNG CHIEU (khong can asset / particle / shader ben ngoai)
# ======================================================================
func unit_center(u: Dictionary) -> Vector2:
	return u["node"].position + Vector2(0.0, -float(u["h"]) * 0.55)
	
func ensure_ultimate_cutin_layer() -> void:
	if ulti_cutin_layer != null:
		return

	ulti_cutin_layer = CanvasLayer.new()
	ulti_cutin_layer.layer = 50
	add_child(ulti_cutin_layer)

	# Nen toi nhe. QUAN TRONG: phai IGNORE chuot, neu khong ColorRect phu kin man hinh
	# se chan moi cu click (ke ca nut Toc do) ngay ca khi no trong suot.
	ulti_cutin_dim = ColorRect.new()
	ulti_cutin_dim.color = Color(0, 0, 0, 0.0)
	ulti_cutin_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ulti_cutin_dim.visible = false
	ulti_cutin_layer.add_child(ulti_cutin_dim)

	ulti_cutin_root = Node2D.new()
	ulti_cutin_root.visible = false
	ulti_cutin_layer.add_child(ulti_cutin_root)

	# Nen khung hinh chu nhat cat cheo
	ulti_cutin_panel = Polygon2D.new()
	ulti_cutin_root.add_child(ulti_cutin_panel)

	# Anh nhan vat: Polygon2D co texture, nen tu dong bi cat dung theo khung
	ulti_cutin_portrait = Polygon2D.new()
	ulti_cutin_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ulti_cutin_root.add_child(ulti_cutin_portrait)

	# Vien sang quanh khung
	ulti_cutin_glow = Line2D.new()
	ulti_cutin_glow.closed = true
	ulti_cutin_glow.width = 6.0
	ulti_cutin_glow.joint_mode = Line2D.LINE_JOINT_SHARP
	ulti_cutin_root.add_child(ulti_cutin_glow)

	# Ten nhan vat (nam trong root de truot cung khung)
	ulti_cutin_name = Label.new()
	ulti_cutin_name.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ulti_cutin_name.add_theme_font_size_override("font_size", 34)
	ulti_cutin_name.add_theme_color_override("font_color", Color.WHITE)
	ulti_cutin_name.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	ulti_cutin_name.add_theme_constant_override("outline_size", 8)
	ulti_cutin_root.add_child(ulti_cutin_name)


func character_display_name(uid: String) -> String:
	match uid:
		"zoro":
			return "Zoro"
		"sabo":
			return "Sabo"
		"reiju":
			return "Reiju"
		"shanks":
			return "Shanks"
		"jinbei":
			return "Jinbei"
		"kaido":
			return "Kaido"
		"chopper":
			return "Chopper"
		"ace":
			return "Ace"
		_:
			return uid.capitalize()


func play_ultimate_cutin(u: Dictionary) -> void:
	ensure_ultimate_cutin_layer()

	var view_size: Vector2 = get_viewport_rect().size
	ulti_cutin_dim.size = view_size
	ulti_cutin_dim.visible = true

	var from_left: bool = int(u["team"]) == 0

	# --- Khung: chiem khoang NUA SAN ben phe dang tung chieu, hinh chu nhat cat cheo ---
	var half_w: float = view_size.x * 0.5
	var skew: float = 70.0
	var y_top: float = view_size.y * 0.20
	var y_bottom: float = view_size.y * 0.80
	var x0: float = 0.0 if from_left else half_w
	var x1: float = half_w if from_left else view_size.x

	var pts: PackedVector2Array
	if from_left:
		# canh cat cheo la canh phia trong (ben phai)
		pts = PackedVector2Array([
			Vector2(x0, y_top), Vector2(x1, y_top),
			Vector2(x1 - skew, y_bottom), Vector2(x0 - skew, y_bottom)])
	else:
		pts = PackedVector2Array([
			Vector2(x0, y_top), Vector2(x1, y_top),
			Vector2(x1 + skew, y_bottom), Vector2(x0 + skew, y_bottom)])

	# --- Mau theo nhan vat ---
	var dark_color := Color(0.04, 0.04, 0.05, 0.94)
	var accent_color := Color(1.00, 0.20, 0.20, 0.95)
	match str(u["id"]):
		"zoro":
			accent_color = Color(0.22, 0.95, 0.45, 0.95)
		"sabo":
			accent_color = Color(1.00, 0.45, 0.12, 0.95)
		"reiju":
			accent_color = Color(0.95, 0.35, 0.85, 0.95)
		"shanks":
			accent_color = Color(1.00, 0.20, 0.20, 0.95)
		"jinbei":
			accent_color = Color(0.25, 0.70, 1.00, 0.95)
		"kaido":
			accent_color = Color(0.65, 0.35, 1.00, 0.95)
		"chopper":
			accent_color = Color(0.45, 1.00, 0.50, 0.95)
		"ace":
			accent_color = Color(1.00, 0.55, 0.10, 0.95)

	ulti_cutin_panel.polygon = pts
	ulti_cutin_panel.color = dark_color
	ulti_cutin_glow.points = pts
	ulti_cutin_glow.default_color = accent_color

	# --- Anh nhan vat: lay frame dau cua battle_loop roi CAT vung than nguoi ---
	var portrait_tex: Texture2D = null
	var actor_sprite: AnimatedSprite2D = u.get("body") as AnimatedSprite2D
	if actor_sprite != null and actor_sprite.sprite_frames != null:
		var frames: SpriteFrames = actor_sprite.sprite_frames
		if frames.has_animation("battle_loop") and frames.get_frame_count("battle_loop") > 0:
			portrait_tex = frames.get_frame_texture("battle_loop", 0)

	if portrait_tex != null:
		# Hop bao cua khung
		var min_x: float = minf(pts[0].x, pts[3].x)
		var max_x: float = maxf(pts[1].x, pts[2].x)
		var bb_pos := Vector2(min_x, y_top)
		var bb_size := Vector2(max_x - min_x, y_bottom - y_top)
		var aspect: float = bb_size.x / bb_size.y

		# Crop is character-specific after transparent margins were trimmed from idle frames.
		var canvas: Vector2 = portrait_tex.get_size()
		var pivot: Vector2 = CHARACTER_ANIMATIONS.IDLE_PIVOTS.get(str(u["id"]), Vector2(canvas.x * 0.5, canvas.y))
		var body_px: float = float(CHARACTER_ANIMATIONS.BODY_REFERENCE_PX.get(str(u["id"]), 250.0))
		var src_h: float = minf(body_px * 1.2, minf(canvas.y, canvas.x / aspect))
		var src_w: float = src_h * aspect
		var src_x: float = clampf(pivot.x - src_w * 0.5, 0.0, canvas.x - src_w)
		var src_y: float = clampf(pivot.y + src_h * 0.06 - src_h, 0.0, canvas.y - src_h)

		# Map the selected portrait crop directly onto the cut-in panel.
		var k := Vector2.ONE

		var uvs := PackedVector2Array()
		for p in pts:
			var fx: float = (p.x - bb_pos.x) / bb_size.x
			var fy: float = (p.y - bb_pos.y) / bb_size.y
			if not from_left:
				fx = 1.0 - fx    # phe phai: lat guong de nhan vat huong vao giua san
			uvs.append(Vector2((src_x + src_w * fx) * k.x, (src_y + src_h * fy) * k.y))

		ulti_cutin_portrait.texture = portrait_tex
		ulti_cutin_portrait.polygon = pts
		ulti_cutin_portrait.uv = uvs
		ulti_cutin_portrait.visible = true
	else:
		ulti_cutin_portrait.visible = false

	# --- Ten nhan vat o day khung ---
	ulti_cutin_name.text = character_display_name(str(u["id"])) + "  \u2022  ULTIMATE"
	ulti_cutin_name.size = Vector2(420.0, 48.0)
	if from_left:
		ulti_cutin_name.position = Vector2(x0 + 40.0, y_bottom - 64.0)
		ulti_cutin_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		ulti_cutin_name.position = Vector2(x1 - 460.0, y_bottom - 64.0)
		ulti_cutin_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	# --- Trang thai dau + truot vao ---
	ulti_cutin_root.visible = true
	ulti_cutin_dim.color.a = 0.0
	ulti_cutin_root.modulate.a = 0.0
	var slide: float = half_w * 1.1
	ulti_cutin_root.position = Vector2(-slide if from_left else slide, 0.0)

	var t_in := create_tween()
	t_in.set_parallel(true)
	t_in.tween_property(ulti_cutin_dim, "color:a", 0.30, ULT_CUTIN_IN_TIME)
	t_in.tween_property(ulti_cutin_root, "position:x", 0.0, ULT_CUTIN_IN_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t_in.tween_property(ulti_cutin_root, "modulate:a", 1.0, ULT_CUTIN_IN_TIME)
	await t_in.finished

	await get_tree().create_timer(ULT_CUTIN_HOLD_TIME).timeout

	var t_out := create_tween()
	t_out.set_parallel(true)
	t_out.tween_property(ulti_cutin_dim, "color:a", 0.0, ULT_CUTIN_OUT_TIME)
	t_out.tween_property(ulti_cutin_root, "position:x", slide if from_left else -slide, ULT_CUTIN_OUT_TIME)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	t_out.tween_property(ulti_cutin_root, "modulate:a", 0.0, ULT_CUTIN_OUT_TIME)
	await t_out.finished

	ulti_cutin_root.visible = false
	ulti_cutin_dim.visible = false


func skill_style(u: Dictionary, key: String) -> String:
	if key == "basic":
		return "slash" if u["main"] == "atk" else "impact"
	match u["id"]:
		"zoro", "shanks":
			return "slash" 
		"sabo":
			return "slash" if key == "s1" else "fire"
		"ace":
			return "shield" if key == "s2" else "fire"
		"reiju":
			return "poison"
		"chopper":
			return "shield" if key == "s2" else "heal"
		"jinbei":
			return "shield" if key == "s2" else "water"
		"kaido":
			if key == "s1":
				return "lightning"
			return "shield" if key == "s2" else "fire"
	return "impact"


func has_projectile(u: Dictionary, key: String) -> bool:
	if key == "basic":
		return false
	match u["id"]:
		"reiju":
			return true
		"ace":
			return key == "s1" or key == "ult"
		"sabo":
			return key == "s2" or key == "ult"
		"kaido":
			return key == "ult"
		"jinbei":
			return key == "s1" or key == "ult"
	return false


func spawn_skill_vfx(pos: Vector2, kind: String, color: Color, radius: float = 65.0, duration: float = 0.32) -> void:
	var fx = BattleVFX.new()
	fx.kind = kind
	fx.tint = color
	fx.radius = radius
	fx.position = pos
	fx.z_index = 25
	add_child(fx)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(fx, "progress", 1.0, duration).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(fx, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD)
	tw.chain().tween_callback(fx.queue_free)


func has_character_animation(u: Dictionary, key: String) -> bool:
	return USE_CHARACTER_ANIMATIONS and key != "basic" and u["body"] is AnimatedSprite2D


func wait_for_character_frame(u: Dictionary, key: String, frame_number: int) -> void:
	if not has_character_animation(u, key):
		return
	var spr: AnimatedSprite2D = u["body"]
	# Use the actual SpriteFrames playback clock; no fixed-delay / frame-count guesses.
	while spr.animation == StringName(key) and spr.is_playing() and spr.frame < frame_number:
		await spr.frame_changed


func wait_for_hit_frame(u: Dictionary, key: String, hit_index: int, hit_count: int) -> void:
	if not has_character_animation(u, key):
		return
	var begin: int = 4 if key == "ult" else 2
	var finish: int = 10 if key == "ult" else 4
	
	# Ultimate Kaido: damage tai frame 8, dung luc Blast Breath bung no
	if u["id"] == "kaido" and key == "ult":
		begin = 7
		finish = 8

	var scheduled_frame: int = begin
	if hit_count > 1:
			scheduled_frame = int(round(lerpf(float(begin), float(finish), float(hit_index) / float(hit_count - 1))))
	await wait_for_character_frame(u, key, scheduled_frame)



func finish_character_animation(u: Dictionary, key: String) -> void:
	if not has_character_animation(u, key):
		return

	var spr: AnimatedSprite2D = u["body"]

	if not is_instance_valid(spr):
		return

	# Cho animation phat den khi ket thuc thuc su
	if spr.animation == StringName(key) and spr.is_playing():
		await spr.animation_finished

	# Chi quay ve Battle Loop neu nhan vat con song
	if u["alive"] and is_instance_valid(spr):
		if spr.animation == StringName(key):
			spr.play("battle_loop")

func play_skill_charge(u: Dictionary, key: String, sk: Dictionary) -> void:
	if key == "basic":
		return

	if has_character_animation(u, key):
		var spr: AnimatedSprite2D = u["body"]

		# Thoi gian phat animation
		var duration: float = 1.0

		if key == "ult":
			duration = 2.25

		# Tinh FPS tu so frame thuc te
		var frame_count: int = spr.sprite_frames.get_frame_count(key)
		var fps: float = float(frame_count) / duration

		# Cap nhat toc do animation
		spr.sprite_frames.set_animation_speed(key, fps)
		spr.speed_scale = 1.0

		u["casting_animation"] = true
		u["node"].z_index = 8

		# Phat animation ky nang
		spr.play(key)

		# Cho den frame charge
		await wait_for_character_frame(
			u,
			key,
			3 if key == "ult" else 1
		)
		return

	# VFX du phong
	var col: Color = sk.get(
		"color",
		Color(0.8, 0.9, 1.0, 0.9)
	)

	var pos = unit_center(u)

	spawn_skill_vfx(
		pos, "aura", col,
		95.0 if key == "ult" else 62.0,
		0.42
	)

	if key == "ult":
		spawn_skill_vfx(
			pos,
			skill_style(u, key),
			col,
			95.0,
			0.52
		)

	await get_tree().create_timer(
		0.28 if key == "ult" else 0.16
	).timeout



func fly_skill_orb(from_pos: Vector2, to_pos: Vector2, col: Color, time: float) -> void:
	var ball = BattleVFX.new()
	ball.kind = "orb"
	ball.tint = col
	ball.radius = 23.0
	ball.position = from_pos
	ball.z_index = 28
	add_child(ball)
	var tw = create_tween().set_parallel(true)
	tw.tween_property(ball, "position", to_pos, time).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(ball, "progress", 1.0, time)
	await tw.finished
	ball.queue_free()


func play_skill_impact(u: Dictionary, t: Dictionary, key: String, sk: Dictionary, hit_index: int) -> void:
	var col: Color = sk.get("color", Color(1.0, 0.95, 0.7, 0.9))
	if has_character_animation(u, key):
		# The full slash/fire/water/poison effect is already baked into the actor's frames.
		# Only show a small impact indicator on the TARGET. Avoid double projectiles.
		spawn_skill_vfx(unit_center(t), "impact", col, 34.0, 0.18)
		await get_tree().create_timer(0.025).timeout
		return
	var kind = skill_style(u, key)
	if has_projectile(u, key) and hit_index == 0:
		if u["id"] == "reiju" and key == "s2":
			await fly_skill_orb(unit_center(t), unit_center(u), col, 0.22)
		else:
			await fly_skill_orb(unit_center(u), unit_center(t), col, 0.23)
	var r = 80.0 if key == "ult" else 57.0
	spawn_skill_vfx(unit_center(t), kind, col, r, 0.36)
	await get_tree().create_timer(0.075).timeout

var hit_stop_active: bool = false


func play_hit_stop(duration: float = 0.07, slow_scale: float = 0.08) -> void:
	if hit_stop_active:
		return

	hit_stop_active = true

	# Làm chậm thời gian trong khoảnh khắc va chạm
	Engine.time_scale = clampf(slow_scale, 0.01, 1.0)

	# Chờ theo thời gian thực
	await get_tree().create_timer(
		duration,
		true,
		false,
		true
	).timeout

	# Khôi phục về tốc độ người chơi đang chọn (kể cả khi vừa bấm nút trong lúc hit-stop)
	Engine.time_scale = float(game_speed)
	hit_stop_active = false

var screen_shake_tween: Tween


func shake_screen(strength: float = 6.0) -> void:
	# Hủy rung cũ để tránh nhiều Tween điều khiển cùng vị trí.
	if screen_shake_tween != null:
		if screen_shake_tween.is_running():
			screen_shake_tween.kill()

	# Project hiện tại sử dụng Node2D gốc tại (0, 0).
	position = Vector2.ZERO

	screen_shake_tween = create_tween()

	# Camera shake vẫn chạy theo thời gian thực khi có hit-stop.
	screen_shake_tween.set_ignore_time_scale(true)

	screen_shake_tween.tween_property(
		self, "position",
		Vector2(strength, -strength * 0.5),
		0.035
	)

	screen_shake_tween.tween_property(
		self, "position",
		Vector2(-strength * 0.85, strength * 0.45),
		0.04
	)

	screen_shake_tween.tween_property(
		self, "position",
		Vector2(strength * 0.4, -strength * 0.3),
		0.04
	)

	screen_shake_tween.tween_property(
		self, "position",
		Vector2(-strength * 0.2, strength * 0.15),
		0.035
	)

	# Luôn trả về vị trí ban đầu.
	screen_shake_tween.tween_property(
		self, "position",
		Vector2.ZERO,
		0.055
	)

# No texture needed. All effects are vector primitives drawn on a Node2D canvas.
class BattleVFX extends Node2D:
	var kind: String = "impact"
	var tint: Color = Color.WHITE
	var radius: float = 64.0
	var progress: float = 0.0:
		set(value):
			progress = value
			queue_redraw()

	func _draw() -> void:
		var p = clampf(progress, 0.0, 1.0)
		var r = radius * (0.68 + 0.48 * p)
		var light = Color(1.0, 1.0, 1.0, 0.9)
		var core = Color(tint.r, tint.g, tint.b, 0.88)
		var haze = Color(tint.r, tint.g, tint.b, 0.28)
		match kind:
			"aura":
				draw_circle(Vector2.ZERO, r * 0.68, haze)
				draw_arc(Vector2.ZERO, r * 0.82, 0.0, TAU, 50, core, 4.0, true)
				for i in range(8):
					var ang = TAU * float(i) / 8.0 + p
					var a = Vector2.RIGHT.rotated(ang) * (r * 0.74)
					var b = Vector2.RIGHT.rotated(ang) * (r * 1.16)
					draw_line(a, b, core, 3.0, true)
			"slash":
				draw_line(Vector2(-r, r * 0.56), Vector2(r, -r * 0.65), core, 15.0, true)
				draw_line(Vector2(-r, r * 0.56), Vector2(r, -r * 0.65), light, 5.0, true)
				draw_line(Vector2(-r * 0.6, -r * 0.72), Vector2(r * 0.72, r * 0.65), core, 10.0, true)
				draw_line(Vector2(-r * 0.6, -r * 0.72), Vector2(r * 0.72, r * 0.65), light, 3.0, true)
				draw_arc(Vector2.ZERO, r * 0.95, -1.9, 0.72, 35, core, 4.0, true)
			"fire":
				draw_circle(Vector2.ZERO, r * 0.53, haze)
				for i in range(8):
					var ang = TAU * float(i) / 8.0 + p * 1.2
					var direction = Vector2.RIGHT.rotated(ang)
					var side = direction.orthogonal()
					var base = direction * (r * 0.2)
					var tip = direction * (r * (0.85 + (i % 3) * 0.1))
					draw_colored_polygon(PackedVector2Array([base + side * r * 0.23, tip, base - side * r * 0.23]), core)
				draw_circle(Vector2.ZERO, r * 0.34, Color(1.0, 0.85, 0.3, 0.87))
				draw_circle(Vector2.ZERO, r * 0.16, light)
			"poison":
				for i in range(9):
					var angle = TAU * float(i) / 9.0 + p * 0.7
					var dist = r * (0.2 + (i % 3) * 0.2)
					var bubble = Vector2.RIGHT.rotated(angle) * dist
					draw_circle(bubble, r * (0.19 + float(i % 3) * 0.045), haze)
					draw_arc(bubble, r * 0.17, 0.0, TAU, 20, core, 2.5, true)
				draw_arc(Vector2.ZERO, r * 0.8, 0.0, TAU, 42, core, 3.0, true)
			"lightning":
				draw_arc(Vector2.ZERO, r * 0.62, 0.0, TAU, 32, haze, 10.0, true)
				for i in range(4):
					var angle = TAU * float(i) / 4.0 + p * 0.2
					var dir = Vector2.RIGHT.rotated(angle)
					var side = dir.orthogonal()
					var points = PackedVector2Array([dir * -r * 0.12, dir * r * 0.23 + side * r * 0.18, dir * r * 0.47 - side * r * 0.14, dir * r * 0.95])
					draw_polyline(points, core, 10.0, true)
					draw_polyline(points, light, 3.0, true)
			"water":
				draw_circle(Vector2.ZERO, r * 0.5, haze)
				for i in range(4):
					var y = float(i - 2) * r * 0.21
					draw_arc(Vector2(0, y), r * (0.65 - i * 0.07), 0.12, PI - 0.12, 26, core, 5.0, true)
				draw_arc(Vector2.ZERO, r * 0.9, 0.0, TAU, 40, light, 2.5, true)
			"heal":
				draw_circle(Vector2.ZERO, r * 0.45, haze)
				draw_arc(Vector2.ZERO, r * 0.72, 0.0, TAU, 48, core, 5.0, true)
				draw_line(Vector2(-r * 0.38, 0), Vector2(r * 0.38, 0), light, 13.0, true)
				draw_line(Vector2(0, -r * 0.38), Vector2(0, r * 0.38), light, 13.0, true)
			"shield":
				draw_circle(Vector2.ZERO, r * 0.55, haze)
				var verts = PackedVector2Array()
				for i in range(7):
					verts.append(Vector2.RIGHT.rotated(TAU * float(i) / 6.0) * r * 0.8)
				draw_polyline(verts, core, 6.0, true)
				draw_arc(Vector2.ZERO, r * 0.52, 0.0, TAU, 36, light, 3.0, true)
			"orb":
				draw_circle(Vector2.ZERO, r * 0.95, haze)
				draw_circle(Vector2.ZERO, r * 0.62, core)
				draw_circle(Vector2.ZERO, r * 0.28, light)
				draw_arc(Vector2.ZERO, r * 1.16, 0.0, TAU, 30, core, 3.0, true)
			_:
				draw_circle(Vector2.ZERO, r * 0.53, haze)
				draw_arc(Vector2.ZERO, r * 0.9, 0.0, TAU, 44, core, 5.0, true)
				for i in range(8):
					var ang = TAU * float(i) / 8.0
					draw_line(Vector2.RIGHT.rotated(ang) * r * 0.45, Vector2.RIGHT.rotated(ang) * r * 1.1, light, 2.5, true)

# Chopper tự động bật Guard Point lần đầu đồng đội xuống dưới 40% HP.
func passive_checks() -> void:
	for c in units:
		if c["id"] != "chopper" or not c["alive"]:
			continue
		for ally in units:
			if ally["team"] != c["team"] or not ally["alive"] or ally["uid"] == c["uid"]:
				continue
			if hp_frac(ally) < 0.4 and not c.get("guard_triggered", false):
				c["guard_triggered"] = true
				add_shield(ally, int(get_stat(c, "mag") * 0.9))
				add_fx(ally, {"t": "mod", "stat": "def", "pct": 0.15, "turns": 2, "label": "Guard Point · DEF+15%"})
				add_log("Chopper kích hoạt Guard Point cho %s!" % ally["name"])
				break


func check_end() -> bool:
	var alive_a = team_alive(0)
	var alive_b = team_alive(1)
	if alive_a > 0 and alive_b > 0:
		return false
	var from_lobby: bool = GameState.pending_battle.has("team_a") and not _is_training()
	var outcome := "draw"
	if alive_a == 0 and alive_b == 0:
		result_label.text = "HÒA!"
	elif alive_b == 0:
		outcome = "win"
		result_label.text = "CHIẾN THẮNG!" if from_lobby else "ĐỘI TRÁI THẮNG!"
	else:
		outcome = "lose"
		result_label.text = "THẤT BẠI" if from_lobby else "ĐỘI PHẢI THẮNG!"
	result_label.visible = true
	restart_button.visible = true
	if from_lobby:
		show_battle_rewards(outcome)
	return true


# [META] Trả thưởng coin và hiện nút "Về sảnh". outcome: "win" | "lose" | "draw"
var battle_over: bool = false

func _is_training() -> bool:
	return String(GameState.pending_battle.get("mode", "")) == "training"


func _leave_training() -> void:
	GameState.pending_battle = {}
	SceneManager.change_scene(GameData.SCENE_LOBBY)


func show_battle_rewards(outcome: String) -> void:
	if battle_over:
		return
	battle_over = true
	var reward: int = GameState.finish_battle(outcome)

	result_label.position = Vector2(0, 240)
	result_label.size = Vector2(1152, 80)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var reward_label := Label.new()
	reward_label.text = "+%d coin" % reward
	reward_label.position = Vector2(0, 322)
	reward_label.size = Vector2(1152, 40)
	reward_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_label.add_theme_font_size_override("font_size", 30)
	reward_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	reward_label.add_theme_constant_override("outline_size", 8)
	reward_label.z_index = 30
	add_child(reward_label)

	restart_button.position = Vector2(400, 380)
	var lobby_button := Button.new()
	lobby_button.text = "Về sảnh"
	lobby_button.size = Vector2(160, 50)
	lobby_button.position = Vector2(592, 380)
	lobby_button.z_index = 30
	lobby_button.pressed.connect(func(): SceneManager.change_scene(GameData.SCENE_LOBBY))
	add_child(lobby_button)


# Hiệu ứng vòng tròn mở rộng khi kỹ năng trúng
class Burst extends Node2D:
	var radius: float = 10.0:
		set(value):
			radius = value
			queue_redraw()
	var tint: Color = Color(1, 1, 1, 0.6)

	func _draw() -> void:
		draw_circle(Vector2.ZERO, radius, tint)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)
