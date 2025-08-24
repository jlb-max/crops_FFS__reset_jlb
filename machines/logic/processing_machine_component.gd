# processing_machine_component.gd
class_name ProcessingMachineComponent
extends Node

signal state_changed(new_state)
signal progress_updated(progress_percentage)
signal queue_changed(length)

enum State { IDLE, PROCESSING, FINISHED }

@export var accepted_recipes: Array[MachineRecipe]
@export var machine_type: StringName
@export var max_queue_size := 10

var current_state: State = State.IDLE

# Chaque entrée du buffer est un "lot" = Array d'objets de sortie (recipe.outputs)
var output_buffer: Array = []                # Array[Array[ItemStack]]
var current_recipe_processing: MachineRecipe = null
var job_queue: Array[MachineRecipe] = []     # file d’attente

@onready var timer: Timer = Timer.new()

func _ready():
	add_child(timer)
	timer.one_shot = true
	timer.timeout.connect(_on_processing_finished)
	set_state(State.IDLE)
	set_process(false)

func _process(_delta: float):
	if current_state == State.PROCESSING and timer.wait_time > 0.0:
		var p := (1.0 - (timer.time_left / timer.wait_time)) * 100.0
		progress_updated.emit(p)

# --- API publique ---

# Clique sur "Créer" -> on consomme + on démarre ou on met en file
func queue_or_start(recipe: MachineRecipe) -> bool:
	if not _has_ingredients_available(recipe):
		return false

	_consume_ingredients(recipe)

	if current_state == State.IDLE and job_queue.is_empty():
		_start_job(recipe)
	else:
		if job_queue.size() >= max_queue_size:
			return false
		job_queue.append(recipe)
		queue_changed.emit(job_queue.size())
	return true

# Ramasse UN lot (le premier) ; renvoie true si quelque chose a été pris
func collect_output() -> bool:
	if output_buffer.is_empty():
		return false

	var bundle: Array = output_buffer.pop_front()
	for item_out in bundle:
		InventoryManager.add_item(item_out.item, item_out.quantity)
		print("Récupéré %d x %s" % [item_out.quantity, item_out.item.item_name])

	# S'il ne reste rien à traiter et plus rien à récupérer -> IDLE
	if job_queue.is_empty() and current_state != State.PROCESSING and output_buffer.is_empty():
		set_state(State.IDLE)
	else:
		# S'il reste encore des bundles, on reste en FINISHED (indicateur actif)
		if current_state != State.PROCESSING and not output_buffer.is_empty():
			set_state(State.FINISHED)
	return true

func clear_queue():
	job_queue.clear()
	queue_changed.emit(0)

func get_queue_length() -> int:
	return job_queue.size()

func set_state(new_state: State) -> void:
	current_state = new_state
	state_changed.emit(current_state)

# --- Internes ---

func _start_job(recipe: MachineRecipe) -> void:
	current_recipe_processing = recipe
	timer.start(recipe.processing_time_seconds)
	set_state(State.PROCESSING)
	set_process(true)

func _on_processing_finished():
	# Empile la sortie du job fini
	if current_recipe_processing:
		# On duplique pour éviter toute référence partagée
		output_buffer.append(current_recipe_processing.outputs.duplicate(true))
	current_recipe_processing = null

	if job_queue.is_empty():
		set_process(false)
		set_state(State.FINISHED if not output_buffer.is_empty() else State.IDLE)
	else:
		var next_recipe: MachineRecipe = job_queue.pop_front()
		queue_changed.emit(job_queue.size())
		_start_job(next_recipe)

func _has_ingredients_available(recipe: MachineRecipe) -> bool:
	for ingredient in recipe.inputs:
		if InventoryManager.get_item_count(ingredient.item) < ingredient.quantity:
			return false
	return true

func _consume_ingredients(recipe: MachineRecipe) -> void:
	for ingredient in recipe.inputs:
		InventoryManager.remove_item(ingredient.item, ingredient.quantity)


func get_queue_snapshot() -> Array:
	# Copie défensive
	return job_queue.duplicate(true)

func get_queue_count_for(recipe: MachineRecipe) -> int:
	var n := 0
	for r in job_queue:
		if r == recipe:
			n += 1
	return n
