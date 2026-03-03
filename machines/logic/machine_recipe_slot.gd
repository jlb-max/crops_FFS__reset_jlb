extends HBoxContainer

signal recipe_selected(recipe)

@onready var input_items_container: HBoxContainer = $InputItemsContainer
@onready var output_items_container: HBoxContainer = $OutputItemsContainer


@onready var convert_button: Button = $ConvertButton
@onready var progress_bar: ProgressBar = $ProgressBar

var current_recipe: MachineRecipe
var machine_component_ref: ProcessingMachineComponent

func _ready():
	convert_button.pressed.connect(_on_convert_button_pressed)

# La fonction est maintenant plus complexe
func display_recipe(recipe: MachineRecipe, machine: ProcessingMachineComponent):
	current_recipe = recipe
	machine_component_ref = machine

	# Reset containers
	for child in input_items_container.get_children():
		child.queue_free()
	for child in output_items_container.get_children():
		child.queue_free()

	# Inputs
	for input_ingredient in recipe.inputs:
		var slot = preload("res://scenes/ui/inventoryslot.tscn").instantiate()
		input_items_container.add_child(slot)
		slot.display_item(input_ingredient.item, input_ingredient.quantity)

	# Outputs
	for output_ingredient in recipe.outputs:
		var slot = preload("res://scenes/ui/inventoryslot.tscn").instantiate()
		output_items_container.add_child(slot)
		slot.display_item(output_ingredient.item, output_ingredient.quantity)

	# --- État courant ---
	var is_current := (machine.current_state == ProcessingMachineComponent.State.PROCESSING
		and machine.current_recipe_processing == recipe)
	var queue_full := (machine.get_queue_length() >= machine.max_queue_size)

	if is_current:
		# Cette recette est en train d'être fabriquée -> barre visible
		convert_button.visible = false
		progress_bar.visible = true
		progress_bar.value = 0
		if not machine.progress_updated.is_connected(progress_bar.set_value):
			machine.progress_updated.connect(progress_bar.set_value)
	else:
		# Recette pas en cours -> bouton visible
		progress_bar.visible = false
		convert_button.visible = true

		# Vérifier les ressources ACTUELLES (elles sont débitées au clic)
		var can_process := true
		for ing in recipe.inputs:
			if InventoryManager.get_item_count(ing.item) < ing.quantity:
				can_process = false
				break

		# ⚠️ NE PLUS BLOQUER SUR L'ÉTAT DE LA MACHINE
		# Autoriser le clic même pendant PROCESSING, sauf si file pleine
		convert_button.disabled = (not can_process) or queue_full


func _on_convert_button_pressed():
	recipe_selected.emit(current_recipe)
