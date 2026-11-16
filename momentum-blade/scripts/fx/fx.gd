class_name FX
extends RefCounted
## Small reusable visual effects, built from simple shapes (no imported art).
## These are "static" functions: call them from anywhere, e.g. FX.burst(...).
## Every effect removes itself when it's done.


## A one-shot burst of little glowing cubes (hit sparks, enemy explosions).
static func burst(parent: Node, at: Vector3, color: Color, amount: int = 12,
		speed: float = 6.0, cube_size: float = 0.14) -> void:
	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = 0.5
	particles.explosiveness = 1.0  # all particles at once
	particles.spread = 180.0       # in every direction
	particles.initial_velocity_min = speed * 0.4
	particles.initial_velocity_max = speed
	particles.gravity = Vector3(0.0, -18.0, 0.0)
	particles.scale_amount_min = 0.5
	particles.scale_amount_max = 1.2
	# Shrink each cube to nothing over its lifetime.
	var shrink: Curve = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))
	particles.scale_amount_curve = shrink

	var cube: BoxMesh = BoxMesh.new()
	cube.size = Vector3.ONE * cube_size
	cube.material = _glow_material(color, 2.0)
	particles.mesh = cube

	parent.add_child(particles)
	particles.global_position = at
	particles.emitting = true
	# Delete the node once the particles are gone.
	var cleanup: SceneTreeTimer = particles.get_tree().create_timer(particles.lifetime + 0.5, false)
	cleanup.timeout.connect(particles.queue_free)


## A see-through copy of a mesh that fades out (speed trail / "afterimage").
static func afterimage(parent: Node, mesh: Mesh, xform: Transform3D, color: Color,
		duration: float = 0.25) -> void:
	var ghost: MeshInstance3D = MeshInstance3D.new()
	ghost.mesh = mesh
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	ghost.material_override = material

	parent.add_child(ghost)
	ghost.global_transform = xform
	var tween: Tween = ghost.create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.tween_callback(ghost.queue_free)


## The glowing slice left behind by a Momentum Cut, from start_point to end_point.
static func cut_line(parent: Node, start_point: Vector3, end_point: Vector3, color: Color) -> void:
	var length: float = start_point.distance_to(end_point)
	if length < 0.1:
		return
	var line: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.18, 0.18, length)
	var material: StandardMaterial3D = _glow_material(color, 6.0)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	box.material = material
	line.mesh = box
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	parent.add_child(line)
	# Place the box halfway along the line and point it at the end.
	line.look_at_from_position((start_point + end_point) * 0.5, end_point, Vector3.UP)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "scale", Vector3(5.0, 0.3, 1.0), 0.06)  # flash wide
	tween.tween_property(line, "scale", Vector3(0.01, 0.01, 1.0), 0.45)
	tween.parallel().tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.tween_callback(line.queue_free)


## A material that glows (works with the "glow" setting in the WorldEnvironment).
static func _glow_material(color: Color, glow: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = glow
	return material
