extends RefCounted
## Danh sách các loại đồ vật mà người trốn có thể hóa thành.
## Quy ước: khi chưa xoay, mặt trước của đồ vật hướng XUỐNG dưới (lưng ghế, đầu giường ở phía trên).
## Thêm loại mới: thêm một dòng vào TYPES, viết cách vẽ trong hàm draw(),
## rồi thêm tên vào @export_enum trong prop.gd.

const TYPES := {
	# Phòng khách
	"sofa": {"name": "Ghế sofa", "shape": "rect", "size": Vector2(112, 48)},
	"armchair": {"name": "Ghế bành", "shape": "rect", "size": Vector2(50, 50)},
	"tv": {"name": "Tivi", "shape": "rect", "size": Vector2(76, 24)},
	"bookshelf": {"name": "Kệ sách", "shape": "rect", "size": Vector2(96, 30)},
	"coffee_table": {"name": "Bàn trà", "shape": "rect", "size": Vector2(70, 40)},
	"lamp": {"name": "Đèn cây", "shape": "circle", "radius": 15.0},
	"plant": {"name": "Chậu cây", "shape": "circle", "radius": 20.0},
	# Phòng ngủ
	"bed": {"name": "Giường", "shape": "rect", "size": Vector2(76, 110)},
	"nightstand": {"name": "Tủ đầu giường", "shape": "rect", "size": Vector2(32, 32)},
	"wardrobe": {"name": "Tủ quần áo", "shape": "rect", "size": Vector2(90, 38)},
	"desk": {"name": "Bàn làm việc", "shape": "rect", "size": Vector2(80, 42)},
	# Bếp
	"dining_table": {"name": "Bàn ăn", "shape": "rect", "size": Vector2(100, 60)},
	"chair": {"name": "Ghế", "shape": "rect", "size": Vector2(30, 30)},
	"fridge": {"name": "Tủ lạnh", "shape": "rect", "size": Vector2(46, 46)},
	"stove": {"name": "Bếp nấu", "shape": "rect", "size": Vector2(46, 46)},
	"counter": {"name": "Bồn rửa", "shape": "rect", "size": Vector2(76, 40)},
	# Phòng tắm, phòng giặt
	"toilet": {"name": "Bồn cầu", "shape": "rect", "size": Vector2(32, 44)},
	"bathtub": {"name": "Bồn tắm", "shape": "rect", "size": Vector2(60, 110)},
	"washer": {"name": "Máy giặt", "shape": "rect", "size": Vector2(44, 44)},
	# Đồ lặt vặt, ngoài sân
	"box": {"name": "Thùng giấy", "shape": "rect", "size": Vector2(40, 40)},
	"crate": {"name": "Thùng gỗ", "shape": "rect", "size": Vector2(52, 52)},
	"barrel": {"name": "Thùng phuy", "shape": "circle", "radius": 22.0},
	"bin": {"name": "Thùng rác", "shape": "circle", "radius": 16.0},
	"bush": {"name": "Bụi cây", "shape": "circle", "radius": 30.0},
	# --- Thêm: phòng tắm
	"shower": {"name": "Buồng tắm vòi sen", "shape": "rect", "size": Vector2(64, 64)},
	"laundry_basket": {"name": "Giỏ đồ bẩn", "shape": "circle", "radius": 17.0},
	"towel_shelf": {"name": "Kệ khăn tắm", "shape": "rect", "size": Vector2(56, 24)},
	# --- Thêm: phòng ngủ
	"dresser": {"name": "Tủ ngăn kéo", "shape": "rect", "size": Vector2(72, 36)},
	"teddy": {"name": "Gấu bông", "shape": "circle", "radius": 15.0},
	"guitar": {"name": "Đàn guitar", "shape": "rect", "size": Vector2(28, 72), "no_shadow": true},
	"beanbag": {"name": "Ghế lười", "shape": "circle", "radius": 24.0},
	# --- Thêm: bếp
	"microwave": {"name": "Lò vi sóng", "shape": "rect", "size": Vector2(42, 30)},
	"water_cooler": {"name": "Cây nước nóng lạnh", "shape": "circle", "radius": 16.0},
	"rice_sack": {"name": "Bao gạo", "shape": "rect", "size": Vector2(36, 48)},
	"gas_tank": {"name": "Bình gas", "shape": "circle", "radius": 15.0},
	# --- Thêm: phòng khách
	"piano": {"name": "Đàn piano", "shape": "rect", "size": Vector2(110, 46)},
	"fish_tank": {"name": "Bể cá", "shape": "rect", "size": Vector2(84, 32)},
	"speaker": {"name": "Loa thùng", "shape": "rect", "size": Vector2(28, 28)},
	"fan": {"name": "Quạt cây", "shape": "circle", "radius": 18.0, "no_shadow": true},
	# --- Thêm: phòng giặt, kho
	"ironing_board": {"name": "Bàn ủi đồ", "shape": "rect", "size": Vector2(100, 30), "no_shadow": true},
	"drying_rack": {"name": "Giá phơi đồ", "shape": "rect", "size": Vector2(84, 36), "no_shadow": true},
	"bucket": {"name": "Xô nước", "shape": "circle", "radius": 14.0},
	"toolbox": {"name": "Hộp đồ nghề", "shape": "rect", "size": Vector2(46, 26)},
	# --- Thêm: ngoài sân
	"motorbike": {"name": "Xe máy", "shape": "rect", "size": Vector2(40, 94), "no_shadow": true},
	"bicycle": {"name": "Xe đạp", "shape": "rect", "size": Vector2(24, 76), "no_shadow": true},
	"flower_pot": {"name": "Chậu hoa", "shape": "circle", "radius": 18.0},
	"water_jar": {"name": "Chum nước", "shape": "circle", "radius": 24.0},
	"bench": {"name": "Ghế đá", "shape": "rect", "size": Vector2(92, 30)},
}

