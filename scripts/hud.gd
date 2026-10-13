extends CanvasLayer
## Giao diện trong trận: đồng hồ, vai trò, thông báo, màn hình che mắt người tìm.

@onready var top_label: Label = $TopLabel
@onready var info_label: Label = $InfoLabel
@onready var role_label: Label = $RoleLabel
@onready var message_label: Label = $MessageLabel
@onready var blind: ColorRect = $Blind
@onready var blind_label: Label = $Blind/BlindLabel
@onready var end_label: Label = $EndLabel

var _message_time := 0.0


func _ready() -> void:
	var overlay := preload("res://scripts/observer_overlay.gd").new()
	overlay.name = "ObserverOverlay"
	add_child(overlay)
	move_child(overlay, 0)
	message_label.text = ""
	blind.visible = false
	end_label.visible = false


func _process(delta: float) -> void:
	if _message_time > 0.0:
		_message_time -= delta
		message_label.modulate.a = clampf(_message_time, 0.0, 1.0)


func show_message(text: String, color: Color = Color.WHITE) -> void:
	message_label.text = text
	message_label.add_theme_color_override("font_color", color)
	message_label.modulate.a = 1.0
	_message_time = 3.5


func set_blind(on: bool, text: String = "") -> void:
	blind.visible = on
	blind_label.text = text


func show_end(text: String, color: Color) -> void:
	end_label.text = text
	end_label.add_theme_color_override("font_color", color)
	end_label.visible = true
