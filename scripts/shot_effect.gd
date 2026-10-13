extends Node2D
## Vệt đạn: vẽ đường từ nòng súng tới điểm trúng rồi mờ dần.
## kinds: 0 = trúng tường/khoảng không, 1 = trúng đồ vật thật, 2 = trúng người trốn.

const DURATION := 0.16

var origin := Vector2.ZERO
var ends := PackedVector2Array()
var kinds := PackedInt32Array()
var weapon := "pistol"
var _t := 0.0


func _ready() -> void:
	z_index = 20


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION + 0.15:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / DURATION, 0.0, 1.0)
	var a := 1.0 - k
	var width := 3.0 if weapon == "rifle" else (2.0 if weapon == "shotgun" else 2.5)
	# chớp lửa đầu nòng
	if _t < 0.06:
		draw_circle(origin, 7.0, Color(1, 0.85, 0.4, 0.9))
	for i in ends.size():
		var e: Vector2 = ends[i]
		if a > 0.0:
			draw_line(origin.lerp(e, k * 0.6), e, Color(1, 0.95, 0.6, a * 0.85), width)
		var ia := clampf(1.0 - _t / (DURATION + 0.15), 0.0, 1.0)
		match kinds[i]:
			0:
				draw_circle(e, 3.0, Color(0.9, 0.9, 0.8, ia))
			1:
				draw_circle(e, 5.0, Color(1, 0.4, 0.3, ia))
			2:
				draw_circle(e, 6.0, Color(1, 0.9, 0.2, ia))
