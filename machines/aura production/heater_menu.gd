# HeaterMenu.gd  (remplace l'ancien HeaterFuelMenu.gd)
extends PanelContainer

# Référence à la machine ouverte
var heater_machine_ref: Node = null

# --- Références UI ---
@onready var row_template: HBoxContainer = $VBoxContainer/HBoxContainer
@onready var recipes_box: VBoxContainer  = $VBoxContainer/RecipesContainer
@onready var cancel_button: Button       = $VBoxContainer/CancelButton
@onready var title_label: Label          = $VBoxContainer/Label

func _ready() -> void:
    # Template caché
    row_template.visible = false

    # Enregistrement auprès du GameManager (si tu l'utilises pour ouvrir/fermer les menus)
    GameManager.register_heater_fuel_menu(self)

    cancel_button.pressed.connect(close_menu)
    hide()

# Appelé par le GameManager ou l'Interactable pour ouvrir le menu de CETTE machine
func open_menu(machine_node: Node) -> void:
    heater_machine_ref = machine_node
    _rebuild_recipes_ui()
    show()

func close_menu() -> void:
    hide()
    _clear_recipes_ui()

# -------------------------------------------------------------------
# Construction dynamique des lignes de recettes
# -------------------------------------------------------------------
func _clear_recipes_ui() -> void:
    for c in recipes_box.get_children():
        c.queue_free()

func _rebuild_recipes_ui() -> void:
    _clear_recipes_ui()
    title_label.text = "Alimenter le chauffage"

    if heater_machine_ref == null:
        return

    var pmc := heater_machine_ref.get_node_or_null("ProcessingMachineComponent") as ProcessingMachineComponent
    if pmc == null:
        push_warning("HeaterMenu: ProcessingMachineComponent introuvable dans la machine.")
        return

    if pmc.accepted_recipes.is_empty():
        var empty_label := Label.new()
        empty_label.text = "Aucune recette disponible."
        recipes_box.add_child(empty_label)
        return

    for recipe in pmc.accepted_recipes:
        _add_recipe_row(recipe, pmc)

func _add_recipe_row(recipe: MachineRecipe, pmc: ProcessingMachineComponent) -> void:
    var row := row_template.duplicate() as HBoxContainer
    row.visible = true
    recipes_box.add_child(row)

    var tex := row.get_node("TextureRect") as TextureRect
    var count_lbl := row.get_node("CountLabel") as Label
    var feed_btn := row.get_node("FeedButton") as Button

    # Icône = celle du 1er ingrédient si dispo
    if recipe.inputs.size() > 0 and recipe.inputs[0].item and recipe.inputs[0].item.icon:
        tex.texture = recipe.inputs[0].item.icon
    else:
        tex.texture = null

    # Nombre de fois possible selon l'inventaire
    var possible := _compute_possible_crafts(recipe)
    count_lbl.text = _recipe_requirement_text(recipe) + "  —  Vous pouvez: %d×" % possible

    feed_btn.text = "Utiliser"
    feed_btn.disabled = (possible == 0)

    # ✅ CORRECTION: fermer uniquement avec ')'
    feed_btn.pressed.connect(func():
        if heater_machine_ref and pmc:
            # IMPORTANT : si une prod précédente est finie, on la ramasse
            if pmc.current_state == ProcessingMachineComponent.State.FINISHED:
                pmc.collect_output()

            var ok = pmc.start_processing(recipe)
            if ok:
                close_menu()
            else:
                feed_btn.disabled = true
    )



# Renvoie le nombre de "crafts" possibles selon l'inventaire courant
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

# Construit une ligne lisible des ingrédients requis
func _recipe_requirement_text(recipe: MachineRecipe) -> String:
    var parts: Array[String] = []
    for ing in recipe.inputs:
        var have := InventoryManager.get_item_count(ing.item)
        parts.append("%s x%d (vous: %d)" % [ing.item.item_name, ing.quantity, have])
    return " + ".join(parts)
