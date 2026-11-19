extends RefCounted
## Reusable animation resource loader. Generated from the standalone Animation Labs.
## Every character keeps one fixed display scale for idle, skills and ultimate.

const BODY_REFERENCE_PX := {
	"ace": 311.0, "akainu": 356.0, "aokiji": 364.0, "chopper": 305.0,
	"doflamingo": 353.0, "enel": 337.0, "garp": 360.0, "jinbei": 341.0,
	"jozu": 359.0, "kaido": 352.0, "kizaru": 366.0, "kuma": 354.0,
	"law": 367.0, "magellan": 352.0, "marco": 359.0, "rayleigh": 351.0,
	"reiju": 371.0, "sabo": 352.0, "sengoku": 374.0, "shanks": 332.0,
	"shirahoshi": 362.0, "teach": 324.0, "whitebeard": 366.0, "zoro": 333.0,
}
const LEGACY_SKILL_BODY_REFERENCE_PX := {
	"ace": 242.0, "chopper": 145.0, "jinbei": 181.0, "kaido": 340.0,
	"reiju": 373.0, "sabo": 177.0, "shanks": 280.0, "zoro": 255.0,
}
const IDLE_PIVOTS := {
	"ace": Vector2(183, 350), "akainu": Vector2(181, 395), "aokiji": Vector2(181, 393), "chopper": Vector2(183, 364),
	"doflamingo": Vector2(178, 387), "enel": Vector2(183, 356), "garp": Vector2(182, 395), "jinbei": Vector2(183, 371),
	"jozu": Vector2(176, 387), "kaido": Vector2(183, 389), "kizaru": Vector2(182, 392), "kuma": Vector2(179, 390),
	"law": Vector2(177, 387), "magellan": Vector2(183, 376), "marco": Vector2(183, 388), "rayleigh": Vector2(180, 387),
	"reiju": Vector2(182, 395), "sabo": Vector2(181, 388), "sengoku": Vector2(182, 395), "shanks": Vector2(183, 361),
	"shirahoshi": Vector2(181, 376), "teach": Vector2(183, 347), "whitebeard": Vector2(183, 395), "zoro": Vector2(183, 384),
}
const SHARED_PIVOT := Vector2(312, 500)
const DEFAULT_CANVAS := Vector2(768, 576)

## ---------------------------------------------------------------------------
## CLIP CÓ KHUNG HÌNH TO HƠN (hóa rồng, phượng hoàng, cầu lửa khổng lồ, hóa Phật, ...)
## DÙNG CHUNG CHO MỌI NHÂN VẬT, KHÔNG CẦN KHAI BÁO GÌ THÊM:
##   Cứ xuất clip đó với canvas = 768x576 nhân hệ số k (1.5, 2, 2.5, 3, 4), vẽ chân nhân vật
##   ở cùng vị trí TƯƠNG ĐỐI (40.6% từ trái, 86.8% từ trên). Game tự đọc kích thước ảnh và
##   đặt chân nhân vật đúng chỗ. Tỉ lệ pixel không đổi, nên canvas gấp 2 = hình to gấp 2 thật sự.
## Chỉ khi cần pivot khác quy tắc trên mới khai báo riêng, MỖI CLIP MỘT DÒNG, ví dụ:
##   "kaido": {"ult": {"canvas": Vector2(1536, 1152), "pivot": Vector2(560, 1000), "scale": 1.0}},
## (scale: nhân thêm vào tỉ lệ hiển thị, 1.0 = giữ nguyên; dùng để thử nhanh bằng ảnh cũ phóng to)
## Bỏ dấu # ở dòng mẫu để bật:
const CLIP_LAYOUT := {
	# Zoro attack sheets use different fixed cell sizes; these pivots keep the feet anchored.
	"zoro": {
		"s1": {"canvas": Vector2(362, 362), "pivot": Vector2(181, 325), "scale": 1.75},
		"s2": {"canvas": Vector2(512, 512), "pivot": Vector2(256, 430), "scale": 1.30},
		"ult": {"canvas": Vector2(544, 384), "pivot": Vector2(272, 355), "scale": 1.95},
	},
	# "kaido": {"ult": {"canvas": Vector2(1536, 1152), "pivot": Vector2(560, 1000), "scale": 1.0}},
}


