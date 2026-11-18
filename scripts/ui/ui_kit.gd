class_name UIKit
extends RefCounted
## Hàm dựng giao diện dùng chung. Toàn bộ UI của các màn mới được dựng bằng code
## nên không cần chỉnh tay trong editor; muốn đổi giao diện thì sửa ở đây.

const CHARACTER_ANIMATIONS = preload("res://scripts/character_animations.gd")
const BACKGROUND_PATH := "res://background.jpg"
const TEXT_COLOR := Color("f4f1ea")
const MUTED_COLOR := Color("aab2c5")
const PANEL_COLOR := Color(0.07, 0.09, 0.15, 0.82)


static func tier_color(tier: String) -> Color:
	match tier:
		"UR":
			return Color("ff4d6d")
		"SP":
			return Color("b678ff")
		_:
			return Color("ffc83d")


static func style(bg: Color, radius: int = 12, border: Color = Color(0, 0, 0, 0), border_w: int = 0, margin: float = 10.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_content_margin_all(margin)
	return s


static func label(text: String, size: int = 20, color: Color = TEXT_COLOR, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.add_theme_constant_override("outline_size", 4)
	return l


static func button(text: String, color: Color = Color("2f6fed"), font_size: int = 22, min_size: Vector2 = Vector2(160, 54)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_stylebox_override("normal", style(color))
	b.add_theme_stylebox_override("hover", style(color.lightened(0.15)))
	b.add_theme_stylebox_override("pressed", style(color.darkened(0.2)))
	b.add_theme_stylebox_override("disabled", style(color.darkened(0.55)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


static func panel(color: Color = PANEL_COLOR, radius: int = 14, border: Color = Color(1, 1, 1, 0.10), border_w: int = 2) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", style(color, radius, border, border_w, 14.0))
	return p


## Ảnh nền + lớp phủ tối. Thêm vào đầu tiên để nằm dưới cùng.
static func add_background(parent: Control, dim: float = 0.5) -> void:
	var tex := TextureRect.new()
	if ResourceLoader.exists(BACKGROUND_PATH):
		tex.texture = load(BACKGROUND_PATH)
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tex.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tex)
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.05, 0.10, dim)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shade)


## Một dòng thông báo nhỏ ở giữa phía trên, tự biến mất.
static func toast(host: Control, text: String) -> void:
	var toast_box := CenterContainer.new()
	toast_box.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast_box.offset_top = 96
	toast_box.offset_bottom = 160
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.z_index = 50
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", style(Color(0, 0, 0, 0.85), 10, Color(1, 1, 1, 0.2), 1, 12.0))
	p.add_child(label(text, 22))
	toast_box.add_child(p)
	host.add_child(toast_box)
	toast_box.modulate.a = 0.0
	var tw := toast_box.create_tween()
	tw.tween_property(toast_box, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.5)
	tw.tween_property(toast_box, "modulate:a", 0.0, 0.3)
	tw.tween_callback(toast_box.queue_free)


## Hàng ô vuông nhỏ biểu diễn số sao (không dùng ký tự ★ để khỏi phụ thuộc font).
static func star_row(stars: int, max_stars: int = 5) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(max_stars):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(13, 13)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var filled := i < stars
		dot.add_theme_stylebox_override("panel", style(
			Color("ffc83d") if filled else Color(1, 1, 1, 0.18), 3, Color(0, 0, 0, 0.5), 1, 0.0))
		row.add_child(dot)
	return row


## Pill nhỏ hiển thị bậc nhân vật (UR / SP / SSR).
static func tier_badge(tier: String, font_size: int = 16) -> Label:
	var l := label(tier, font_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_stylebox_override("normal", style(tier_color(tier).darkened(0.1), 6, Color(1, 1, 1, 0.5), 1, 5.0))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Khung chứa nhân vật chạy animation `battle_loop`, chân đứng giữa-đáy khung.
## silhouette = true -> bóng đen (nhân vật chưa sở hữu).
static func character_view(id: String, body_height: float, view_size: Vector2, silhouette: bool = false) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = view_size
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.clip_contents = true
	var anchor := Node2D.new()
	anchor.position = Vector2(view_size.x * 0.5, view_size.y - 4.0)
	holder.add_child(anchor)
	var art_scale: float = float(GameData.CHARACTER_ART_SCALE.get(id, 1.0))
	var max_height: float = maxf(8.0, view_size.y - 8.0)
	var display_height: float = minf(body_height * art_scale, max_height)
	var sprite: CanvasItem = CHARACTER_ANIMATIONS.create_sprite(id, display_height, 0)
	if sprite != null:
		if silhouette:
			sprite.modulate = Color(0.02, 0.02, 0.05, 0.9)
		anchor.add_child(sprite)
	else:
		var path: String = "res://assets/characters_static/%s.png" % id
		if ResourceLoader.exists(path):
			var texture := load(path) as Texture2D
			if texture != null:
				var still := Sprite2D.new()
				still.name = "StaticCharacterArt_" + id
				still.texture = texture
				still.centered = false
				still.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				var max_width: float = maxf(8.0, view_size.x - 8.0)
				var image_scale: float = minf(display_height / texture.get_height(), max_width / texture.get_width())
				still.scale = Vector2.ONE * image_scale
				still.offset = Vector2(-texture.get_width() * 0.5, -texture.get_height())
				if silhouette:
					still.modulate = Color(0.02, 0.02, 0.05, 0.9)
				anchor.add_child(still)
	return holder


## Đặt mouse_filter = IGNORE cho cả cây con (để click xuyên xuống Button cha).
static func ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		ignore_mouse(c)
