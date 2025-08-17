# res://scenes/ui/reward_machine_menu.gd
extends PanelContainer

# --- Références UI existantes / posées dans l'éditeur ---
@onready var title_label: Label = $VBoxContainer/TitleLabel
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar
@onready var rewards_title: Label = $VBoxContainer/RewardsTitle
@onready var requirements_container: GridContainer = $VBoxContainer/ScrollContainer/Content/RequirementsContainer
@onready var rewards_container: VBoxContainer   = $VBoxContainer/ScrollContainer/Content/RewardsContainer
@onready var close_button: Button               = $VBoxContainer/CloseButton


const REQ_COLUMNS := 4
const REQ_SLOT_SIZE := Vector2i(48, 48)       # slots "Objectifs"
const REWARD_SLOT_SIZE := Vector2i(40, 40)    # icônes "Récompenses"
const GRID_HSEP := 8
const GRID_VSEP := 8



# Slots réutilisés pour afficher icônes + quantités
var inventory_slot_scene := preload("res://scenes/ui/inventoryslot.tscn")

var machine: RewardMachineComponent


@export var req_columns: int = 5   # colonnes dans la grille
@export var slot_px: int = 48      # taille carrée d’un slot
@export var give_pulse_scale: float = 1.12

func _style_slot(node: Control) -> void:
	node.custom_minimum_size = Vector2(slot_px, slot_px)
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	node.size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _pulse(node: CanvasItem) -> void:
	var s0: Vector2 = node.scale
	var tw = node.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", s0 * give_pulse_scale, 0.08)
	tw.set_ease(Tween.EASE_IN)
	tw.tween_property(node, "scale", s0, 0.10)


func _on_req_slot_clicked(event: InputEvent, slot: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		_pulse(slot)  # feedback visuel
		if slot.item_data:
			machine.add_item(slot.item_data, 1)


func _ready() -> void:
	GameManager.register_reward_machine_menu(self)
	close_button.pressed.connect(close_menu)
	# Grille propre
	requirements_container.columns = req_columns
	requirements_container.add_theme_constant_override("h_separation", 8)
	requirements_container.add_theme_constant_override("v_separation", 8)
	hide()




func open_menu(machine_component: RewardMachineComponent) -> void:
	machine = machine_component
	if not machine.progress_updated.is_connected(update_display):
		machine.progress_updated.connect(update_display)
	update_display()
	show()

func update_display(_progress_data: Variant = null, _requirements_data: Variant = null) -> void:
	if not is_instance_valid(machine):
		return

	_clear_container(requirements_container)
	_clear_container(rewards_container)

	# Si tout est terminé
	if machine.current_tier_index >= machine.reward_tiers.size():
		title_label.text = "Tous les objectifs sont atteints !"
		rewards_title.text = "🎉 Plus de récompenses restantes"
		progress_bar.visible = false
		return

	var tier := machine.reward_tiers[machine.current_tier_index]
	#objectifs
	title_label.text = "Objectifs actuels :"
	var reqs: Array = tier.fuel_required

	var total_required := 0
	var total_submitted := 0

	for ing in reqs:
		total_required += int(ing.quantity)
		var submitted := _submitted_amount_for(ing.item)
		var possessed := InventoryManager.get_item_count(ing.item)

		# --- Cellule = [CenterContainer(slot)] + [Label sous la case] ---
		var cell := VBoxContainer.new()
		cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		var center := CenterContainer.new()
		center.custom_minimum_size = Vector2(slot_px, slot_px)
		cell.add_child(center)

		var slot := inventory_slot_scene.instantiate()
		center.add_child(slot)
		_style_slot(slot)

		# Icône seule dans la case (on met l’overlay "soumis/requis")
		slot.display_item(ing.item, 0)
		slot.label.visible = true
		slot.label.text = "%d/%d" % [submitted, ing.quantity]
		slot.label.add_theme_color_override("font_color",
			(Color(1, 0.3, 0.3) if submitted < ing.quantity else Color(1,1,1)))

		# Clic: pulse + donation de 1 item
		slot.gui_input.connect(_on_req_slot_clicked.bind(slot))

		# Texte "vous avez" sous la case
		var below := Label.new()
		below.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		below.add_theme_font_size_override("font_size", 11)
		below.text = "(vous avez %d)" % possessed
		cell.add_child(below)

		requirements_container.add_child(cell)

		total_submitted += int(min(submitted, ing.quantity))


	# Barre de progression globale (somme des requis vs soumis)
	progress_bar.visible = true
	progress_bar.min_value = 0
	progress_bar.max_value = max(total_required, 1)
	progress_bar.value = clamp(total_submitted, 0, progress_bar.max_value)

	# --------- RÉCOMPENSES ----------
	rewards_title.text = "Voici ce que je peux faire :"
	var has_any_reward := false

	if tier.reward_items.size() > 0:
		has_any_reward = true
		_add_section_label(rewards_container, "Objets obtenus")

		var items_grid := GridContainer.new()
		items_grid.columns = 6
		items_grid.add_theme_constant_override("h_separation", GRID_HSEP)
		items_grid.add_theme_constant_override("v_separation", GRID_VSEP)
		items_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rewards_container.add_child(items_grid)

		for ri in tier.reward_items:
			var s := inventory_slot_scene.instantiate()
			items_grid.add_child(s)
			s.mouse_filter = Control.MOUSE_FILTER_IGNORE
			s.custom_minimum_size = REWARD_SLOT_SIZE
			s.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			if s.has_method("set"):
				s.set("slot_size", REWARD_SLOT_SIZE)
			s.display_item(ri.item, ri.quantity)

	# Recettes de craft
	if tier.reward_crafting_recipes.size() > 0:
		has_any_reward = true
		_add_section_label(rewards_container, "Recettes de craft débloquées")
		for recipe in tier.reward_crafting_recipes:
			rewards_container.add_child(_make_crafting_recipe_row(recipe))

	# Recettes de machine
	if tier.reward_machine_recipes.size() > 0:
		has_any_reward = true
		_add_section_label(rewards_container, "Recettes de machine débloquées")
		for mrecipe in tier.reward_machine_recipes:
			rewards_container.add_child(_make_machine_recipe_row(mrecipe))

	if not has_any_reward:
		var none := Label.new()
		none.text = "Aucune récompense définie pour ce palier."
		rewards_container.add_child(none)

# --- Clic sur un ingrédient requis pour en donner 1 ---
func _on_slot_clicked(event: InputEvent, slot: Panel) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		if slot.item_data:
			machine.add_item(slot.item_data, 1)

# ===== Helpers UI =====
func _clear_container(c: Node) -> void:
	for ch in c.get_children():
		ch.queue_free()

func _add_section_label(parent: Node, text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8))
	l.add_theme_font_size_override("font_size", 14)
	parent.add_child(l)

