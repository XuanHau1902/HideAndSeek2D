@tool
extends StaticBody2D
## Đồ vật thật trên bản đồ. Người tìm đánh nhầm thì chỉ rung lên, không bị phá.
## Có @tool để thấy hình ngay trong trình chỉnh sửa: chọn node rồi đổi "Prop Type" ở Inspector.
## Có thể xoay đồ vật (nên xoay theo bội số 90°), người trốn hóa trang sẽ copy luôn góc xoay.

const PropTypes = preload("res://scripts/prop_types.gd")

@export_enum("sofa", "armchair", "tv", "bookshelf", "coffee_table", "lamp", "plant",
	"bed", "nightstand", "wardrobe", "desk",
	"dining_table", "chair", "fridge", "stove", "counter",
	"toilet", "bathtub", "washer",
	"box", "crate", "barrel", "bin", "bush",
	"shower", "laundry_basket", "towel_shelf",
	"dresser", "teddy", "guitar", "beanbag",
	"microwave", "water_cooler", "rice_sack", "gas_tank",
	"piano", "fish_tank", "speaker", "fan",
	"ironing_board", "drying_rack", "bucket", "toolbox",
	"motorbike", "bicycle", "flower_pot", "water_jar", "bench")
var prop_type: String = "box":
	set(value):
		prop_type = value
		_rebuild()

var broken := false
var highlighted := false:
	set(value):
		if highlighted != value:
			highlighted = value
			queue_redraw()

var _shape_owner := -1
var _shake := 0.0
const SHAKE_TIME := 0.35


func _ready() -> void:
	_rebuild()
	set_process(false)


func _rebuild() -> void:
	if _shape_owner == -1:
		_shape_owner = create_shape_owner(self)
	shape_owner_clear_shapes(_shape_owner)
	shape_owner_add_shape(_shape_owner, PropTypes.make_shape(prop_type))
	queue_redraw()


func contains_point(world_point: Vector2) -> bool:
	return not broken and PropTypes.contains_point(prop_type, to_local(world_point))


## Góc xoay làm tròn về bội số 90° (người trốn copy góc này).
func snapped_rotation() -> float:
	return wrapf(snappedf(rotation, PI / 2.0), 0.0, TAU)


## Rung lên khi bị đánh nhầm (chỉ là hiệu ứng hình ảnh).
func bump() -> void:
	_shake = SHAKE_TIME
	set_process(true)


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta)
	queue_redraw()
	if _shake <= 0.0:
		set_process(false)


func _draw() -> void:
	if _shake > 0.0:
		var k := _shake / SHAKE_TIME
		draw_set_transform(Vector2(sin(_shake * 70.0) * 4.0 * k, 0), sin(_shake * 50.0) * 0.08 * k)
	PropTypes.draw(self, prop_type)
	draw_set_transform(Vector2.ZERO, 0.0)
	if highlighted:
		var d := PropTypes.get_data(prop_type)
		if d["shape"] == "circle":
			draw_arc(Vector2.ZERO, d["radius"] + 5.0, 0, TAU, 40, Color(1, 1, 0.6, 0.95), 2.5)
		else:
			var s: Vector2 = d["size"]
			draw_rect(Rect2(-s / 2.0, s).grow(5.0), Color(1, 1, 0.6, 0.95), false, 2.5)
