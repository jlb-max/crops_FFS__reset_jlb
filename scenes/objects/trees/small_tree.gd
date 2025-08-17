extends AnimatedSprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent
@export var log_item_to_drop: ItemData
var log_scene = preload("res://scenes/objects/trees/log.tscn")

# --- CONFIG DROP MULTIPLE + ANIM ---
@export var min_logs_to_drop: int = 4
@export var max_logs_to_drop: int = 6
@export var drop_spread_radius: float = 40.0      # éparpillement
@export var drop_min_separation: float = 12.0     # évite la superposition
@export var drop_spawn_delay: float = 0.03        # 0 = tout d’un coup

@export var drop_fall_height: float = 48.0        # hauteur de chute
@export var drop_fall_time: float = 0.18          # durée chute
@export var drop_bounce: float = 6.0              # petit rebond
@export var add_with_deferred: bool = true        # safe si SceneTree “locked”

func _ready() -> void:
	randomize()
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damaged_reached.connect(on_max_damage_reached)

func on_hurt(item_used: ItemData) -> void:
	damage_component.apply_damage(item_used.damage)
	if material:
		material.set_shader_parameter("shake_intensity", 0.5)
		await get_tree().create_timer(0.15).timeout
		material.set_shader_parameter("shake_intensity", 0.0)

func on_max_damage_reached() -> void:
	# IMPORTANT: plus d'appel à add_log_scene()
	await spawn_drops()             # on attend la fin des spawns/animations
	print("max damaged reached")
	queue_free()

func spawn_drops() -> void:
	var parent := get_parent()
	var count := randi_range(min_logs_to_drop, max_logs_to_drop)
	print("Spawning logs:", count)
	var placed: Array[Vector2] = []

	for i in range(count):
		var offset := _pick_offset(placed)
		var target_pos := global_position + offset
		var start_pos := target_pos + Vector2(randf_range(-8.0, 8.0), -drop_fall_height)

		var log_instance = log_scene.instantiate()
		if add_with_deferred:
			parent.call_deferred("add_child", log_instance)
			await get_tree().process_frame   # s'assurer qu'il est ajouté
		else:
			parent.add_child(log_instance)

		# état initial
		log_instance.global_position = start_pos
		log_instance.rotation = randf_range(-0.25, 0.25)
		log_instance.scale = Vector2(0.0, 0.0)

		# optionnel: config collectable si présent
		var collectable = log_instance.get_node_or_null("CollectableComponent")
		if collectable and log_item_to_drop:
			collectable.item_data = log_item_to_drop

		# animations (chute + rebond + rotation + pop)
		var tw_pos = log_instance.create_tween().set_trans(Tween.TRANS_QUAD)
		tw_pos.set_ease(Tween.EASE_IN)
		tw_pos.tween_property(log_instance, "global_position", target_pos + Vector2(0, drop_bounce), drop_fall_time)
		tw_pos.set_ease(Tween.EASE_OUT)
		tw_pos.tween_property(log_instance, "global_position", target_pos, 0.08)

		var tw_rot = log_instance.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw_rot.tween_property(log_instance, "rotation", randf_range(-PI/6, PI/6), drop_fall_time + 0.08)

		var tw_scale = log_instance.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_scale.tween_property(log_instance, "scale", Vector2.ONE, 0.12)

		placed.append(target_pos)

		if drop_spawn_delay > 0.0 and i < count - 1:
			await get_tree().create_timer(drop_spawn_delay).timeout

func _pick_offset(placed: Array[Vector2]) -> Vector2:
	for _i in range(6):
		var ang := randf() * TAU
		var r := randf_range(0.0, drop_spread_radius)
		var cand := Vector2(cos(ang), sin(ang)) * r
		var world_cand := global_position + cand
		var ok := true
		for p in placed:
			if (p - world_cand).length() < drop_min_separation:
				ok = false
				break
		if ok:
			return cand
	return Vector2(randf_range(-drop_spread_radius, drop_spread_radius),
				   randf_range(-drop_spread_radius, drop_spread_radius))
