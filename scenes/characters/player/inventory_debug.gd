extends Node
class_name InventoryDebug

## Active/désactive le composant
@export var enabled: bool = true
## Donne les items automatiquement à l'entrée en scène
@export var auto_give_on_ready: bool = true
## Si inventaire_magique est coché, on ne donne rien (pour éviter le double cheat)
@export var inventaire_magique: bool = false

## Raccourci clavier pour re-donner les items (ajoute l'action dans InputMap)
@export var input_action_give: StringName = &"debug_give_items"

# Chemins des items (adapte si besoin)
const CORN_SEED_PATH   := "res://scenes/objects/plants/corn_seed.tres"
const TOMATO_SEED_PATH := "res://scenes/objects/plants/tomato_seed.tres"
const STONE_PATH       := "res://scenes/objects/rocks/stone.tres"
const SMALL_LOG_PATH   := "res://scenes/objects/trees/small_log.tres"

# Quantités (modifiable dans le code ou via exports si tu préfères)
@export var corn_seed_qty: int = 10
@export var tomato_seed_qty: int = 10
@export var stone_qty: int = 30
@export var small_log_qty: int = 30

func _ready() -> void:
	if not enabled:
		return
	# Attends une frame pour être sûr que l'UI/InventoryManager sont prêts
	if auto_give_on_ready:
		await get_tree().process_frame
		give_test_items()

func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if input_action_give != StringName() and event.is_action_pressed(input_action_give):
		give_test_items()

func give_test_items() -> void:
	if inventaire_magique:
		print("InventoryDebug: inventaire_magique actif → on ne donne rien.")
		return

	print("InventoryDebug: donne les items de test au joueur.")

	_give(CORN_SEED_PATH,   corn_seed_qty)
	_give(TOMATO_SEED_PATH, tomato_seed_qty)
	_give(STONE_PATH,       stone_qty)
	_give(SMALL_LOG_PATH,   small_log_qty)

func _give(res_path: String, qty: int) -> void:
	var item := load(res_path)
	if item == null:
		push_error("InventoryDebug: res introuvable: " + res_path)
		return
	if qty <= 0:
		return
	InventoryManager.add_item(item, qty)
