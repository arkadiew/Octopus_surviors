class_name Bullet
extends CharacterBody2D

signal hit_enemy(enemy: Node) #сигнал, что пуля попала во врага

#Настройки
@export var speed: float = 500.0
@export var life_time: float = 2.0
@export var max_bounces: int = 5

#Переменные
var direction: Vector2 = Vector2.ZERO
var _life := 0.0
var bounces := 0

#Логика движения 
func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:#если нет направления - не двигаемся
		return
	#двигаем пулю
	velocity = direction * speed
	var collision := move_and_collide(velocity * delta)
	#если есть столкновение
	if collision:
		var collider := collision.get_collider()
		#если попали во врага - отправляем сигнал и удаляем пулю
		if collider and collider.is_in_group("enemy"):
			emit_signal("hit_enemy", collider) 
			queue_free() 
			return
		#иначе - отскакиваем от поверхности
		direction = direction.bounce(collision.get_normal())
		bounces += 1
		if bounces > max_bounces:# слишком много отскоков -> уничтожаем
			queue_free()
	#ограничение по времени жизни 
	_life += delta
	if _life >= life_time:
		queue_free()