## Trả về canvas / pivot / scale của một clip. tex_size là kích thước frame thực tế của clip.
static func layout_for(id: String, clip: String, tex_size: Vector2) -> Dictionary:
	if CLIP_LAYOUT.has(id) and CLIP_LAYOUT[id].has(clip):
		var custom: Dictionary = CLIP_LAYOUT[id][clip]
		return {
			"canvas": custom.get("canvas", tex_size),
			"pivot": custom.get("pivot", SHARED_PIVOT),
			"scale": float(custom.get("scale", 1.0)),
		}
	if clip == "battle_loop" or clip == "idle_loop":
		return {
			"canvas": tex_size,
			"pivot": IDLE_PIVOTS.get(id, Vector2(round(tex_size.x * 0.5), tex_size.y)),
			"scale": 1.0,
		}
	if LEGACY_SKILL_BODY_REFERENCE_PX.has(id) and clip in ["s1", "s2", "ult"]:
		var preserve_skill_scale: float = float(BODY_REFERENCE_PX[id]) / float(LEGACY_SKILL_BODY_REFERENCE_PX[id])
		return {
			"canvas": tex_size,
			"pivot": Vector2(
				round(SHARED_PIVOT.x * tex_size.x / DEFAULT_CANVAS.x),
				round(SHARED_PIVOT.y * tex_size.y / DEFAULT_CANVAS.y)),
			"scale": preserve_skill_scale,
		}
	return {
		"canvas": tex_size,
		"pivot": Vector2(
			round(SHARED_PIVOT.x * tex_size.x / DEFAULT_CANVAS.x),
			round(SHARED_PIVOT.y * tex_size.y / DEFAULT_CANVAS.y)),
		"scale": 1.0,
	}

static func apply_layout(sprite: AnimatedSprite2D, id: String, team: int, clip: String) -> void:
	var tex_size: Vector2 = DEFAULT_CANVAS
	var frames: SpriteFrames = sprite.sprite_frames
	if frames != null and frames.has_animation(clip) and frames.get_frame_count(clip) > 0:
		var tex: Texture2D = frames.get_frame_texture(clip, 0)
		if tex != null:
			tex_size = tex.get_size()
	var lay: Dictionary = layout_for(id, clip, tex_size)
	var canvas: Vector2 = lay["canvas"]
	var pivot: Vector2 = lay["pivot"]
	# Lật gương làm đảo trục X của ảnh nguồn -> đổi pivot cho phe phải.
	var pivot_x: float = pivot.x
	if team == 1:
		pivot_x = canvas.x - pivot.x
	sprite.offset = Vector2(-pivot_x, -pivot.y)
	var base: float = float(sprite.get_meta("base_scale", 1.0))
	sprite.scale = Vector2.ONE * base * float(lay["scale"])


static func create_sprite(id: String, display_height: float, team: int) -> AnimatedSprite2D:
	if not BODY_REFERENCE_PX.has(id):
		return null
	var path: String = "res://animations/%s/spriteframes.tres" % id
	if not ResourceLoader.exists(path):
		return null
	var resource: SpriteFrames = load(path) as SpriteFrames
	if resource == null:
		return null
	var sprite := AnimatedSprite2D.new()
	sprite.name = "BattleAnimation_" + id
	sprite.sprite_frames = resource
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var body_height: float = float(BODY_REFERENCE_PX[id])
	sprite.set_meta("base_scale", display_height / body_height)
	# Artwork in the animation sets faces right. Right-side team mirrors horizontally.
	sprite.flip_h = team == 1
	# Mỗi lần đổi clip (battle_loop -> ult ...) tự áp lại offset/scale của clip đó.
	sprite.animation_changed.connect(func() -> void:
		apply_layout(sprite, id, team, String(sprite.animation)))
	apply_layout(sprite, id, team, "battle_loop")
	sprite.play("battle_loop")
	return sprite
