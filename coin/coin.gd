extends Area2D

signal collected#сигнал, что монета собрана

#При запуске
func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"): 
		emit_signal("collected")
		queue_free()
