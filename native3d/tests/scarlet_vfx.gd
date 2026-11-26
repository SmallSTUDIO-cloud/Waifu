extends SceneTree

# Scarlet Veil combat VFX QA:
#  - crimson_blade.glb loads, is a real mesh asset with scarlet emissive
#    materials, modest poly count, and is attached under the J_Bip_R_Hand grip
#  - blade extends along the grip's -Y (correct carry direction)
#  - combat effects use the crimson palette (red-dominant vertex colors)
#  - effect budget and automatic cleanup still hold
#  - REDUCED quality drops particles and petal layers
#  - sword trail ribbon is crimson
#  - skill (50 energy) and ultimate (100 energy) fire through the existing
#    attack pipeline, consume energy and spawn veil/bloom effects
#  - dodge spawns the directional bloodline streak

var failures: int = 0

func _initialize() -> void:
	call_deferred("run_test")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		printerr("FAIL scarlet: ", message)

func active_effects() -> Array:
	return get_nodes_in_group("combat_effects").filter(func(n): return not n.is_queued_for_deletion())

func _mesh_tris(node: Node) -> int:
	var total := 0
	if node is MeshInstance3D and node.mesh:
		for s in range(node.mesh.get_surface_count()):
			var arr = node.mesh.surface_get_arrays(s)
			if arr[Mesh.ARRAY_INDEX] != null:
				total += arr[Mesh.ARRAY_INDEX].size() / 3
			else:
				total += arr[Mesh.ARRAY_VERTEX].size() / 3
	for c in node.get_children():
		total += _mesh_tris(c)
	return total

func _has_emissive_red(node: Node) -> bool:
	if node is MeshInstance3D:
		var m = node.material_override
		if m == null and node.mesh:
			for s in range(node.mesh.get_surface_count()):
				m = node.mesh.surface_get_material(s)
				if m == null: continue
		if m is StandardMaterial3D and m.emission_enabled:
			if m.emission.r > 0.9 and m.emission.g < 0.45 and m.emission.b < 0.6:
				return true
	for c in node.get_children():
		if _has_emissive_red(c): return true
	return false

