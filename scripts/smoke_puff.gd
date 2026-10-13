extends Node2D
## Làn khói "bùm" khi người trốn biến hình (kiểu thuật biến thân).
## size: bán kính đại khái của đám khói (theo kích thước đồ vật).

const DURATION := 0.5

var size := 40.0
var _t := 0.0
var _puffs: Array = []
var _rays: Array = []


func _ready() -> void:
	z_index = 50   # nổi trên đồ vật và người chơi
	var n := 16
	for i in n:
		var a := TAU * i / n + randf_range(-0.2, 0.2)
		_puffs.append({
			"dir": Vector2(cos(a), sin(a)),
			"dist": size * randf_range(0.6, 1.1),
			"r0": size * randf_range(0.18, 0.28),
			"r1": size * randf_range(0.45, 0.65),
			"rise": randf_range(8.0, 22.0),
			"delay": randf_range(0.0, 0.04),
		})
	# vài cụm khói ở giữa cho dày
	for i in 5:
		var a := randf() * TAU
		_puffs.append({
			"dir": Vector2(cos(a), sin(a)),
			"dist": size * randf_range(0.0, 0.3),
			"r0": size * 0.3,
			"r1": size * randf_range(0.5, 0.65),
			"rise": randf_range(10.0, 26.0),
			"delay": 0.015,
		})
	for i in 8:
		var a := TAU * i / 8.0 + 0.2
		_rays.append(Vector2(cos(a), sin(a)))


func _process(delta: float) -> void:
	_t += delta
	if _t >= DURATION:
		queue_free()
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / DURATION, 0.0, 1.0)
	# Chớp sáng + các tia "bùm" lúc đầu
	if k < 0.25:
		var fk := k / 0.25
		draw_circle(Vector2.ZERO, size * (0.4 + 0.8 * fk), Color(1, 1, 0.92, 0.85 * (1.0 - fk)))
		for d in _rays:
			var a: Vector2 = d * size * (0.7 + 0.9 * fk)
			var b: Vector2 = d * size * (1.0 + 1.1 * fk)
			draw_line(a, b, Color(1, 1, 1, 0.9 * (1.0 - fk)), 3.0)
	# Các cụm khói: bung ra nhanh, nở to, bay lên rồi tan
	var outline := Color(0.62, 0.64, 0.7)
	for pass_i in 2:
		for p in _puffs:
			var lk := clampf((_t - p["delay"]) / (DURATION - p["delay"]), 0.0, 1.0)
			if lk <= 0.0:
				continue
			var e := 1.0 - pow(1.0 - lk, 3.0)          # bung nhanh, chậm dần
			var pos: Vector2 = p["dir"] * p["dist"] * e + Vector2(0, -p["rise"] * lk)
			var r: float = lerpf(p["r0"], p["r1"], e) * (1.0 - 0.35 * lk * lk)
			var alpha := 1.0 if lk < 0.55 else 1.0 - (lk - 0.55) / 0.45
			if pass_i == 0:
				draw_circle(pos, r + 2.5, Color(outline, alpha))   # viền xám kiểu hoạt hình
			else:
				draw_circle(pos, r, Color(0.97, 0.97, 0.99, alpha))
				draw_circle(pos + Vector2(-r * 0.3, -r * 0.3), r * 0.35, Color(1, 1, 1, alpha))
