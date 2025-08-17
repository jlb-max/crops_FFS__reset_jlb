#effects_overlay.gd
extends Node2D
class_name EffectsOverlay

# --- Limites de dessin de l'overlay ---
enum BoundsMode { FROM_EFFECTMAPS, UNION_OF_LAYERS, CAMERA_VIEW }
@export var bounds_mode: int = BoundsMode.UNION_OF_LAYERS

# Si UNION_OF_LAYERS : liste des TileMapLayer à fusionner (mets GameTileMap/Water, /Grass, /TilledSoil)
@export var bounds_layer_paths: Array[NodePath] = []

# Si CAMERA_VIEW : caméra à utiliser + marge (en cellules)
@export var camera2d_path: NodePath
@export var view_margin_cells: int = 2



@export var overlay_visible := false
@export var start_in_all_mode := true        # Ouvre en mode "toutes les cartes"
@export var alpha_max: float = 0.55
@export var threshold: float = 0.02
@export var z_index_overlay: int = 1000

# Fond sombre
@export var darken_background := true
@export var background_color := Color(0, 0, 0, 0.35)


enum Norm { RELATIVE, ABSOLUTE }

@export var normalize_mode: int = Norm.RELATIVE    # RELATIVE = auto par effet, ABSOLUTE = échelle fixe
@export var absolute_scale: Array[float] = [       # utilisé si ABSOLUTE
	20.0,  # OXYGEN  (ex: valeurs typiques max)
	1.0,   # LIGHT
	10.0,  # HEAT
	5.0    # GRAVITY
]


const COLORS: Array[Color] = [
	Color(0.2, 0.8, 1.0, 1.0),   # OXYGEN
	Color(1.0, 0.95, 0.2, 1.0),  # LIGHT
	Color(1.0, 0.25, 0.15, 1.0), # HEAT
	Color(0.7, 0.3, 1.0, 1.0),   # GRAVITY
]
const NAMES := ["Oxygène", "Lumière", "Chaleur", "Gravité"]

var _rects_by_effect: Array = []       # Array<Array[Rect2]>
var _colors_by_effect: Array = []      # Array<Array[Color]>
var _debug_once := false
var _show_all := true
var current_effect: int = EffectMaps.EffectType.OXYGEN

func _ready() -> void:
	add_to_group("effects_overlay")
	z_index = z_index_overlay     # ← au lieu du 10 en dur
	z_as_relative = true
	visible = overlay_visible
	EffectMaps.maps_rebuilt.connect(_on_maps_rebuilt)



func _alpha_for(et: int, v: float) -> float:
	var a: float = 0.0
	if normalize_mode == Norm.RELATIVE:
		var m: float = EffectMaps.get_max_value(et)
		if m <= 0.0001:
			return 0.0
		a = v / m
	else:
		var s: float = (absolute_scale[et] if et < absolute_scale.size() else 1.0)
		if s <= 0.0001:
			return 0.0
		a = v / s
	return clampf(a, 0.0, 1.0)

  
func is_showing_all() -> bool:
	return _show_all


func _on_maps_rebuilt(_types: Array) -> void:
	if overlay_visible:
		_rebuild_draw_cache()
		queue_redraw()




func set_overlay_visible(v: bool) -> void:
	overlay_visible = v
	visible = v
	if v:
		# Ouvre toujours en mode "toutes les couches"
		_show_all = true
		current_effect = EffectMaps.EffectType.OXYGEN
		EffectMaps.rebuild()
		_rebuild_draw_cache()
		queue_redraw()

# --- API pour la barre d’outils UI ---
func set_mode_all() -> void:
	_show_all = true
	if overlay_visible:
		_rebuild_draw_cache()
		queue_redraw()

func set_mode_single(effect: int) -> void:
	_show_all = false
	current_effect = effect
	if overlay_visible:
		_rebuild_draw_cache()
		queue_redraw()

func _cycle_effect(dir: int) -> void:
	var vals := EffectMaps.EFFECT_TYPES
	var idx := vals.find(current_effect)
	current_effect = vals[(idx + dir + vals.size()) % vals.size()]
	_rebuild_draw_cache()
	queue_redraw()

