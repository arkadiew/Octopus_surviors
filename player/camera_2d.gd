extends Camera2D
#Настройки камеры
@export var follow_speed: float = 5.0
@export var offset_strength: float = 100.0

var target: Node2D#цель (обычно игрок)

#При старте
func _ready():
	target = get_parent()#камерa следит за родителем (например, за игроком)
#Каждый кадр
func _process(delta: float) -> void:
	if target == null:#если цели нет - ничего не делаем
		return
	#базовая позиция = позиция цели
	var desired_position = target.global_position
	#если у цели есть метод get_velocity - сдвигаем камеру в сторону движения
	if target.has_method("get_velocity"):
		desired_position += target.get_velocity().normalized() * offset_strength
	#плавно двигаем камеру к цели
	global_position = global_position.lerp(desired_position, delta * follow_speed)
