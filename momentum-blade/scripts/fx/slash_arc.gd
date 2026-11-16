class_name SlashArc
extends MeshInstance3D
## The white "swoosh" that flashes in front of the player on each slash.
## Its curved shape (a slice of a flat ring, like a bit of a donut) is built in
## code below, so no 3D model file is needed.

## Colour of the swoosh.
@export var color: Color = Color(0.85, 0.95, 1.0, 0.85)
## How long the swoosh takes to fade out (seconds).
@export var fade_time: float = 0.14
## Inner edge of the ring, as a fraction of the outer edge.
@export var inner_ratio: float = 0.3
## More segments = smoother curve.
@export var segments: int = 20

var _material: StandardMaterial3D = StandardMaterial3D.new()
var _tween: Tween


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED  # visible from both sides
	_material.vertex_color_use_as_albedo = true
	_material.albedo_color = color
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh = _build_arc_mesh(Game.config.slash_arc_degrees)
	visible = false


## Shows the swoosh. direction_sign: +1 swings right-to-left, -1 left-to-right.
func play(direction_sign: float, radius: float) -> void:
	# Mirroring on X flips the swing direction; scaling sets the reach.
	scale = Vector3(direction_sign * radius, 1.0, radius)
	_material.albedo_color = color
	visible = true
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_material, "albedo_color:a", 0.0, fade_time)
	_tween.tween_callback(hide)


## Builds a flat arc with radius 1, centered on the forward (-Z) direction.
func _build_arc_mesh(arc_degrees: float) -> ArrayMesh:
	var half_angle: float = deg_to_rad(arc_degrees) * 0.5
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in segments:
		var t0: float = float(i) / segments
		var t1: float = float(i + 1) / segments
		var a0: float = lerpf(-half_angle, half_angle, t0)
		var a1: float = lerpf(-half_angle, half_angle, t1)
		# Brightest at the leading edge (left side), fading toward the trailing edge.
		var c0: Color = Color(1.0, 1.0, 1.0, 1.0 - t0)
		var c1: Color = Color(1.0, 1.0, 1.0, 1.0 - t1)
		var outer0: Vector3 = Vector3(sin(a0), 0.0, -cos(a0))
		var outer1: Vector3 = Vector3(sin(a1), 0.0, -cos(a1))
		var inner0: Vector3 = outer0 * inner_ratio
		var inner1: Vector3 = outer1 * inner_ratio
		# Two triangles make one quad segment of the ring.
		_add_vertex(st, inner0, c0)
		_add_vertex(st, outer0, c0)
		_add_vertex(st, outer1, c1)
		_add_vertex(st, inner0, c0)
		_add_vertex(st, outer1, c1)
		_add_vertex(st, inner1, c1)
	return st.commit()


func _add_vertex(st: SurfaceTool, point: Vector3, vertex_color: Color) -> void:
	st.set_color(vertex_color)
	st.add_vertex(point)
