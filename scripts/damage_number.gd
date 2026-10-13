extends Node2D
## Chữ số bay lên rồi mờ dần (sát thương, trừ máu).

const DURATION := 0.9

var text := "-10"
var color := Color.WHITE
var _t := 0.0


func _ready() -> void:
	z_index = 60
	position += Vector2(randf_range(-10, 10), 0)


func _process(delta: float) -> void:
	_t += delta
	position.y -= 40.0 * delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var a := 1.0 - _t / DURATION
	var font := ThemeDB.fallback_font
	var fs := 18
	var size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var p := Vector2(-size.x / 2.0, 0)
	draw_string_outline(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, a))
	draw_string(font, p, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(color, a))