func _make_crafting_recipe_row(recipe) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon := inventory_slot_scene.instantiate()
	icon.custom_minimum_size = REWARD_SLOT_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.display_recipe(recipe)

	var txt := Label.new()
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rid_val = recipe.get("recipe_id")
	var rid := (str(rid_val) if rid_val != null else str(recipe.resource_name))
	txt.text = "Recette: %s — %s → %s" % [
		rid,
		_ingredients_to_text(recipe.inputs),
		_ingredients_to_text(recipe.outputs)
	]
	row.add_child(txt)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(row)
	return pad


func _make_machine_recipe_row(mrecipe) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var icon := inventory_slot_scene.instantiate()
	icon.custom_minimum_size = REWARD_SLOT_SIZE
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if mrecipe.outputs.size() > 0:
		icon.display_item(mrecipe.outputs[0].item, mrecipe.outputs[0].quantity)

	var txt := Label.new()
	txt.autowrap_mode = TextServer.AUTOWRAP_WORD
	txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var mid_val = mrecipe.get("recipe_id")
	var mid := (str(mid_val) if mid_val != null else str(mrecipe.resource_name))
	txt.text = "Machine: %s — %s → %s" % [
		mid,
		_ingredients_to_text(mrecipe.inputs),
		_ingredients_to_text(mrecipe.outputs)
	]
	row.add_child(txt)

	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 8)
	pad.add_theme_constant_override("margin_right", 8)
	pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pad.add_child(row)
	return pad


func _ingredients_to_text(list: Array) -> String:
	var parts: Array[String] = []
	for ing in list:
		var n1 = ing.item.get("item_name")
		var n2 = ing.item.get("display_name")
		var name := (str(n1) if n1 != null else (str(n2) if n2 != null else str(ing.item.resource_name)))
		parts.append("%dx %s" % [ing.quantity, name])
	return " + ".join(parts)

# Progress “safe” (resource_path pour éviter les problèmes d’égalité de Resource)
func _submitted_amount_for(it) -> int:
	var total := 0
	for k in machine.progress_per_item.keys():
		if k.resource_path == it.resource_path:
			total += int(machine.progress_per_item[k])
	return total

func close_menu() -> void:
	if is_instance_valid(machine) and machine.progress_updated.is_connected(update_display):
		machine.progress_updated.disconnect(update_display)
	hide()
