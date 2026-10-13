extends Control
## Biểu tượng vai: người tìm cầm búa, hoặc thùng giấy có đôi mắt (người trốn).

const PropTypes = preload("res://scripts/prop_types.gd")

var role := "seeker":
	set(v):
		role = v
		queue_redraw()
var icon_scale := 1.0:
	set(v):
		icon_scale = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size / 2.0
	draw_set_transform(c, 0.0, Vector2.ONE * icon_scale)
	if role == "seeker":
		var col := Color("#ff5a4a")
		draw_circle(Vector2(4, 5), 30, Color(0, 0, 0, 0.2))
		draw_circle(Vector2.ZERO, 30, col.darkened(0.45))
		draw_circle(Vector2.ZERO, 26, col)
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(10, 10 * s), 7, Color.WHITE)
			draw_circle(Vector2(13, 10 * s), 3.5, Color(0.1, 0.1, 0.15))
		# lông mày "nghiêm túc"
		draw_line(Vector2(3, -19), Vector2(17, -14), Color(0.25, 0.08, 0.08), 3.0)
		draw_line(Vector2(3, 19), Vector2(17, 14), Color(0.25, 0.08, 0.08), 3.0)
		# búa
		draw_line(Vector2(24, 18), Vector2(52, 18), Color("#6b4226"), 6.0)
		draw_rect(Rect2(46, 6, 16, 24), Color("#9aa3ad"))
		draw_rect(Rect2(46, 6, 16, 24), Color("#4d555f"), false, 2.0)
	else:
		draw_set_transform(c, 0.0, Vector2.ONE * icon_scale * 1.5)
		PropTypes.draw(self, "box")
		for s in [-1.0, 1.0]:
			draw_circle(Vector2(9 * s, -2), 5, Color.WHITE)
			draw_circle(Vector2(9 * s + 1.5, -1), 2.5, Color(0.1, 0.1, 0.15))
		# vài vệt khói nhỏ
		for p in [Vector2(-24, -18), Vector2(24, -20), Vector2(-28, 10)]:
			draw_circle(p, 7, Color(0.62, 0.64, 0.7, 0.9))
			draw_circle(p, 5.5, Color(0.97, 0.97, 0.99))
	draw_set_transform(Vector2.ZERO, 0.0)
