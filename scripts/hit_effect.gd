extends Node2D
## Hiệu ứng khi người tìm đánh: 0 = đánh hụt, 1 = đánh nhầm đồ vật thật, 2 = tìm thấy người trốn (đồ vỡ tan).

const DURATION := 0.6

var kind := 0
var _t := 0.0
var _bits: Array = []


func _ready() -> void:
	z_index = 10
	var n := 18 if kind == 2 else 0
	for i in n:
		var a := randf() * TAU
		_bits.append({"dir": Vector2(cos(a), sin(a)) * randf_range(60, 180), "size": randf_range(3, 7)})


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := _t / DURATION
	var alpha := 1.0 - k
	match kind:
		0:
			draw_arc(Vector2.ZERO, 8.0 + 18.0 * k, 0, TAU, 24, Color(1, 1, 1, alpha * 0.8), 2.0)
		1:
			# dấu "bốp" đỏ: đánh nhầm đồ thật
			draw_arc(Vector2.ZERO, 10.0 + 22.0 * k, 0, TAU, 24, Color(1, 0.35, 0.3, alpha), 3.0)
			var c := 7.0 + 4.0 * k
			draw_line(Vector2(-c, -c), Vector2(c, c), Color(1, 0.35, 0.3, alpha), 3.0)
			draw_line(Vector2(-c, c), Vector2(c, -c), Color(1, 0.35, 0.3, alpha), 3.0)
		2:
			# đồ vật giả vỡ tan: mảnh vụn nâu + vầng sáng vàng
			draw_circle(Vector2.ZERO, 14.0 + 40.0 * k, Color(1, 0.95, 0.3, alpha * 0.5))
			for i in _bits.size():
				var b: Dictionary = _bits[i]
				var p: Vector2 = b["dir"] * k * 1.3
				if i % 2 == 0:
					draw_rect(Rect2(p - Vector2.ONE * b["size"] / 2.0, Vector2.ONE * b["size"]), Color(0.55, 0.35, 0.2, alpha))
				else:
					draw_circle(p, b["size"] * 0.7, Color(1, 0.9, 0.2, alpha))