const OUTLINE_W := 3.0


static func get_data(type_id: String) -> Dictionary:
	if TYPES.has(type_id):
		return TYPES[type_id]
	return TYPES["box"]


## Kích thước khung bao (chưa xoay).
static func get_extent(type_id: String) -> Vector2:
	var d := get_data(type_id)
	if d["shape"] == "circle":
		return Vector2.ONE * d["radius"] * 2.0
	return d["size"]


## Tạo hình va chạm cho loại đồ vật. shrink > 0 làm hình nhỏ lại một chút.
static func make_shape(type_id: String, shrink: float = 0.0) -> Shape2D:
	var d := get_data(type_id)
	if d["shape"] == "circle":
		var c := CircleShape2D.new()
		c.radius = max(4.0, d["radius"] - shrink)
		return c
	var r := RectangleShape2D.new()
	var s: Vector2 = d["size"]
	r.size = Vector2(max(8.0, s.x - shrink * 2.0), max(8.0, s.y - shrink * 2.0))
	return r


## Kiểm tra một điểm (tọa độ so với tâm đồ vật, CHƯA xoay) có nằm trong đồ vật không.
static func contains_point(type_id: String, local_point: Vector2, padding: float = 4.0) -> bool:
	var d := get_data(type_id)
	if d["shape"] == "circle":
		return local_point.length() <= d["radius"] + padding
	var half: Vector2 = d["size"] / 2.0 + Vector2(padding, padding)
	return absf(local_point.x) <= half.x and absf(local_point.y) <= half.y


# ---------------------------------------------------------------- Vẽ

static func _box(ci: CanvasItem, r: Rect2, fill: Color, ow: float = OUTLINE_W) -> void:
	ci.draw_rect(r, fill.darkened(0.55))
	ci.draw_rect(r.grow(-ow), fill)


static func _disc(ci: CanvasItem, c: Vector2, rad: float, fill: Color, ow: float = OUTLINE_W) -> void:
	ci.draw_circle(c, rad, fill.darkened(0.55))
	ci.draw_circle(c, maxf(1.0, rad - ow), fill)


static func _r(x: float, y: float, w: float, h: float) -> Rect2:
	return Rect2(x, y, w, h)