func run_test() -> void:
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var player = scene.player
	scene.playing = true
	player.enabled = true

	# --- sword asset ---
	var glb = load("res://assets/crimson_blade.glb")
	check(glb != null, "crimson_blade.glb missing")
	var inst = glb.instantiate()
	check(inst.name == "CrimsonBlade" or inst.get_child_count() > 0, "glb has no CrimsonBlade content")
	var tris = _mesh_tris(inst)
	print("SCARLET blade tris=", tris)
	check(tris > 100 and tris < 2000, "blade poly count out of range (%d)" % tris)
	check(_has_emissive_red(inst), "no scarlet emissive material in blade")
	inst.queue_free()
	var attached = player.sword_grip.get_node_or_null("CrimsonBlade") if player.sword_grip else null
	check(attached != null, "CrimsonBlade not attached to grip")
	check(player.aura_material != null and player.aura_material.emission.r > 0.9 and player.aura_material.emission.g < 0.45, "aura not scarlet")
	await process_frame
	if attached != null:
		# The GLB root sits at the grip origin; check the mesh AABB instead:
		# the blade must extend along local -Y (tip near y=-0.885).
		var aabb = attached.get_aabb()
		print("SCARLET blade aabb min=", aabb.position, " size=", aabb.size)
		check(aabb.position.y < -0.5, "blade does not extend along -Y (aabb min y=%.3f)" % aabb.position.y)

	# --- palette of spawned slash ---
	scene._swing_vfx(1)
	var fx = active_effects()
	check(fx.size() == 1, "expected 1 slash effect, got %d" % fx.size())
	if fx.size() == 1:
		var e = fx[0]
		check(e.kind == "slash", "wrong kind")
		var arr = e.shape.mesh.surface_get_arrays(0)
		var cols: PackedColorArray = arr[Mesh.ARRAY_COLOR]
		check(cols.size() > 0, "slash has no vertex colors")
		var red_ok := 0
		for c in cols:
			if c.r > c.g * 1.5 and c.r > 0.4:
				red_ok += 1
		check(red_ok > cols.size() / 2, "slash not crimson-dominant (%d/%d)" % [red_ok, cols.size()])
		check(e.get_child_count() >= 2, "FULL slash should have a particle burst child")

	# --- budget + cleanup ---
	for i in range(20):
		scene._swing_vfx(4)
	check(active_effects().size() <= 12, "effect budget exceeded: %d" % active_effects().size())
	for i in range(80):
		await process_frame
	check(active_effects().size() == 0, "effects not cleaned up after lifetime (%d left)" % active_effects().size())

	# --- REDUCED quality: no particles, fewer verts (compare slash to slash) ---
	scene.quality_settings.effects = 0
	scene._swing_vfx(2)
	var e0 = null
	for e in active_effects():
		if e.kind == "slash": e0 = e
	check(e0 != null, "no slash effect at REDUCED")
	if e0 != null:
		check(e0.effect_quality == 0, "effect quality not 0 at REDUCED")
		var kids := 0
		for c in e0.get_children():
			if c is CPUParticles3D: kids += 1
		check(kids == 0, "REDUCED effect should have no particles")
		var v0 = e0.shape.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
		for e in active_effects(): e.queue_free()
		await process_frame
		scene.quality_settings.effects = 1
		scene._swing_vfx(2)
		var e1 = null
		for e in active_effects():
			if e.kind == "slash": e1 = e
		check(e1 != null, "no slash effect at FULL")
		if e1 != null:
			var v1 = e1.shape.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()
			print("SCARLET slash verts reduced=", v0, " full=", v1)
			check(v1 > v0, "FULL should add petal geometry over REDUCED")
		for e in active_effects(): e.queue_free()
		await process_frame

	# --- trail ribbon is crimson ---
	for i in range(6):
		player.sword_trail.update_trail(1.0 / 60.0, player.sword_grip, true)
	var tarr = player.sword_trail.ribbon.surface_get_arrays(0)
	var tcols: PackedColorArray = tarr[Mesh.ARRAY_COLOR]
	check(tcols.size() > 0, "trail ribbon empty")
	var tred := 0
	for c in tcols:
		if c.r > c.g * 1.5: tred += 1
	check(tred > tcols.size() / 2, "trail not crimson (%d/%d)" % [tred, tcols.size()])
	player.sword_trail.clear_trail()

	# --- skill / ultimate ---
	player.energy = 100.0
	player.attack_timer = 0.0
	player.attack_cooldown = 0.0
	scene._skill()
	check(player.energy == 50.0, "skill did not consume 50 energy (%.1f)" % player.energy)
	check(player.attack_timer > 0.0, "skill did not start an attack")
	var kinds = {}
	for e in active_effects(): kinds[e.kind] = true
	check(kinds.has("veil"), "no veil effect spawned")
	player.attack_timer = 0.0
	player.attack_cooldown = 0.0
	player.energy = 100.0
	for e in active_effects(): e.queue_free()
	await process_frame
	scene._ultimate()
	check(player.energy == 0.0, "ultimate did not drain energy")
	kinds.clear()
	for e in active_effects(): kinds[e.kind] = true
	check(kinds.has("bloom"), "no bloom effect spawned")
	check(player.attack_timer > 0.0, "ultimate did not start the heavy attack")
	for e in active_effects(): e.queue_free()
	await process_frame
	# not enough energy -> nothing happens
	player.attack_timer = 0.0
	player.attack_cooldown = 0.0
	player.energy = 10.0
	var before = active_effects().size()
	scene._skill()
	check(active_effects().size() == before and player.attack_timer <= 0.0, "skill fired without energy")

	# --- dodge spawns directional streak ---
	player.dash_cooldown = 0.0
	scene._dodge()
	check(player.dash_time > 0.0, "dodge did not start")
	kinds.clear()
	for e in active_effects(): kinds[e.kind] = true
	check(kinds.has("dash"), "no bloodline dash streak")
	for e in active_effects(): e.queue_free()

	scene.queue_free()
	if failures == 0:
		print("PASS scarlet vfx: crimson blade GLB, attachment, palette, budget, cleanup, quality modes, trail, skill/ultimate/dash")
	quit(1 if failures else 0)
