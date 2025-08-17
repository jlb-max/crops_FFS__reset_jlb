extends Sprite2D

@onready var hurt_component: HurtComponent = $HurtComponent
@onready var damage_component: DamageComponent = $DamageComponent

# Item ramassable laissé par chaque caillou
@export var stone_item_to_drop: ItemData

# Scène de caillou (Sprite2D simple avec, si tu veux, un CollectableComponent)
var stone_scene := preload("res://scenes/objects/rocks/stone.tscn")

# ---- CONFIG DROP EXPLOSIF ----
@export var min_stones_to_drop: int = 4
@export var max_stones_to_drop: int = 7

# Physique "arc" (unité px et s)
@export var jet_gravity: float = 1200.0        # gravité (vers le bas)
@export var jet_vy_range: Vector2 = Vector2(220.0, 320.0)   # vitesse verticale initiale (magnitude); réel = -rand (vers le haut)
@export var jet_vh_range: Vector2 = Vector2(120.0, 220.0)   # vitesse horizontale (magnitude)

@export var drop_min_separation: float = 12.0  # éviter la superpo
@export var drop_spawn_delay: float = 0.0      # délai entre jets (0 = tous en même temps)
@export var spin_speed_range: Vector2 = Vector2(-6.0, 6.0)   # rad/s

@export var add_with_deferred: bool = true     # utile si SceneTree "locked"

func _ready() -> void:
	randomize()
	hurt_component.hurt.connect(on_hurt)
	damage_component.max_damaged_reached.connect(on_max_damage_reached)

func on_hurt(item_used: ItemData) -> void:
	damage_component.apply_damage(item_used.damage)
	if material:
		material.set_shader_parameter("shake_intensity", 0.35)
		await get_tree().create_timer(0.12).timeout
		material.set_shader_parameter("shake_intensity", 0.0)

func on_max_damage_reached() -> void:
	await spawn_explosive_drops()   # on attend la fin des jets
	queue_free()

func spawn_explosive_drops() -> void:
	var parent := get_parent()
	var count := randi_range(min_stones_to_drop, max_stones_to_drop)
	var placed: Array[Vector2] = []

	for i in range(count):
		# Tirage des vitesses (direction aléatoire dans le plan, vers le haut)
		var angle := randf() * TAU
		var vh_mag := randf_range(jet_vh_range.x, jet_vh_range.y)
		var v_h := Vector2(cos(angle), sin(angle)) * vh_mag
		var vy0 := -randf_range(jet_vy_range.x, jet_vy_range.y)   # négatif = vers le haut

		# Durée jusqu'au "sol" (retour à y=0)
		var t_hit := (-2.0 * vy0) / jet_gravity
		var final_offset := v_h * t_hit
		var target_pos := global_position + final_offset

		# Évite la superposition de landing spots (quelques essais)
		var tries := 0
		while tries < 6:
			var ok := true
			for p in placed:
				if (p - target_pos).length() < drop_min_separation:
					ok = false
					break
			if ok: break
			angle = randf() * TAU
			vh_mag = randf_range(jet_vh_range.x, jet_vh_range.y)
			v_h = Vector2(cos(angle), sin(angle)) * vh_mag
			final_offset = v_h * t_hit
			target_pos = global_position + final_offset
			tries += 1

		var stone := stone_scene.instantiate()
		if add_with_deferred:
			parent.call_deferred("add_child", stone)
			await get_tree().process_frame
		else:
			parent.add_child(stone)

		# Départ EXACT au centre du rocher (jet explosif)
		stone.global_position = global_position
		var base_rot := randf_range(-0.2, 0.2)
		stone.rotation = base_rot
		stone.scale = Vector2(0.0, 0.0)

		# Si Collectable présent, on assigne l'item
		var collectable = stone.get_node_or_null("CollectableComponent")
		if collectable and stone_item_to_drop:
			collectable.item_data = stone_item_to_drop

		# Mouvement balistique via tween_method
		var rot_speed := randf_range(spin_speed_range.x, spin_speed_range.y)
		var start_pos := global_position
		var cb := func(t):
			# x/y(t) = start + v_h*t + (0, vy0*t + 0.5*g*t^2)
			stone.global_position = start_pos + v_h * t + Vector2(0.0, vy0 * t + 0.5 * jet_gravity * t * t)
			stone.rotation = base_rot + rot_speed * t

		var tw = stone.create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
		tw.tween_method(cb, 0.0, t_hit, t_hit)
		# Petit rebond au sol
		var bounce := 6.0
		tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(stone, "global_position", target_pos - Vector2(0, bounce), 0.06)
		tw.set_ease(Tween.EASE_IN)
		tw.tween_property(stone, "global_position", target_pos, 0.08)

		# Pop de scale en parallèle
		var tw_scale = stone.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw_scale.tween_property(stone, "scale", Vector2.ONE, 0.12)

		placed.append(target_pos)

		if drop_spawn_delay > 0.0 and i < count - 1:
			await get_tree().create_timer(drop_spawn_delay).timeout