## Vẽ đồ vật (tâm tại gốc tọa độ). Phải gọi trong hàm _draw() của ci.
static func draw(ci: CanvasItem, type_id: String) -> void:
	var d := get_data(type_id)
	var shadow := Color(0, 0, 0, 0.22)
	if d.get("no_shadow", false):
		pass   # đồ mảnh/có khe hở: không vẽ bóng khối
	elif d["shape"] == "circle":
		ci.draw_circle(Vector2(3, 4), d["radius"], shadow)
	else:
		var s0: Vector2 = d["size"]
		ci.draw_rect(Rect2(-s0 / 2.0 + Vector2(3, 4), s0), shadow)

	var s: Vector2 = d.get("size", Vector2.ZERO)
	var hx := s.x / 2.0
	var hy := s.y / 2.0
	match type_id:
		"sofa":
			var red := Color("#b8343c")
			_box(ci, _r(-hx, -hy, s.x, s.y), red)
			_box(ci, _r(-hx, -hy, s.x, 15), red.darkened(0.2))             # lưng
			_box(ci, _r(-hx, -hy, 15, s.y), red.darkened(0.2))             # tay trái
			_box(ci, _r(hx - 15, -hy, 15, s.y), red.darkened(0.2))         # tay phải
			_box(ci, _r(-hx + 15, -hy + 15, (s.x - 30) / 2.0, s.y - 15), red.lightened(0.1), 2.0)
			_box(ci, _r(0, -hy + 15, (s.x - 30) / 2.0, s.y - 15), red.lightened(0.1), 2.0)
		"armchair":
			var blue := Color("#3f6fb8")
			_box(ci, _r(-hx, -hy, s.x, s.y), blue.darkened(0.2))
			_box(ci, _r(-hx + 12, -hy + 13, s.x - 24, s.y - 13), blue.lightened(0.1), 2.0)
		"tv":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#2e2e33"))
			ci.draw_rect(_r(-hx + 5, hy - 8, s.x - 10, 4), Color("#7fb8e6"))
			ci.draw_circle(Vector2(hx - 9, -hy + 8), 2.0, Color("#e05555"))
		"bookshelf":
			var wood := Color("#7d5131")
			_box(ci, _r(-hx, -hy, s.x, s.y), wood)
			var cols := [Color("#d94f4f"), Color("#4f8bd9"), Color("#e8c547"), Color("#5cb85c"), Color("#9b59b6"), Color("#e67e22")]
			var widths := [7, 9, 6, 8, 7, 10, 6, 8, 9, 7, 6]
			var x := -hx + 5.0
			var i := 0
			while x < hx - 8.0:
				var w: float = widths[i % widths.size()]
				w = minf(w, hx - 5.0 - x)
				ci.draw_rect(_r(x, -hy + 5, w - 1, s.y - 10), cols[i % cols.size()])
				x += w
				i += 1
		"coffee_table", "desk", "dining_table":
			var tc := {"coffee_table": Color("#a5703f"), "desk": Color("#c7a06e"), "dining_table": Color("#94643a")}
			var wood2: Color = tc[type_id]
			_box(ci, _r(-hx, -hy, s.x, s.y), wood2)
			for k in range(1, 3):
				var yy := -hy + s.y * k / 3.0
				ci.draw_line(Vector2(-hx + 4, yy), Vector2(hx - 4, yy), wood2.darkened(0.2), 1.5)
			if type_id == "dining_table":
				for p in [Vector2(-hx * 0.5, -hy * 0.45), Vector2(hx * 0.5, -hy * 0.45), Vector2(-hx * 0.5, hy * 0.45), Vector2(hx * 0.5, hy * 0.45)]:
					_disc(ci, p, 9.0, Color("#f4f4f4"), 2.0)
			elif type_id == "desk":
				_box(ci, _r(-hx + 10, -hy + 8, 30, 20), Color("#8d939b"), 2.0)   # laptop
				ci.draw_rect(_r(hx - 30, -hy + 9, 18, 22), Color("#fafafa"))       # giấy
			else:
				ci.draw_rect(_r(-12, -8, 24, 16), Color("#e9e2c9"))                # tạp chí
		"lamp":
			_disc(ci, Vector2.ZERO, d["radius"], Color("#f1dfa8"))
			ci.draw_circle(Vector2.ZERO, d["radius"] * 0.5, Color("#fff4cf"))
			ci.draw_circle(Vector2.ZERO, 2.5, Color("#6b5a3a"))
		"plant":
			var rr: float = d["radius"]
			_disc(ci, Vector2.ZERO, rr * 0.75, Color("#a0522d"))
			for k in 7:
				var a := TAU * k / 7.0
				_disc(ci, Vector2(cos(a), sin(a)) * rr * 0.5, rr * 0.45, Color("#3f9b4b"), 2.0)
			ci.draw_circle(Vector2.ZERO, rr * 0.35, Color("#58b862"))
		"bed":
			var frame := Color("#6e4528")
			_box(ci, _r(-hx, -hy, s.x, s.y), frame)
			_box(ci, _r(-hx + 5, -hy + 30, s.x - 10, s.y - 35), Color("#5b8bd6"), 2.0)   # chăn
			ci.draw_rect(_r(-hx + 6, -hy + 31, s.x - 12, 10), Color("#7ea6e6"))           # mép chăn
			_box(ci, _r(-hx + 9, -hy + 9, s.x - 18, 18), Color("#f3f3f3"), 2.0)         # gối
		"nightstand":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#8a5a33"))
			ci.draw_circle(Vector2(0, 0), 8.0, Color("#f1dfa8"))
			ci.draw_circle(Vector2(0, 0), 3.0, Color("#fff4cf"))
		"wardrobe":
			var wd := Color("#6b4a2f")
			_box(ci, _r(-hx, -hy, s.x, s.y), wd)
			ci.draw_line(Vector2(0, -hy + 3), Vector2(0, hy - 3), wd.darkened(0.5), 2.0)
			ci.draw_circle(Vector2(-6, hy - 9), 2.5, Color("#e0c068"))
			ci.draw_circle(Vector2(6, hy - 9), 2.5, Color("#e0c068"))
		"chair":
			var cw := Color("#8a5a33")
			_box(ci, _r(-hx, -hy, s.x, s.y), cw.lightened(0.1))
			_box(ci, _r(-hx, -hy, s.x, 9), cw.darkened(0.15), 2.0)
		"fridge":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#e8edf0"))
			ci.draw_rect(_r(-hx + 4, -hy + 4, s.x - 8, 6), Color("#cfd8de"))
			ci.draw_rect(_r(-10, hy - 9, 20, 4), Color("#8c959c"))
		"stove":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#d6dadd"))
			for p in [Vector2(-10, -10), Vector2(10, -10), Vector2(-10, 10), Vector2(10, 10)]:
				ci.draw_circle(p, 7.5, Color("#33363a"))
				ci.draw_arc(p, 5.0, 0, TAU, 16, Color("#6d7278"), 1.5)
		"counter":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#ddd3c2"))
			_box(ci, _r(-18, -hy + 8, 36, s.y - 14), Color("#a9c1cf"), 2.0)
			ci.draw_circle(Vector2(0, -hy + 6), 3.0, Color("#7d8790"))
		"toilet":
			var wh := Color("#f2f4f5")
			_box(ci, _r(-hx, -hy, s.x, 14), wh)
			_disc(ci, Vector2(0, 6), 15.0, wh)
			ci.draw_circle(Vector2(0, 7), 9.0, Color("#bfe0ee"))
		"bathtub":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#f2f4f5"))
			_box(ci, _r(-hx + 7, -hy + 7, s.x - 14, s.y - 14), Color("#a9d6ea"), 2.0)
			ci.draw_circle(Vector2(0, hy - 20), 3.0, Color("#6f7d86"))
			ci.draw_rect(_r(-5, -hy + 2, 10, 6), Color("#9aa3ab"))
		"washer":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#eef1f3"))
			ci.draw_rect(_r(-hx + 4, -hy + 4, s.x - 8, 7), Color("#cdd5db"))
			_disc(ci, Vector2(0, 4), 13.0, Color("#9aa5ad"), 3.0)
			ci.draw_circle(Vector2(0, 4), 8.0, Color("#5e7d94"))
		"box":
			var cb := Color("#c48c50")
			_box(ci, _r(-hx, -hy, s.x, s.y), cb)
			ci.draw_rect(_r(-hx + 3, -4, s.x - 6, 8), cb.lightened(0.25))
		"crate":
			var cr := Color("#a0703c")
			_box(ci, _r(-hx, -hy, s.x, s.y), cr)
			ci.draw_rect(_r(-hx + 7, -hy + 7, s.x - 14, s.y - 14), cr.darkened(0.3), false, 2.0)
			ci.draw_line(Vector2(-hx + 8, -hy + 8), Vector2(hx - 8, hy - 8), cr.darkened(0.3), 3.0)
		"barrel":
			var rr2: float = d["radius"]
			_disc(ci, Vector2.ZERO, rr2, Color("#3d6fb6"))
			ci.draw_arc(Vector2.ZERO, rr2 * 0.62, 0, TAU, 28, Color("#2a4d80"), 2.0)
			ci.draw_circle(Vector2(rr2 * 0.3, -rr2 * 0.3), 3.0, Color("#2a4d80"))
		"bin":
			var rr3: float = d["radius"]
			_disc(ci, Vector2.ZERO, rr3, Color("#7d8794"))
			ci.draw_circle(Vector2.ZERO, rr3 * 0.55, Color("#4d555f"))
		"bush":
			var rr4: float = d["radius"]
			var g := Color("#3c8a3a")
			for k in 9:
				var a := TAU * k / 9.0
				ci.draw_circle(Vector2(cos(a), sin(a)) * rr4 * 0.62, rr4 * 0.45, g.darkened(0.45))
			ci.draw_circle(Vector2.ZERO, rr4 * 0.82, g.darkened(0.45))
			for k in 9:
				var a := TAU * k / 9.0
				ci.draw_circle(Vector2(cos(a), sin(a)) * rr4 * 0.6, rr4 * 0.38, g)
			ci.draw_circle(Vector2.ZERO, rr4 * 0.72, g)
			ci.draw_circle(Vector2(-rr4 * 0.25, -rr4 * 0.25), rr4 * 0.25, g.lightened(0.18))
		_:
			_draw_extra(ci, type_id, d, s, hx, hy)


