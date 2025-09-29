extends CharacterBody2D

signal health_changed(current: int) #сигнал при изменении здоровья

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D3

#Параметры игрока
@export var invulnerable_time: float
@export var speed: float   
@export var accel: float
@export var dash_speed: float
@export var dash_time: float
@export var dash_cooldown: float
@export var health: int

#Параметры стрельбы
@export var bullet_scene: PackedScene = preload("res://assets/bullet.tscn")
@export var bullet_offset: float
@export var fire_cooldown: float
var fire_timer := 0.0

#Таймеры
var invul_timer: float = 0.0
var dash_timer := 0.0
var cd_timer := 0.0
var dash_dir := Vector2.ZERO

#Последнее направление движения
var last_dir := Vector2.DOWN   

#Основная логика игрока
func _physics_process(delta: float) -> void:
	if invul_timer > 0.0: #уменьшаем таймер неуязвимости
		invul_timer -= delta

	#Чтение ввода (WASD)
	var input_dir := Vector2(
		int(Input.is_action_pressed("button_d")) - int(Input.is_action_pressed("button_a")),
		int(Input.is_action_pressed("button_s")) - int(Input.is_action_pressed("button_w"))
	)
	if input_dir != Vector2.ZERO:
		input_dir = input_dir.normalized()
		last_dir = input_dir
	
	#Рывок
	if cd_timer <= 0.0 and dash_timer <= 0.0 and Input.is_action_just_pressed("dash"):
		dash_dir = input_dir
		dash_timer = dash_time
		cd_timer = dash_cooldown
	
	#Если идёт рывок
	if dash_timer > 0.0:
		velocity = dash_dir * dash_speed
		dash_timer -= delta
		_play_dash_anim(dash_dir)
	else: #обычное движение
		var target_vel := input_dir * speed
		velocity = velocity.lerp(target_vel, clamp(accel * delta, 0.0, 1.0))

		#Анимации
		if input_dir == Vector2.ZERO:
			_play_idle_anim()
		else:
			_play_walk_anim(input_dir)

	#Обновляем таймеры
	if cd_timer > 0.0:
		cd_timer -= delta
	if fire_timer > 0.0:
		fire_timer -= delta

	#Стрельба
	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		_shoot()
		fire_timer = fire_cooldown

	move_and_slide() #движение игрока
	
#Анимации  
func _play_walk_anim(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			anim.play("walk_right")
		else:
			anim.play("walk_left")
	else:
		if dir.y > 0:
			anim.play("walk_down")
		else:
			anim.play("walk_up")

func _play_idle_anim() -> void:
	if abs(last_dir.x) > abs(last_dir.y):
		if last_dir.x > 0:
			anim.play("idle_right")
		else:
			anim.play("idle_left")
	else:
		if last_dir.y > 0:
			anim.play("idle_down")
		else:
			anim.play("idle_up")

func _play_dash_anim(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0 and anim.sprite_frames.has_animation("dash_right"):
			anim.play("dash_right")
		elif anim.sprite_frames.has_animation("dash_left"):
			anim.play("dash_left")
	else:
		if dir.y > 0 and anim.sprite_frames.has_animation("dash_down"):
			anim.play("dash_down")
		elif anim.sprite_frames.has_animation("dash_up"):
			anim.play("dash_up")
			
#Стрельба
func _shoot() -> void:
	if bullet_scene == null:
		return
		
	var dir := last_dir
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	dir = dir.normalized()

	#создаём пулю
	var bullet := bullet_scene.instantiate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position + dir * bullet_offset
	bullet.direction = dir

	#звук выстрела
	var shoot_sound := AudioStreamPlayer2D.new()
	shoot_sound.stream = preload("res://assets/Ninja Adventure - Asset Pack/Audio/Sounds/Hit & Impact/Impact5.wav")
	shoot_sound.global_position = global_position
	get_parent().add_child(shoot_sound)
	shoot_sound.play()
	shoot_sound.connect("finished", Callable(shoot_sound, "queue_free"))
	
#Получение урона
func take_damage(amount: int) -> void:
	if invul_timer > 0.0: #если ещё есть неуязвимость
		return
	health -= amount #уменьшаем здоровье
	emit_signal("health_changed", health) #сообщаем об изменении
	invul_timer = invulnerable_time #включаем неуязвимость

	#звук получения урона
	var damage_sound := AudioStreamPlayer2D.new()
	damage_sound.stream = preload("res://assets/Ninja Adventure - Asset Pack/Audio/Sounds/Hit & Impact/Hit1.wav")
	damage_sound.global_position = global_position
	get_parent().add_child(damage_sound)
	damage_sound.play()
