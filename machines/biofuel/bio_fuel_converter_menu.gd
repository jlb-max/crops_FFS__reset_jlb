#biofuelconvertermenu.gd
extends PanelContainer

@onready var item_grid: GridContainer = $VBoxContainer/ScrollContainer/ItemGrid
@onready var close_button: Button = $VBoxContainer/CloseButton

# Barre de file (ajoutée dans la scène)
@onready var queue_bar: HBoxContainer = $VBoxContainer/QueueBar
@onready var queue_text: Label = $VBoxContainer/QueueBar/QueueText
@onready var queue_icons: HBoxContainer = $VBoxContainer/QueueBar/QueueIcons

# (optionnels si tu les ajoutes plus tard)
@onready var collect_all_btn: Button = get_node_or_null("VBoxContainer/CollectAllButton")
@onready var clear_queue_btn: Button = get_node_or_null("VBoxContainer/ClearQueueButton")

var slot_scene = preload("res://machines/logic/machine_recipe_slot.tscn")
var current_machine_component: ProcessingMachineComponent

func _ready() -> void:
    GameManager.register_biofuel_menu(self)
    close_button.pressed.connect(close_menu)
    if collect_all_btn:
        collect_all_btn.pressed.connect(_on_collect_all_pressed)
    if clear_queue_btn:
        clear_queue_btn.pressed.connect(_on_clear_queue_pressed)
    set_process_unhandled_input(true)
    hide()

# ----- ouverture / fermeture -----
func open_menu(machine_component: ProcessingMachineComponent) -> void:
    _disconnect_machine_signals()
    current_machine_component = machine_component
    _connect_machine_signals()
    show()
    redraw_recipes()
    _redraw_queue_bar()

func close_menu() -> void:
    _disconnect_machine_signals()
    hide()

func _unhandled_input(event: InputEvent) -> void:
    if not visible:
        return
    if event.is_action_pressed("ui_cancel"):
        close_menu()
        get_viewport().set_input_as_handled()

# ----- signaux machine -----
func _connect_machine_signals() -> void:
    if not current_machine_component:
        return
    if not current_machine_component.state_changed.is_connected(_on_machine_state_changed):
        current_machine_component.state_changed.connect(_on_machine_state_changed)
    if not current_machine_component.queue_changed.is_connected(_on_machine_queue_changed):
        current_machine_component.queue_changed.connect(_on_machine_queue_changed)

func _disconnect_machine_signals() -> void:
    if not current_machine_component:
        return
    if current_machine_component.state_changed.is_connected(_on_machine_state_changed):
        current_machine_component.state_changed.disconnect(_on_machine_state_changed)
    if current_machine_component.queue_changed.is_connected(_on_machine_queue_changed):
        current_machine_component.queue_changed.disconnect(_on_machine_queue_changed)
    current_machine_component = null

func _on_machine_state_changed(_new_state: int) -> void:
    # rafraîchit le slot "en cours" + la file visuelle
    redraw_recipes()
    _redraw_queue_bar()

func _on_machine_queue_changed(_len: int) -> void:
    # rafraîchit la file visuelle (icônes) + titres
    redraw_recipes()
    _redraw_queue_bar()

# ----- UI -----
func redraw_recipes() -> void:
    for child in item_grid.get_children():
        child.queue_free()
    if not current_machine_component:
        return

    var recipes := MachineRecipeManager.get_discovered_recipes_for_machine(
        current_machine_component.machine_type
    )

    for recipe in recipes:
        var slot = slot_scene.instantiate()
        item_grid.add_child(slot)

        # disponibilité des ingrédients à l'instant T
        var can_process := true
        for ingredient in recipe.inputs:
            if InventoryManager.get_item_count(ingredient.item) < ingredient.quantity:
                can_process = false
                break

        slot.display_recipe(recipe, current_machine_component)

        if can_process:
            slot.modulate = Color.WHITE
            if not slot.recipe_selected.is_connected(_on_recipe_clicked):
                slot.recipe_selected.connect(_on_recipe_clicked)
        else:
            slot.modulate = Color(0.5, 0.5, 0.5, 0.8)

    _update_queue_bar_buttons()

func _update_queue_bar_buttons() -> void:
    if not current_machine_component:
        return
    if collect_all_btn:
        collect_all_btn.disabled = current_machine_component.output_buffer.is_empty()
    if clear_queue_btn:
        clear_queue_btn.disabled = current_machine_component.get_queue_length() == 0

# --- dessin de la file (icônes) ---
func _redraw_queue_bar() -> void:
    if not current_machine_component:
        queue_bar.visible = false
        return

    # vide les anciennes icônes
    for c in queue_icons.get_children():
        c.queue_free()

    var q = current_machine_component.get_queue_snapshot()

    queue_text.text = "Queue: %d" % q.size()
    queue_bar.visible = q.size() > 0

    # On montre UNIQUEMENT les jobs EN ATTENTE (pas celui en cours)
    for recipe in q:
        var icon_tex: Texture2D = null
        # 1) si la recette a une icône propre
        if recipe.has_method("get_icon"):
            icon_tex = recipe.get_icon()
        elif "icon" in recipe:
            icon_tex = recipe.icon
        # 2) sinon on prend l'icône du 1er output
        if icon_tex == null and recipe.outputs.size() > 0:
            icon_tex = recipe.outputs[0].item.icon

        var tr := TextureRect.new()
        tr.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
        tr.custom_minimum_size = Vector2(28, 28)  # ✅ Godot 4.x
        tr.texture = icon_tex
        
        queue_icons.add_child(tr)


    _update_queue_bar_buttons()

# ----- actions -----
func _on_recipe_clicked(recipe: MachineRecipe) -> void:
    if not current_machine_component:
        return
    var ok := current_machine_component.queue_or_start(recipe)
    if ok:
        redraw_recipes()
    _redraw_queue_bar()

func _on_collect_all_pressed() -> void:
    if not current_machine_component:
        return
    var picked := false
    while current_machine_component.collect_output():
        picked = true
    if picked:
        _redraw_queue_bar()
        redraw_recipes()

func _on_clear_queue_pressed() -> void:
    if not current_machine_component:
        return
    current_machine_component.clear_queue()
    _redraw_queue_bar()
    redraw_recipes()