## Các loại đồ vật thêm sau.
static func _draw_extra(ci: CanvasItem, type_id: String, d: Dictionary, s: Vector2, hx: float, hy: float) -> void:
	var dark := Color("#2b2d31")
	match type_id:
		"shower":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#e9eef1"))
			ci.draw_rect(_r(-hx + 6, -hy + 6, s.x - 12, s.y - 12), Color("#c9dbe4"))
			for i in range(-2, 3):
				ci.draw_line(Vector2(-hx + 8, i * 9.0), Vector2(hx - 8, i * 9.0), Color("#b5cbd6"), 1.0)
			ci.draw_circle(Vector2.ZERO, 4.0, Color("#7d8a93"))
			ci.draw_circle(Vector2(0, -hy + 10), 6.0, Color("#9aa7b0"))
		"laundry_basket":
			var r: float = d["radius"]
			_disc(ci, Vector2.ZERO, r, Color("#c9a46a"))
			ci.draw_arc(Vector2.ZERO, r * 0.7, 0, TAU, 24, Color("#a8854f"), 2.0)
			ci.draw_circle(Vector2(-3, -2), r * 0.45, Color("#e86b6b"))
			ci.draw_circle(Vector2(4, 3), r * 0.35, Color("#6ba3e8"))
		"towel_shelf":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#8a5a33"))
			var cols := [Color("#f2f2f2"), Color("#7ec8e3"), Color("#f5b7c5")]
			for i in 3:
				ci.draw_rect(_r(-hx + 5 + i * 16.0, -hy + 4, 14, s.y - 8), cols[i])
		"dresser":
			var wd := Color("#9b6b43")
			_box(ci, _r(-hx, -hy, s.x, s.y), wd)
			ci.draw_line(Vector2(-hx + 3, 2), Vector2(hx - 3, 2), wd.darkened(0.4), 1.5)
			ci.draw_line(Vector2(-12, -hy + 3), Vector2(-12, hy - 3), wd.darkened(0.4), 1.5)
			ci.draw_line(Vector2(12, -hy + 3), Vector2(12, hy - 3), wd.darkened(0.4), 1.5)
			ci.draw_circle(Vector2(-hx + 14, -8), 4.0, Color("#e9d8a6"))   # hộp trang sức
			ci.draw_rect(_r(hx - 20, -12, 10, 8), Color("#7ec8e3"))       # khung ảnh
		"teddy":
			var bc := Color("#b07a4a")
			_disc(ci, Vector2(-9, -10), 6.0, bc, 2.0)
			_disc(ci, Vector2(9, -10), 6.0, bc, 2.0)
			_disc(ci, Vector2.ZERO, d["radius"] - 2.0, bc)
			ci.draw_circle(Vector2(0, 3), 5.0, Color("#e2c19a"))
			ci.draw_circle(Vector2(-4, -3), 1.8, dark)
			ci.draw_circle(Vector2(4, -3), 1.8, dark)
		"guitar":
			var body := Color("#c0622f")
			ci.draw_rect(_r(-3, -hy, 6, s.y * 0.5), Color("#5a3a20"))
			_disc(ci, Vector2(0, hy - 13), 13.0, body)
			_disc(ci, Vector2(0, hy - 30), 10.0, body)
			ci.draw_circle(Vector2(0, hy - 22), 4.0, dark)
			ci.draw_rect(_r(-5, -hy, 10, 9), Color("#3b2614"))
		"beanbag":
			var r2: float = d["radius"]
			_disc(ci, Vector2.ZERO, r2, Color("#8e5bb5"))
			ci.draw_circle(Vector2(-4, 4), r2 * 0.55, Color("#a678c9"))
			ci.draw_arc(Vector2.ZERO, r2 * 0.8, PI * 1.1, PI * 1.9, 12, Color("#6c3f8f"), 2.0)
		"microwave":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#d9dcdf"))
			ci.draw_rect(_r(-hx + 4, -hy + 4, s.x - 16, s.y - 8), Color("#3a4046"))
			ci.draw_circle(Vector2(hx - 6, -4), 2.0, dark)
			ci.draw_circle(Vector2(hx - 6, 4), 2.0, dark)
		"water_cooler":
			_disc(ci, Vector2.ZERO, d["radius"], Color("#eef1f3"))
			ci.draw_circle(Vector2.ZERO, d["radius"] * 0.65, Color("#7fc3ea"))
			ci.draw_circle(Vector2(-3, -3), d["radius"] * 0.25, Color("#bfe4f7"))
		"rice_sack":
			var sc := Color("#efe6cf")
			_box(ci, _r(-hx, -hy, s.x, s.y), sc)
			ci.draw_rect(_r(-hx + 4, -hy + 2, s.x - 8, 6), sc.darkened(0.15))
			ci.draw_rect(_r(-10, -4, 20, 14), Color("#d94f4f"))
			ci.draw_rect(_r(-6, 0, 12, 6), Color("#f2d04b"))
		"gas_tank":
			_disc(ci, Vector2.ZERO, d["radius"], Color("#e0573a"))
			ci.draw_arc(Vector2.ZERO, d["radius"] * 0.6, 0, TAU, 20, Color("#a8381f"), 2.0)
			ci.draw_circle(Vector2.ZERO, 4.0, Color("#9aa3ab"))
		"piano":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#1f1f24"))
			ci.draw_rect(_r(-hx + 6, hy - 16, s.x - 12, 12), Color("#f4f4f4"))
			var x := -hx + 8.0
			while x < hx - 8.0:
				ci.draw_rect(_r(x, hy - 16, 3, 7), dark)
				x += 7.0
			ci.draw_rect(_r(-14, -hy + 6, 28, 8), Color("#e8d9b0"))   # bản nhạc
		"fish_tank":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#3d4a52"))
			ci.draw_rect(_r(-hx + 4, -hy + 4, s.x - 8, s.y - 8), Color("#4fa3d1"))
			ci.draw_rect(_r(-hx + 4, hy - 9, s.x - 8, 5), Color("#d9c38c"))
			ci.draw_circle(Vector2(-18, -2), 4.0, Color("#ff9f43"))
			ci.draw_circle(Vector2(12, 3), 3.5, Color("#ff6b6b"))
			ci.draw_circle(Vector2(26, -5), 3.0, Color("#feca57"))
		"speaker":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#34373c"))
			ci.draw_circle(Vector2(0, 2), 8.0, Color("#1c1d20"))
			ci.draw_circle(Vector2(0, 2), 3.0, Color("#55595f"))
			ci.draw_circle(Vector2(0, -9), 2.5, Color("#1c1d20"))
		"fan":
			var r3: float = d["radius"]
			ci.draw_arc(Vector2.ZERO, r3 - 1.0, 0, TAU, 32, Color("#5d6a73"), 2.5)
			for i in 3:
				var a := TAU * i / 3.0 + 0.3
				ci.draw_circle(Vector2(cos(a), sin(a)) * r3 * 0.45, r3 * 0.36, Color("#7fb8e6"))
			ci.draw_circle(Vector2.ZERO, 4.0, Color("#3d4a52"))
		"ironing_board":
			var bc2 := Color("#8fb8d8")
			ci.draw_rect(_r(-hx, -hy + 3, s.x - 16, s.y - 6), bc2.darkened(0.5))
			ci.draw_rect(_r(-hx + 2, -hy + 5, s.x - 20, s.y - 10), bc2)
			_disc(ci, Vector2(hx - 14, 0), hy - 2.0, bc2)
			ci.draw_rect(_r(-14, -7, 18, 14), Color("#e8e8e8"))   # bàn là
			ci.draw_rect(_r(-14, -3, 18, 6), Color("#c0392b"))
		"drying_rack":
			var mc := Color("#9aa3ab")
			ci.draw_rect(_r(-hx, -hy, s.x, s.y), mc, false, 2.5)
			for i in range(1, 6):
				var xx := -hx + s.x * i / 6.0
				ci.draw_line(Vector2(xx, -hy), Vector2(xx, hy), mc, 1.5)
			ci.draw_rect(_r(-hx + 6, -hy + 4, 18, s.y - 8), Color("#f5b7c5"))
			ci.draw_rect(_r(-2, -hy + 4, 14, s.y - 12), Color("#7ec8e3"))
			ci.draw_rect(_r(hx - 26, -hy + 4, 18, s.y - 8), Color("#f6e58d"))
		"bucket":
			_disc(ci, Vector2.ZERO, d["radius"], Color("#3d85c6"))
			ci.draw_circle(Vector2.ZERO, d["radius"] * 0.65, Color("#9fd3ef"))
			ci.draw_arc(Vector2.ZERO, d["radius"] + 2.0, PI * 1.15, PI * 1.85, 10, Color("#7d8794"), 2.0)
		"toolbox":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#c0392b"))
			ci.draw_rect(_r(-12, -hy + 2, 24, 5), Color("#7d8794"))
			ci.draw_line(Vector2(-hx + 3, 2), Vector2(hx - 3, 2), Color("#8e2a1f"), 1.5)
		"motorbike":
			ci.draw_rect(_r(-6, -hy, 12, 18), dark)                       # bánh trước
			ci.draw_rect(_r(-6, hy - 20, 12, 20), dark)                   # bánh sau
			_box(ci, _r(-hx + 6, -hy + 14, s.x - 12, s.y - 30), Color("#c0392b"))
			ci.draw_rect(_r(-9, -hy + 34, 18, 30), Color("#2f3136"))      # yên
			ci.draw_line(Vector2(-hx, -hy + 18), Vector2(hx, -hy + 18), Color("#7d8794"), 4.0)  # tay lái
			ci.draw_circle(Vector2(0, -hy + 12), 4.0, Color("#fff4b3"))   # đèn
		"bicycle":
			ci.draw_rect(_r(-3, -hy, 6, 22), dark)
			ci.draw_rect(_r(-3, hy - 22, 6, 22), dark)
			ci.draw_line(Vector2(0, -hy + 16), Vector2(0, hy - 16), Color("#2e86de"), 4.0)
			ci.draw_line(Vector2(-hx, -hy + 14), Vector2(hx, -hy + 14), Color("#7d8794"), 3.0)
			ci.draw_rect(_r(-5, 4, 10, 14), Color("#2f3136"))
		"flower_pot":
			var r4: float = d["radius"]
			_disc(ci, Vector2.ZERO, r4, Color("#b5562f"))
			ci.draw_circle(Vector2.ZERO, r4 * 0.75, Color("#4b8b3b"))
			var fc := [Color("#ff6b81"), Color("#feca57"), Color("#ff9ff3"), Color("#ffffff")]
			for i in 5:
				var a2 := TAU * i / 5.0
				ci.draw_circle(Vector2(cos(a2), sin(a2)) * r4 * 0.42, 4.0, fc[i % fc.size()])
			ci.draw_circle(Vector2.ZERO, 3.5, Color("#feca57"))
		"water_jar":
			var r5: float = d["radius"]
			_disc(ci, Vector2.ZERO, r5, Color("#8c5a3c"))
			ci.draw_circle(Vector2.ZERO, r5 * 0.62, Color("#5b3a26"))
			ci.draw_circle(Vector2.ZERO, r5 * 0.5, Color("#5d8aa8"))
			ci.draw_arc(Vector2.ZERO, r5 * 0.82, 0, TAU, 28, Color("#a5714f"), 2.0)
		"bench":
			_box(ci, _r(-hx, -hy, s.x, s.y), Color("#a4a7ab"))
			ci.draw_rect(_r(-hx + 4, -hy + 4, s.x - 8, 4), Color("#c3c6ca"))
			ci.draw_rect(_r(-hx + 6, hy - 6, 10, 4), Color("#7d8187"))
			ci.draw_rect(_r(hx - 16, hy - 6, 10, 4), Color("#7d8187"))
		_:
			_box(ci, _r(-20, -20, 40, 40), Color("#c48c50"))
