# PuzzleTriggerComponent.gd
class_name PuzzleTriggerComponent
extends Area2D

@export var required_plant: PlantData
@export var template_scene_to_apply: PackedScene
@export var target_game_tilemap: Node2D   # parent qui contient "Water" et "Grass"

# ---- POSITIONNEMENT ----
enum PositionMode { TEMPLATE_ABSOLUTE, RELATIVE_TO_TRIGGER_TOPLEFT, RELATIVE_TO_TRIGGER_CENTER }
@export var position_mode: PositionMode = PositionMode.TEMPLATE_ABSOLUTE
# (si RELATIVE_*) on peut facilement changer d’ancre si besoin

# ---- OPTIONS PEINTURE/FX ----
@export var include_neighbors_for_connect: bool = true
@export var erase_water_under_new_tiles: bool = true
@export var fx_scene: PackedScene        # ex: res://fx/TilePoof.tscn
@export var fx_wave_delay: float = 0.02
@export var fx_z_index: int = 30

var listening_to_plant: PlantedCrop = null

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

# --------------------------------------------------------------------------
# Détection d’entrée/sortie
# --------------------------------------------------------------------------
func _on_area_entered(area: Area2D) -> void:
	if area.owner is PlantedCrop and area.owner.plant_data == required_plant:
		listening_to_plant = area.owner as PlantedCrop
		listening_to_plant.growth_cycle_component.crop_harvesting.connect(on_puzzle_solved)

func _on_area_exited(area: Area2D) -> void:
	if area.owner == listening_to_plant:
		if is_instance_valid(listening_to_plant):
			var sig = listening_to_plant.growth_cycle_component.crop_harvesting
			if sig.is_connected(on_puzzle_solved):
				sig.disconnect(on_puzzle_solved)
		listening_to_plant = null

# --------------------------------------------------------------------------
# Application du template + FX
# --------------------------------------------------------------------------
func on_puzzle_solved() -> void:
	if not template_scene_to_apply or not target_game_tilemap:
		return

	var template := template_scene_to_apply.instantiate() as TileMapLayer
	var water_layer := target_game_tilemap.find_child("Water") as TileMapLayer
	var grass_layer := target_game_tilemap.find_child("Grass") as TileMapLayer
	if template == null or grass_layer == null:
		push_error("Template ou couche Grass introuvable.")
		if template: template.queue_free()
		return

	# IMPORTANT : même TileSet (mêmes TerrainSets) entre template et Grass
	if template.tile_set != grass_layer.tile_set:
		push_error("Le TileSet du template doit être le même que celui de Grass.")
		template.queue_free()
		return

	# 1) Récupère les cellules du template
	var tpl_cells: Array[Vector2i] = template.get_used_cells()
	if tpl_cells.is_empty():
		template.queue_free()
		return

	# 2) Détermine l’offset selon le mode (par défaut : 0 = coordonnées du template inchangées)
	var offset := Vector2i.ZERO
	if position_mode != PositionMode.TEMPLATE_ABSOLUTE:
		var target_cell := grass_layer.local_to_map(grass_layer.to_local(global_position))
		var tpl_rect := template.get_used_rect()
		var tpl_anchor := tpl_rect.position
		if position_mode == PositionMode.RELATIVE_TO_TRIGGER_CENTER:
			tpl_anchor = Vector2i(
				tpl_rect.position.x + int(floor((tpl_rect.size.x - 1) / 2.0)),
				tpl_rect.position.y + int(floor((tpl_rect.size.y - 1) / 2.0))
			)
		offset = target_cell - tpl_anchor

	# 3) Construit l’ensemble des cellules à peindre (avec voisines si demandé)
	var all_cells_dict := {}
	for c in tpl_cells:
		var dst := c + offset
		all_cells_dict[dst] = true
		if include_neighbors_for_connect:
			for n in grass_layer.get_surrounding_cells(dst):
				all_cells_dict[n] = true
	var all_cells: Array[Vector2i] = []
	for k in all_cells_dict.keys():
		all_cells.append(k)

	# 4) Groupe par (terrain_set, terrain) depuis le template (en appliquant l’offset)
	var by_terrain := {}  # key=Vector2i(terrain_set, terrain) -> Array[Vector2i]
	for c in tpl_cells:
		var td := template.get_cell_tile_data(c)
		if td == null:
			continue
		var key := Vector2i(td.terrain_set, td.terrain)
		if not by_terrain.has(key):
			by_terrain[key] = []
		var arr := by_terrain[key] as Array
		arr.append(c + offset)
		by_terrain[key] = arr

	# 5) Efface l'eau sous les nouvelles cellules (optionnel)
	if erase_water_under_new_tiles and water_layer:
		for cell in all_cells:
			water_layer.erase_cell(cell)

	# 6) Peint groupe par groupe avec autoconnect propre
	if include_neighbors_for_connect:
		for key_any in by_terrain.keys():
			var key: Vector2i = key_any
			var arr := by_terrain[key] as Array
			var expanded := {}
			for v in arr:
				var cell: Vector2i = v
				expanded[cell] = true
				for n in grass_layer.get_surrounding_cells(cell):
					expanded[n] = true
			var arr2 := []
			for k_any in expanded.keys():
				arr2.append(k_any)
			by_terrain[key] = arr2

	for key_any in by_terrain.keys():
		var key: Vector2i = key_any
		var cells := by_terrain[key] as Array
		grass_layer.set_cells_terrain_connect(cells, key.x, key.y, true)

	grass_layer.update_internals()

	# 7) FX d’apparition (optionnel)
	if fx_scene:
		await _play_reveal_fx(grass_layer, tpl_cells, offset)

	template.queue_free()
	queue_free()

# Effet visuel en vague (du centre du motif)
func _play_reveal_fx(grass_layer: TileMapLayer, template_cells: Array[Vector2i], offset: Vector2i) -> void:
	var sum := Vector2.ZERO
	for c in template_cells:
		sum += Vector2(c)
	var center := sum / float(max(1, template_cells.size()))

	var items := []
	for c in template_cells:
		var dst := c + offset
		var pos := grass_layer.to_global(grass_layer.map_to_local(dst))
		var d := pos.distance_to(
			grass_layer.to_global(
				grass_layer.map_to_local(Vector2i(center.floor().x, center.floor().y) + offset)
			)
		)
		items.append({ "pos": pos, "dist": d })

	items.sort_custom(func(a, b): return a["dist"] < b["dist"])

	for it in items:
		var fx := fx_scene.instantiate() as Node2D
		if fx:
			fx.position = it["pos"]
			fx.z_index = fx_z_index
			get_tree().current_scene.add_child(fx)
		if fx_wave_delay > 0.0:
			await get_tree().create_timer(fx_wave_delay).timeout
