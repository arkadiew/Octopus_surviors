class_name Enemy
extends CharacterBody2D

#Параметры врага
@export var speed: float = 60.0
@export var path_update_interval: float = 0.5
@export var min_prediction_time: float = 0.1
@export var max_prediction_time: float = 1.0
@export var max_prediction_distance: float = 500.0
@export var active_distance: float = 1200.0
@export var sleep_distance: float = 2000.0

@export var walk_anim: String = "down"
@export var death_anim: String = "death"

#Узлы
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var nav_agent: NavigationAgent2D = $NavigationAgent2D
@onready var area: Area2D = $Area2D

#Переменные
var player: CharacterBody2D
var is_dead: bool = false
var _time_since_path_update: float = 0.0
var _nav_map: RID

#Состояния врага
enum State { SLEEPING, PATROLLING, CHASING, DEAD }
var state: State = State.SLEEPING

#Запуск
func _ready() -> void:
	player = get_tree().get_first_node_in_group("player") as CharacterBody2D
	_time_since_path_update = randf_range(0.0, path_update_interval)
	#подключаем область удара
	if area:
		area.body_entered.connect(_on_body_entered)
	#настройка NavigationAgent
	if nav_agent:
		nav_agent.avoidance_enabled = true
		nav_agent.radius = 16.0
		nav_agent.max_speed = speed
		nav_agent.path_desired_distance = 4.0
		nav_agent.target_desired_distance = 4.0
		nav_agent.neighbor_distance = 64.0
		nav_agent.max_neighbors = 8
		nav_agent.time_horizon = 0.5
	#ждём кадр, чтобы карта прогрузилась
	await get_tree().process_frame
	_nav_map = nav_agent.get_navigation_map()
	if not _nav_map.is_valid():
		_nav_map = get_world_2d().navigation_map
	#подключаемся к новым пулям
	get_tree().connect("node_added", Callable(self, "_on_node_added"))
	for b: Node in get_tree().get_nodes_in_group("bullet"):
		_try_connect_bullet(b)
		
#Логика врага  
func _physics_process(delta: float) -> void:
	if is_dead or not player:#если враг мёртв - ничего не делаем
		return
		
	var dist: float = global_position.distance_to(player.global_position)
	match state:
		State.SLEEPING:
			_process_sleeping(dist)
			
		State.PATROLLING:
			_process_patrolling(dist)
			
		State.CHASING:
			_process_chasing(delta, dist)
			
		State.DEAD:
			velocity = Vector2.ZERO
	move_and_slide()
	
#Состояния  
func _process_sleeping(dist: float) -> void:
	if dist <= sleep_distance:#если игрок рядом - просыпается
		_change_state(State.PATROLLING)
		
func _process_patrolling(dist: float) -> void:
	velocity = Vector2.ZERO
	if dist <= active_distance:#если игрок близко - начинает гнаться
		_change_state(State.CHASING)
	elif dist > sleep_distance:# если игрок далеко — снова спит
		_change_state(State.SLEEPING)
		
func _process_chasing(delta: float, dist: float) -> void:
	if dist > sleep_distance:
		_change_state(State.SLEEPING)
		return
	#обновление пути
	_time_since_path_update += delta
	if _time_since_path_update >= path_update_interval and nav_agent:
		_time_since_path_update = 0.0
		var t: float = clamp(dist / max_prediction_distance, 0.0, 1.0)
		var prediction_time: float = lerp(min_prediction_time, max_prediction_time, t)
		var predicted_pos: Vector2 = player.global_position + player.velocity * prediction_time
		call_deferred("set_nav_target", predicted_pos)
	#движение по пути
	if not _nav_map.is_valid() or NavigationServer2D.map_get_iteration_id(_nav_map) == 0:
		return
		
	if nav_agent and not nav_agent.is_navigation_finished():
		var next_pos: Vector2 = nav_agent.get_next_path_position()
		var dir: Vector2 = (next_pos - global_position).normalized()
		velocity = dir * speed
	else:
		velocity = (player.global_position - global_position).normalized() * speed
	#избегание столкновений
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(velocity)
		var safe_velocity: Vector2 = nav_agent.get_velocity()
		if safe_velocity != Vector2.ZERO:
			velocity = safe_velocity.normalized() * speed
	#включаем анимацию
	if sprite and not sprite.is_playing():
		sprite.play(walk_anim)
		
#Смена состояния
func _change_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	match state:
		State.SLEEPING:
			velocity = Vector2.ZERO
			if sprite: sprite.stop()
		State.PATROLLING:
			velocity = Vector2.ZERO
			if sprite: sprite.stop()
		State.CHASING:
			if sprite: sprite.play(walk_anim)
		State.DEAD:
			velocity = Vector2.ZERO
			if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation(death_anim):
				sprite.play(death_anim)
				await sprite.animation_finished
			queue_free()
			
#Навигация
func set_nav_target(pos: Vector2) -> void:
	if nav_agent:
		nav_agent.target_position = pos
#Пули
func _on_node_added(node: Node) -> void:
	if node.is_in_group("bullet"):
		call_deferred("_try_connect_bullet", node)
		
func _try_connect_bullet(node: Node) -> void:
	if node.has_signal("hit_enemy") and not node.is_connected("hit_enemy", Callable(self, "_on_bullet_hit")):
		node.connect("hit_enemy", Callable(self, "_on_bullet_hit"))
		
func _on_bullet_hit(enemy: Node) -> void:
	if enemy == self:
		die()
		
#Смерть
func die() -> void:
	if is_dead:
		return
	is_dead = true
	_change_state(State.DEAD)
	var die_sound := AudioStreamPlayer2D.new()
	die_sound.stream = preload("res://assets/Ninja Adventure - Asset Pack/Audio/Sounds/Hit & Impact/Hit2.wav")
	die_sound.global_position = global_position
	get_parent().add_child(die_sound)
	die_sound.play()
	
#Урон игроку
func _on_body_entered(body: Node) -> void:
	if is_dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(1)
