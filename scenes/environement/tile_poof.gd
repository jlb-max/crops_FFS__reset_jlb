extends Node2D

@onready var p: GPUParticles2D = $GPUParticles2D

func _ready() -> void:
	if not p:
		queue_free()
		return

	p.one_shot = true
	p.emitting = true

	# Godot 4.x : GPUParticles2D émet "finished" en one_shot
	if p.has_signal("finished"):
		p.finished.connect(func():
			queue_free()
		)
	else:
		# Fallback si le signal n'existe pas : on attend ~la lifetime + marge
		var life: float = maxf(p.lifetime, 0.1)
		await get_tree().create_timer(life + 0.2).timeout
		queue_free()
