extends CanvasLayer
## Chuyển scene có hiệu ứng mờ dần (autoload: SceneManager).

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color(0.02, 0.03, 0.06, 1.0)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


func change_scene(path: String) -> void:
	if _busy:
		return
	_busy = true
	_fade.mouse_filter = Control.MOUSE_FILTER_STOP     # chặn click khi đang chuyển
	var t_out := create_tween()
	t_out.tween_property(_fade, "modulate:a", 1.0, 0.18)
	await t_out.finished
	Engine.time_scale = 1.0     # battle có nút tăng tốc, trả về bình thường khi rời trận
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Không mở được scene: %s" % path)
	await get_tree().process_frame
	await get_tree().process_frame
	var t_in := create_tween()
	t_in.tween_property(_fade, "modulate:a", 0.0, 0.22)
	await t_in.finished
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