func _get_map_rect_local() -> Rect2:
	var cells_rect: Rect2i = _bounds_rect_cells()
	var ts: Vector2 = Vector2(EffectMaps.tile_size)

	var top_left_layer: Vector2 = EffectMaps.terrain_layer.map_to_local(cells_rect.position)
	var top_left: Vector2 = to_local(EffectMaps.terrain_layer.to_global(top_left_layer)) - ts * 0.5
	return Rect2(top_left, Vector2(cells_rect.size) * ts)


func _rebuild_draw_cache() -> void:
	_rects_by_effect.clear()
	_colors_by_effect.clear()
	if not EffectMaps.terrain_layer:
		return

	var effects := EffectMaps.EFFECT_TYPES if _show_all else [current_effect]

	for et in effects:
		var rects: Array[Rect2] = []
		var cols: Array[Color] = []
		_fill_cache_for_effect(int(et), rects, cols)
		_rects_by_effect.append(rects)
		_colors_by_effect.append(cols)

func _fill_cache_for_effect(et: int, out_rects: Array, out_cols: Array) -> void:
	var cells_rect: Rect2i = _bounds_rect_cells()
	var ts: Vector2 = Vector2(EffectMaps.tile_size)

	for y in range(cells_rect.position.y, cells_rect.end.y):
		for x in range(cells_rect.position.x, cells_rect.end.x):
			var cell := Vector2i(x, y)
			var v: float = EffectMaps.get_value(et, cell)  # doit tolérer OOB → 0.0
			var a_norm := _alpha_for(et, v)
			if a_norm <= threshold:
				continue

			var p_layer: Vector2 = EffectMaps.terrain_layer.map_to_local(cell)
			var pos: Vector2 = to_local(EffectMaps.terrain_layer.to_global(p_layer)) - ts * 0.5
			out_rects.append(Rect2(pos, ts))

			var col: Color = COLORS[et]
			col.a = a_norm * alpha_max
			out_cols.append(col)


func _draw() -> void:
	if not overlay_visible:
		return
	# 1) Fond sombre
	if darken_background:
		draw_rect(_get_map_rect_local(), background_color, true)
	# 2) Heatmaps
	for i in _rects_by_effect.size():
		var rects: Array = _rects_by_effect[i]
		var cols: Array = _colors_by_effect[i]
		for j in rects.size():
			draw_rect(rects[j], cols[j], true)

func _bounds_rect_cells() -> Rect2i:
	# 0) Sécurité : si pas de layer de référence, on tombe sur l'ancien comportement
	if not EffectMaps.terrain_layer:
		return EffectMaps.map_used_rect

	match bounds_mode:
		BoundsMode.FROM_EFFECTMAPS:
			return EffectMaps.map_used_rect

		BoundsMode.UNION_OF_LAYERS:
			var have_any := false
			var rect := Rect2i()
			for p in bounds_layer_paths:
				var l := get_node_or_null(p) as TileMapLayer
				if l:
					var r := l.get_used_rect()
					if not have_any:
						rect = r
						have_any = true
					else:
						rect = rect.merge(r)
			return rect if have_any else EffectMaps.map_used_rect


		BoundsMode.CAMERA_VIEW:
			var cam := get_node_or_null(camera2d_path) as Camera2D
			if not cam:
				return EffectMaps.map_used_rect

			# coins du viewport (en global), avec zoom
			var vp_size := get_viewport_rect().size
			var half := (vp_size * cam.zoom) * 0.5
			var tl := cam.global_position - half
			var br := cam.global_position + half

			# convertit en cellules via le layer de référence d’EffectMaps
			var L := EffectMaps.terrain_layer
			var tl_cell := L.local_to_map(L.to_local(tl))
			var br_cell := L.local_to_map(L.to_local(br))

			var min_x := mini(tl_cell.x, br_cell.x) - view_margin_cells
			var min_y := mini(tl_cell.y, br_cell.y) - view_margin_cells
			var max_x := maxi(tl_cell.x, br_cell.x) + view_margin_cells
			var max_y := maxi(tl_cell.y, br_cell.y) + view_margin_cells

			return Rect2i(Vector2i(min_x, min_y), Vector2i(max_x - min_x + 1, max_y - min_y + 1))

		_:
			return EffectMaps.map_used_rect
