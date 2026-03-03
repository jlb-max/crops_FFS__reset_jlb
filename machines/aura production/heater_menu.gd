# HeaterMenu.gd
extends PanelContainer

# --- Référence machine + composant ---
var heater_machine_ref: Node = null
var pmc_ref: ProcessingMachineComponent = null

# --- Références UI (identiques à ta scène) ---
@onready var row_template: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var recipes_box: VBoxContainer  = $VBoxContainer/RecipesContainer
@onready var cancel_button: Button       = $VBoxContainer/CancelButton
@onready var title_label: Label          = $VBoxContainer/Label

func _ready() -> void:
	row_template.visible = false
	GameManager.register_heater_fuel_menu(self)
	cancel_button.pressed.connect(close_menu)
	hide()

# Appelé par GameManager / interactable
func open_menu(machine_node: Node) -> void:
	heater_machine_ref = machine_node
	pmc_ref = heater_machine_ref.get_node_or_null("ProcessingMachineComponent") as ProcessingMachineComponent
	if pmc_ref == null:
		push_warning("HeaterMenu: ProcessingMachineComponent introuvable.")
		return

	# Récupérer tout ce qui traîne déjà (bundles prêts) avant d’ouvrir
	if not pmc_ref.output_buffer.is_empty():
		if pmc_ref.has_method("collect_all_outputs"):
			pmc_ref.collect_all_outputs()
		else:
			while pmc_ref.collect_output():
				pass

	# écouter les changements (progression/file)
	if not pmc_ref.state_changed.is_connected(_on_machine_state_changed):
		pmc_ref.state_changed.connect(_on_machine_state_changed)
	if not pmc_ref.queue_changed.is_connected(_on_machine_queue_changed):
		pmc_ref.queue_changed.connect(_on_machine_queue_changed)

	_rebuild_recipes_ui()
	show()

func close_menu() -> void:
	hide()
	_clear_recipes_ui()
	if pmc_ref:
		if pmc_ref.state_changed.is_connected(_on_machine_state_changed):
			pmc_ref.state_changed.disconnect(_on_machine_state_changed)
		if pmc_ref.queue_changed.is_connected(_on_machine_queue_changed):
			pmc_ref.queue_changed.disconnect(_on_machine_queue_changed)
	pmc_ref = null
	heater_machine_ref = null

func _on_machine_state_changed(_st: int) -> void:
	_rebuild_recipes_ui()

func _on_machine_queue_changed(_len: int) -> void:
	_rebuild_recipes_ui()

# -------------------------------------------------------------------
# Construction dynamique des lignes
# -------------------------------------------------------------------
func _clear_recipes_ui() -> void:
	for c in recipes_box.get_children():
		c.queue_free()

func _rebuild_recipes_ui() -> void:
	_clear_recipes_ui()
	title_label.text = "Alimenter le chauffage"
	if pmc_ref == null:
		return

	if pmc_ref.accepted_recipes.is_empty():
		var empty_label := Label.new()
		empty_label.text = "Aucune recette disponible."
		recipes_box.add_child(empty_label)
		return

	for recipe in pmc_ref.accepted_recipes:
		_add_recipe_row(recipe)

func _add_recipe_row(recipe: MachineRecipe) -> void:
	var row := row_template.duplicate() as HBoxContainer
	row.visible = true
	recipes_box.add_child(row)

	var tex := row.get_node("TextureRect") as TextureRect
	var count_lbl := row.get_node("CountLabel") as Label
	var feed_btn := row.get_node("FeedButton") as Button

	# Icône = 1er ingrédient si dispo
	if recipe.inputs.size() > 0 and recipe.inputs[0].item and recipe.inputs[0].item.icon:
		tex.texture = recipe.inputs[0].item.icon
	else:
		tex.texture = null

	# Remplissage initial
	_refresh_row(recipe, count_lbl, feed_btn)

	feed_btn.text = "Utiliser"
	feed_btn.pressed.connect(func():
		if not pmc_ref: return
		# File d'attente (consomme à la commande)
		var ok := pmc_ref.queue_or_start(recipe)
		if ok:
			# on reste ouvert pour pouvoir cliquer plusieurs fois
			_refresh_row(recipe, count_lbl, feed_btn)
		else:
			# pas de ressources ou file pleine
			_refresh_row(recipe, count_lbl, feed_btn)
	)
	

func _refresh_row(recipe: MachineRecipe, count_lbl: Label, feed_btn: Button) -> void:
	var possible := _compute_possible_crafts(recipe)
	count_lbl.text = _recipe_requirement_text(recipe) + "  —  Vous pouvez : %dx" % possible

	# bouton actif si ressources dispo ET file non pleine
	var queue_full := (pmc_ref and pmc_ref.get_queue_length() >= pmc_ref.max_queue_size)
	feed_btn.disabled = (possible == 0) or queue_full

# Combien de fois craftable avec l'inventaire
func _compute_possible_crafts(recipe: MachineRecipe) -> int:
	var min_times := 1_000_000
	if recipe.inputs.is_empty():
		return 0
	for ing in recipe.inputs:
		var have := InventoryManager.get_item_count(ing.item)
		if ing.quantity <= 0:
			return 0
		var times := int(floor(have / float(ing.quantity)))
		min_times = min(min_times, times)
	return max(min_times, 0)

# Ligne lisible des besoins
func _recipe_requirement_text(recipe: MachineRecipe) -> String:
	var parts: Array[String] = []
	for ing in recipe.inputs:
		var have := InventoryManager.get_item_count(ing.item)
		parts.append("%s x%d (vous: %d)" % [ing.item.item_name, ing.quantity, have])
	return " + ".join(parts)
