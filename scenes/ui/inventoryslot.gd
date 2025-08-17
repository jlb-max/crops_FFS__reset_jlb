# res://scenes/ui/InventorySlot.gd
extends Panel

enum SlotType { INVENTORY, MACHINE_INPUT }
@export var slot_type: SlotType = SlotType.INVENTORY
@export var slot_size: Vector2i = Vector2i(48, 48)  # overridable par l’éditeur


# --- NŒUDS ---
@onready var texture_rect: TextureRect = $TextureRect
@onready var label: Label             = $Label

# --- ÉTAT ---
var item_data: ItemData
var quantity: int
var slot_index: int = -1
var current_recipe: CraftingRecipe = null

# --- SIGNAUX ---
signal recipe_selected(recipe)

func _ensure_refs() -> void:
	if texture_rect == null:
		texture_rect = get_node_or_null("TextureRect") as TextureRect
	if label == null:
		label = get_node_or_null("Label") as Label

func _ready() -> void:
	# Taille mini fixe du slot
	custom_minimum_size = slot_size
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Sécurise l’icône pour ne pas s’étirer
	if texture_rect:
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.custom_minimum_size = slot_size
		texture_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		texture_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER

# =========================================================
# Helpers tooltip (nouveau)
# =========================================================
func _item_display_name(it: ItemData) -> String:
	if it == null:
		return ""
	if "item_name" in it:
		return str(it.item_name)
	if "display_name" in it:
		return str(it.display_name)
	return str(it.resource_name)

func _apply_tooltip(text: String) -> void:
	# On met le même tooltip sur tous les contrôles
	tooltip_text = text
	if texture_rect: texture_rect.tooltip_text = text
	if label:        label.tooltip_text = text

func _set_tooltip_from_item(it: ItemData, qty: int) -> void:
	var tip := _item_display_name(it)
	# Si tu veux afficher la quantité dans le tooltip, décommente la ligne suivante
	# if qty > 1: tip += " ×%d" % qty
	_apply_tooltip(tip)

# =========================================================
# API d’affichage (existante + tooltips)
# =========================================================
func display_item(p_item_data: ItemData, p_quantity: int) -> void:
	_ensure_refs()
	current_recipe = null
	item_data = p_item_data
	quantity = p_quantity

	if texture_rect:
		texture_rect.texture = item_data.icon
		texture_rect.visible = true

	if label:
		label.text = str(quantity) if quantity > 1 else ""
		label.visible = true

	if texture_rect:
		texture_rect.modulate = Color.WHITE

	_set_tooltip_from_item(item_data, quantity)
	_apply_tooltip(_item_display_name(item_data))

func display_empty() -> void:
	_ensure_refs()
	item_data = null
	current_recipe = null
	quantity = 0

	if texture_rect:
		texture_rect.texture = null
		texture_rect.visible = false

	if label:
		label.text = ""
		label.visible = false

	_apply_tooltip("")

func display_recipe(recipe: CraftingRecipe) -> void:
	_ensure_refs()
	display_empty()
	current_recipe = recipe

	if recipe and not recipe.outputs.is_empty():
		var display_item_data: ItemData = recipe.outputs[0].item
		_set_tooltip_from_item(display_item_data, 1)
		_apply_tooltip(_item_display_name(display_item_data))

		if texture_rect:
			texture_rect.texture = display_item_data.icon
			texture_rect.visible = true

	if texture_rect:
		if CraftingManager.can_craft(recipe):
			texture_rect.modulate = Color.WHITE
		else:
			texture_rect.modulate = Color(0.7, 0.7, 0.7, 0.8)

func display_ingredient_info(p_item_data: ItemData, p_quantity_required: int):
	_ensure_refs()
	item_data = p_item_data
	quantity = p_quantity_required

	if texture_rect:
		texture_rect.texture = p_item_data.icon
		texture_rect.visible = true

	var possessed_quantity = InventoryManager.get_item_count(p_item_data)
	if label:
		label.text = "%d/%d" % [possessed_quantity, p_quantity_required]
		label.visible = true
		label.add_theme_color_override(
			"font_color",
			Color.RED if possessed_quantity < p_quantity_required else Color.WHITE
		)

	_set_tooltip_from_item(p_item_data, 0)
	_apply_tooltip(_item_display_name(p_item_data))

# =========================================================
# Interaction (inchangée)
# =========================================================
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton \
	and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if current_recipe != null:
			recipe_selected.emit(current_recipe)

func _get_drag_data(at_position: Vector2) -> Variant:
	if item_data:
		var preview := TextureRect.new()
		preview.texture = texture_rect.texture
		preview.size = Vector2(32, 32)
		set_drag_preview(preview)
		return {"item": item_data, "from_slot": slot_index, "source": "inventory"}
	return null

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("item")

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if slot_type == SlotType.INVENTORY:
		InventoryManager.merge_or_swap_slots(data.source, data.from_slot, "inventory", self.slot_index)
	elif slot_type == SlotType.MACHINE_INPUT:
		var item_to_drop: ItemData = data.get("item")
		if item_to_drop:
			display_item(item_to_drop, 1)

func _make_custom_tooltip(for_text: String) -> Control:
	var panel := PanelContainer.new()

	# Style de fond
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.9)
	sb.border_color = Color(1, 1, 1, 0.08)
	sb.set_border_width_all(1)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", sb)

	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(240, 0)
	panel.add_child(root)

	# Ligne icône + titre
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	root.add_child(top)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(32, 32)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# icône prioritaire: item affiché; sinon icône actuelle du slot
	if item_data and "icon" in item_data:
		icon_rect.texture = item_data.icon
	elif texture_rect and texture_rect.texture:
		icon_rect.texture = texture_rect.texture
	top.add_child(icon_rect)

	var title := Label.new()
	title.text = for_text
	title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	title.add_theme_font_size_override("font_size", 16)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	# Description (si le type d'item en possède une)
	var desc_text := ""
	if item_data and "description" in item_data and typeof(item_data.description) == TYPE_STRING:
		desc_text = item_data.description
	elif current_recipe and not current_recipe.outputs.is_empty():
		var out_item: ItemData = current_recipe.outputs[0].item
		if out_item and "description" in out_item and typeof(out_item.description) == TYPE_STRING:
			desc_text = out_item.description

	if desc_text != "":
		var desc := Label.new()
		desc.text = desc_text
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc.add_theme_color_override("font_color", Color(0.9, 0.9, 0.95))
		root.add_child(desc)

	# Ligne quantité (seulement pour les items d’inventaire)
	if item_data and quantity > 1:
		var qty := Label.new()
		qty.text = "Quantité : %d" % quantity
		qty.add_theme_color_override("font_color", Color(0.8, 0.85, 1.0))
		root.add_child(qty)

	return panel
