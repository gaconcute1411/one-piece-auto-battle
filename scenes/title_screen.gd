extends Control
## Màn hình vào game.

var _hint: Label
var _confirm: ConfirmationDialog


func _ready() -> void:
	UIKit.add_background(self, 0.35)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UIKit.label(GameData.GAME_TITLE, 60, Color("ffe08a"), HORIZONTAL_ALIGNMENT_CENTER)
	title.add_theme_constant_override("outline_size", 12)
	box.add_child(title)
	box.add_child(UIKit.label("Đại chiến hải tặc 6 vs 6", 24, UIKit.TEXT_COLOR, HORIZONTAL_ALIGNMENT_CENTER))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 40)
	box.add_child(gap)

	var play := UIKit.button("VÀO GAME", Color("e0572f"), 30, Vector2(320, 72))
	play.pressed.connect(_on_play)
	box.add_child(play)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)

	var reset := UIKit.button("Xóa dữ liệu", Color("4a4f63"), 18, Vector2(154, 44))
	reset.pressed.connect(func(): _confirm.popup_centered())
	row.add_child(reset)
	# Nút Thoát không có ý nghĩa trên trình duyệt / mobile nên chỉ hiện trên PC
	if OS.get_name() in ["Windows", "Linux", "macOS"]:
		var quit := UIKit.button("Thoát", Color("4a4f63"), 18, Vector2(154, 44))
		quit.pressed.connect(func(): get_tree().quit())
		row.add_child(quit)

	_hint = UIKit.label("", 18, UIKit.MUTED_COLOR, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_hint)
	_refresh_hint()

	var ver := UIKit.label("v%s" % GameData.GAME_VERSION, 16, UIKit.MUTED_COLOR)
	ver.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	ver.offset_left = 16
	ver.offset_top = -34
	add_child(ver)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Xóa dữ liệu"
	_confirm.dialog_text = "Xóa toàn bộ tiến trình (coin, nhân vật, điểm danh) và chơi lại từ đầu?"
	_confirm.ok_button_text = "Xóa"
	_confirm.cancel_button_text = "Hủy"
	_confirm.confirmed.connect(func():
		GameState.new_game()
		_refresh_hint()
		UIKit.toast(self, "Đã tạo dữ liệu mới"))
	add_child(_confirm)


func _refresh_hint() -> void:
	_hint.text = "Coin hiện có: %d  |  Nhân vật: %d/%d" % [
		GameState.coins, GameState.owned.size(), GameData.CHARACTERS.size()]


func _on_play() -> void:
	SceneManager.change_scene(GameData.SCENE_LOBBY)
