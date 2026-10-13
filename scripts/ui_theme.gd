extends RefCounted
## Bảng màu và giao diện chung (nút, ô nhập, thẻ) theo phong cách của game:
## tường đỏ sẫm, sàn gỗ, giấy kem.

const CREAM := Color("#f6ecd6")
const CREAM_DARK := Color("#e9dbbd")
const MAROON := Color("#7c2329")
const MAROON_DARK := Color("#3a0f12")
const WOOD := Color("#c97d3c")
const WOOD_DARK := Color("#8a5126")
const TEXT := Color("#3b2516")
const TEXT_SOFT := Color("#7a6550")
const SEEKER := Color("#d9473c")
const HIDER := Color("#3b88d6")


static func box(bg: Color, border: Color = Color.TRANSPARENT, border_w: int = 0, radius: int = 10, pad: Vector2 = Vector2(14, 8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_right = pad.x
	s.content_margin_top = pad.y
	s.content_margin_bottom = pad.y
	return s


static func _button_styles(t: Theme, type: String, base: Color, text: Color) -> void:
	var normal := box(base, base.darkened(0.35), 0, 10)
	normal.border_width_bottom = 5          # gờ dưới kiểu nút bấm "nổi"
	var hover := normal.duplicate()
	hover.bg_color = base.lightened(0.12)
	var pressed := normal.duplicate()
	pressed.bg_color = base.darkened(0.12)
	pressed.border_width_bottom = 2
	pressed.content_margin_top += 3
	var disabled := normal.duplicate()
	disabled.bg_color = Color("#b9ad98")
	disabled.border_color = Color("#9a8f7c")
	t.set_stylebox("normal", type, normal)
	t.set_stylebox("hover", type, hover)
	t.set_stylebox("pressed", type, pressed)
	t.set_stylebox("disabled", type, disabled)
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, type, text)
	t.set_color("font_disabled_color", type, Color("#f1e9da"))
	t.set_font_size("font_size", type, 20)


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)

	_button_styles(t, "Button", MAROON, CREAM)
	t.set_type_variation("WoodButton", "Button")
	_button_styles(t, "WoodButton", WOOD, CREAM)

	# Nút phụ: chữ đỏ sẫm, không nền
	t.set_type_variation("GhostButton", "Button")
	var ghost := box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 8, Vector2(10, 6))
	var ghost_hover := box(Color(MAROON, 0.08), Color.TRANSPARENT, 0, 8, Vector2(10, 6))
	t.set_stylebox("normal", "GhostButton", ghost)
	t.set_stylebox("hover", "GhostButton", ghost_hover)
	t.set_stylebox("pressed", "GhostButton", ghost_hover)
	t.set_stylebox("focus", "GhostButton", StyleBoxEmpty.new())
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		t.set_color(c, "GhostButton", MAROON)
	t.set_font_size("font_size", "GhostButton", 17)

	var edit := box(Color("#fffaf0"), WOOD_DARK, 2, 8, Vector2(14, 10))
	var edit_focus := box(Color("#ffffff"), MAROON, 3, 8, Vector2(14, 10))
	t.set_stylebox("normal", "LineEdit", edit)
	t.set_stylebox("focus", "LineEdit", edit_focus)
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", Color(TEXT_SOFT, 0.7))
	t.set_color("caret_color", "LineEdit", MAROON)
	t.set_color("selection_color", "LineEdit", Color(WOOD, 0.4))
	t.set_font_size("font_size", "LineEdit", 20)

	# Thẻ giấy kem viền đỏ sẫm
	var card := box(CREAM, MAROON, 6, 16, Vector2(34, 28))
	card.shadow_color = Color(0, 0, 0, 0.35)
	card.shadow_size = 14
	card.shadow_offset = Vector2(0, 6)
	t.set_stylebox("panel", "PanelContainer", card)
	# Khung phụ bên trong thẻ
	t.set_type_variation("InsetPanel", "PanelContainer")
	t.set_stylebox("panel", "InsetPanel", box(CREAM_DARK, Color("#d6c39c"), 2, 12, Vector2(20, 16)))

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font_size("normal_font_size", "RichTextLabel", 17)
	t.set_font_size("bold_font_size", "RichTextLabel", 17)
	return t
