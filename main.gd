extends Node2D
#Основные узлы и сцены
@onready var ground_layer: TileMapLayer = $GroundLayer
@onready var player = preload("res://player/player.tscn").instantiate()
@export var enemy_scene: PackedScene = preload("res://enemy/enemy.tscn")
@export var coin_scene: PackedScene = preload("res://coin/coin.tscn")

#Атласы тайлов (земля)
@export var ATLAS_GRASS: Vector2i = Vector2i(1, 7)
@export var ATLAS_SAND:  Vector2i = Vector2i(1, 1)
@export var ATLAS_ROCK:  Vector2i = Vector2i(1, 10)

#Определение зданий
@export var BUILDINGS := [
	{ 
		"id": "big_building",
		"cells": [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),
				  Vector2i(0,1),Vector2i(1,1),Vector2i(2,1),
				  Vector2i(0,2),Vector2i(1,2),Vector2i(2,2)],
		"ground": ATLAS_ROCK,
		"weight": 1
	},
	{ 
		"id": "small_building",
		"cells": [Vector2i(10,10),Vector2i(11,10),
				  Vector2i(10,11),Vector2i(11,11)],
		"ground": ATLAS_SAND,
		"weight": 4
	},
	{ 
		"id": "grass_building",
		"cells": [Vector2i(17,7),Vector2i(18,7),Vector2i(19,7),
				  Vector2i(17,8),Vector2i(18,8),Vector2i(19,8),
				  Vector2i(17,9),Vector2i(18,9),Vector2i(19,9)],
		"ground": ATLAS_GRASS,
		"weight": 2
	}
]
#Переменные для карты и игры
var saved_buildings: Array = [] 
var noise: FastNoiseLite
var objects: Array = []           
var occupied_cells: Array[Vector2i] = []
var enemy_timer: float 
var score: int 
var enemy_initial_count: int 
var enemy_min_spacing: float 
var map_size: Vector2i
var seed: int
var frequency: float
var tile_scale: float
var enemy_spawn_interval: float
var spawn_distance: float
var player_speed: float
var player_health: int
var coins_count: int
var enemy_speed: float
var building_density: int 
var player_safe_radius: int
var coin_min_spacing: float 
var coin_near_building_chance: float 
var coin_near_building_min_dist: int 
var coin_near_building_max_dist: int
var coin_max_building: int 

#UI
@onready var health_bar: ProgressBar = get_node("CanvasUI/UI/hp")
@onready var labelinfo: Label = get_node("CanvasUI/UI/GameOverorWin/panellinfo/Infogame")
@onready var labelwinorgameower: Label = get_node("CanvasUI/UI/GameOverorWin/panellinfo/GameOverorWinLabel")
@onready var panelwinorgameower: Panel = get_node("CanvasUI/UI/GameOverorWin")
@onready var panelmenu: Panel = get_node("CanvasUI/UI/Menu")
@onready var score_label = get_node("CanvasUI/UI/HBoxContainer/ScoreLabel")

#Регистрирует объект и убирает его из списка после удаления
func _register_object(obj: Node2D) -> void:
	objects.append(obj)
	obj.tree_exited.connect(func():
		if obj in objects:
			objects.erase(obj)
	)
#Открытие/закрытие меню на ESC
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed and not event.echo:
		if panelmenu.visible:
			panelmenu.visible = false
			get_tree().paused = false
		else:
			panelmenu.visible = true
			get_tree().paused = true
			
#При запуске
func _ready() -> void:
	_load_config()
	_load_building_weights()
	score = 0
	score_label.text = "Score 0/%d" % [coins_count]
	ground_layer.scale = Vector2(tile_scale, tile_scale)
	health_bar.max_value = player_health
	health_bar.value = player_health
	player.health_changed.connect(_on_player_health_changed)
	noise = FastNoiseLite.new()
	noise.seed = seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = frequency
	
	# Проверяем, не было ли рестарта
	if get_tree().has_meta("new_game") and get_tree().get_meta("new_game"):
		get_tree().set_meta("new_game", false) # сбросить флаг
		# запускаем чистую новую партию
		if not player.is_inside_tree():
			add_child(player)
			_register_object(player)
		player.set("speed", player_speed)
		player.set("health", player_health)
		generate_map()
		var center_px = get_map_center_px()
		player.global_position = center_px
		spawn_player_safe()
		create_invisible_walls()
		spawn_coins_across_map()
		spawn_enemies_across_map()
	else:
		# обычная логика – если есть сейв, загрузить
		if SaveManager.has_save():
			if not player.is_inside_tree():
				add_child(player)
				_register_object(player)
			player.set("speed", player_speed)
			player.set("health", player_health)
			load_game()
			create_invisible_walls()
		else:
			generate_map()
			var center_px = get_map_center_px()
			player.global_position = center_px
			player.set("speed", player_speed)
			player.set("health", player_health)
			spawn_player_safe()
			create_invisible_walls()
			spawn_coins_across_map()
			spawn_enemies_across_map()

		
#Загрузка параметров из config
func _load_config() -> void:
	#читает game_config.cfg и применяет значения
	#(размер карты, здоровье игрока, скорость врагов и т.д.)
	var config = ConfigFile.new()
	var err = config.load("res://config/game_config.cfg")
	if err != OK:
		push_error("Ошибка загрузки game_config.cfg!")
		return
	map_size = Vector2i(
		config.get_value("map", "size_x", 100),
		config.get_value("map", "size_y", 100)
	)
	seed = config.get_value("map", "seed", 1337)
	frequency = config.get_value("map", "frequency", 0.05)
	tile_scale = config.get_value("map", "tile_scale", 2.0)
	building_density = int(config.get_value("map", "building_density", 20))
	if building_density <= 0:
		building_density = 20

	enemy_spawn_interval = config.get_value("enemy", "spawn_interval", 3.0)
	spawn_distance = config.get_value("enemy", "spawn_distance", 400.0)
	enemy_speed = config.get_value("enemy", "speed", 150)
	player_speed        = config.get_value("player", "speed", 200)
	player_health       = config.get_value("player", "health", 3)
	var player_accel    = config.get_value("player", "accel", 12)
	var player_dash_spd = config.get_value("player", "dash_speed", 1000.0)
	var player_dash_time= config.get_value("player", "dash_time", 0.15)
	var player_dash_cd  = config.get_value("player", "dash_cooldown", 0.4)
	var bullet_offset   = config.get_value("player", "bullet_offset", 16.0)
	var fire_cd         = config.get_value("player", "fire_cooldown", 0.25)
	var invul_time      = config.get_value("player", "invulnerable_time", 0.6)
	var knockback       = config.get_value("player", "hurt_knockback", 260.0)
	coins_count = config.get_value("victory", "coins_required", 10)
	coin_min_spacing    = config.get_value("coins", "coin_min_spacing", 128.0)
	coin_near_building_chance = config.get_value("coins", "spawn_near_building_chance", 0.25)
	coin_near_building_min_dist = config.get_value("coins", "spawn_near_building_min_dist", 1)
	coin_near_building_max_dist = config.get_value("coins", "spawn_near_building_max_dist", 3)
	coin_max_building = config.get_value("coins", "max_building_coins", 5)
	enemy_initial_count = int(config.get_value("enemy", "initial_count", 8))
	enemy_min_spacing = float(config.get_value("enemy", "min_spacing", 192.0))
	player_safe_radius  = int(config.get_value("player", "safe_radius", 6))
	player.set("speed", player_speed)
	player.set("health", player_health)
	player.set("accel", player_accel)
	player.set("dash_speed", player_dash_spd)
	player.set("dash_time", player_dash_time)
	player.set("dash_cooldown", player_dash_cd)
	player.set("bullet_offset", bullet_offset)
	player.set("fire_cooldown", fire_cd)
	player.set("invulnerable_time", invul_time)
	player.set("hurt_knockback", knockback)
	
#Загрузка весов зданий
func _load_building_weights() -> void:
	#читает building_weights.cfg и меняет вероятность появления зданий
	var cfg = ConfigFile.new()
	var err = cfg.load("res://config/building_weights.cfg")
	if err != OK:
		push_warning("Не удалось загрузить building_weights.cfg, будут использованы стандартные веса")
		return
	for b in BUILDINGS:
		var id = b.get("id", "")
		if id != "":
			var new_weight = cfg.get_value("weights", id, b["weight"])
			b["weight"] = int(new_weight)
			
#Монеты
func spawn_coins_across_map() -> void:
	#случайным образом спавнит монеты по карте
	#учитывает расстояния, близость к зданиям и т.д.
	if coin_scene == null:
		return
	var margin: float = 64.0
	var tile_px := Vector2(ground_layer.tile_set.tile_size)
	var tile_center_offset := tile_px * 0.5
	var spawned := 0
	var tries := 0
	var max_tries := coins_count * 20
	var coin_positions: Array[Vector2] = []
	var building_coins := 0
	while spawned < coins_count and tries < max_tries:
		tries += 1
		var cell = Vector2i(randi() % map_size.x, randi() % map_size.y)
		if is_near_border(cell):
			continue
		if is_cell_occupied(cell):
			continue
		var near_building = is_within_building_radius(cell, coin_near_building_min_dist, coin_near_building_max_dist)
		if near_building:
			if building_coins >= coin_max_building:
				continue
			if randf() > coin_near_building_chance:
				continue
		else:
			if not is_valid_spawn(cell, 3, coin_min_spacing / tile_px.x):
				continue
				
		var pos = cell_to_px(cell) + tile_center_offset
		var too_close = false
		for p in coin_positions:
			if pos.distance_to(p) < coin_min_spacing:
				too_close = true
				break
		if too_close:
			continue
		var coin = coin_scene.instantiate()
		coin.position = pos
		add_child(coin)
		if coin.has_signal("collected"):
			coin.collected.connect(_on_coin_collected)
		_register_object(coin)
		coin_positions.append(pos)
		spawned += 1
		if near_building:
			building_coins += 1
	if spawned < coins_count:
		print("spawn_coins_across_map: spawned %d of %d (tries %d)" % [spawned, coins_count, tries])
		
func _on_coin_collected() -> void:
	score += 1
	score_label.text = "Score %d/%d" % [score, coins_count]
	if score >= coins_count:
		show_victory_message()
		
#Враги
func spawn_enemy_outside_screen() -> void:
	#спавнит врагов за пределами камеры
	if enemy_scene == null:
		return
	var cam = get_viewport().get_camera_2d()
	if cam == null:
		return

	var margin: float = 64.0
	var tile_center_offset = Vector2(ground_layer.tile_set.tile_size) * ground_layer.scale * 0.5
	var map_px_size = cell_to_px(map_size)

	var tries = 0
	while tries < 20:
		tries += 1
		# случайная клетка карты
		var cell = Vector2i(randi() % map_size.x, randi() % map_size.y)
		if is_near_border(cell):
			continue
		if not is_valid_spawn(cell, 6, 2):
			continue

		var pos = cell_to_px(cell) + tile_center_offset
		# проверка что внутри карты
		if pos.x < margin or pos.y < margin or pos.x > map_px_size.x - margin or pos.y > map_px_size.y - margin:
			continue

		# проверка — за пределами экрана
		var screen_rect = Rect2(
			cam.global_position - get_viewport().size * 0.5,
			get_viewport().size
		).grow(200) # +200px, чтобы точно не было видно спавна
		if screen_rect.has_point(pos):
			continue

		# создаём врага
		var enemy = enemy_scene.instantiate()
		enemy.set("speed", enemy_speed)
		add_child(enemy)
		enemy.global_position = pos
		_register_object(enemy)
		return
	
#Проверка спавна
func is_valid_spawn(cell: Vector2i, min_dist_from_player: float = 0.0, min_dist_from_objects: float = 0.0) -> bool:
	#проверяет, можно ли спавнить объект в ячейке
	if is_near_border(cell):
		return false
	if is_cell_occupied(cell):
		return false
	var player_cell = ground_layer.local_to_map(player.global_position)
	if min_dist_from_player > 0.0 and cell.distance_to(player_cell) < min_dist_from_player:
		return false
	for obj in objects:
		if not is_instance_valid(obj):
			continue
		var obj_cell = ground_layer.local_to_map(obj.global_position)
		if min_dist_from_objects > 0.0 and cell.distance_to(obj_cell) < min_dist_from_objects:
			return false
	return true

func is_within_building_radius(cell: Vector2i, min_d: int, max_d: int) -> bool:
	#проверяет, находится ли клетка рядом со зданием
	for occupied in occupied_cells:
		var dist = cell.distance_to(occupied)
		if dist >= min_d and dist <= max_d:
			return true
	return false
	
#Победа/поражение
func show_victory_message() -> void:
	panelwinorgameower.visible = true
	labelwinorgameower.text = "win"
	labelinfo.text = "You score %d" % [score]
	get_tree().paused = true

func _on_player_health_changed(current: int) -> void:
	health_bar.value = current
	if current <= 0:
		game_over()

func game_over() -> void:
	panelwinorgameower.visible = true
	labelwinorgameower.text = "game over"
	labelinfo.text = "You score %d" % [score]
	get_tree().paused = true
	
#Генерация карты
func generate_map() -> void:
	#заполняет карту тайлами с помощью шума
	#добавляет здания
	ground_layer.clear()
	for y in range(map_size.y):
		for x in range(map_size.x):
			var n = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var atlas: Vector2i
			if n < 0.30:
				atlas = ATLAS_SAND
			elif n < 0.45:
				atlas = ATLAS_GRASS
			elif n < 0.65:
				atlas = ATLAS_ROCK
			elif n < 0.85:
				atlas = ATLAS_GRASS
			else:
				atlas = ATLAS_ROCK
			ground_layer.set_cell(Vector2i(x, y), 0, atlas)
			
	if saved_buildings.size() > 0:
		occupied_cells.clear()
		for b in saved_buildings:
			var cell := Vector2i(b["x"], b["y"])
			var atlas := _arr_to_v2i(b["atlas"])
			var source_id: int = b.get("source_id", 1)
			ground_layer.set_cell(cell, source_id, atlas)
			occupied_cells.append(cell)
		print("generate_map: restored saved buildings")
		return
		
	var area = map_size.x * map_size.y
	var density: int = max(1, building_density)
	var max_buildings: int = max(1, int(ceil(area / float(density))))
	var min_buildings: int = clamp(int(max_buildings / 2), 1, max_buildings)
	var building_count: int = randi_range(min_buildings, max_buildings)
	
	for i in range(building_count):
		var pos = Vector2i(randi_range(0, map_size.x - 1), randi_range(0, map_size.y - 1))
		var building = pick_weighted_building()
		if can_place_building(pos, building):
			place_building(pos, building)
			
func can_place_building(map_pos: Vector2i, building: Dictionary) -> bool:
	#проверяет, можно ли поставить здание
	var min_x = INF
	var min_y = INF
	for cell in building["cells"]:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
		
	for cell in building["cells"]:
		var offset = Vector2i(cell.x - min_x, cell.y - min_y)
		var final_pos = map_pos + offset
		if not is_valid_spawn(final_pos, 5):
			return false
		var ground_source = ground_layer.get_cell_source_id(final_pos)
		var ground_atlas  = ground_layer.get_cell_atlas_coords(final_pos)
		if ground_atlas != building["ground"]:
			return false
	return true
	
func place_building(map_pos: Vector2i, building: Dictionary) -> void:
	#ставит здание на карту
	var min_x = INF
	var min_y = INF
	for cell in building["cells"]:
		min_x = min(min_x, cell.x)
		min_y = min(min_y, cell.y)
	for cell in building["cells"]:
		var offset = Vector2i(cell.x - min_x, cell.y - min_y)
		var final_pos = map_pos + offset
		var building_source_id = 1 
		ground_layer.set_cell(final_pos, building_source_id, cell)
		occupied_cells.append(final_pos)
		saved_buildings.append({
			"x": final_pos.x,
			"y": final_pos.y,
			"source_id": building_source_id,
			"atlas": _v2i_to_arr(cell)
		})
		
func pick_weighted_building() -> Dictionary:
	#выбирает здание с учётом веса
	var total_weight = 0
	for b in BUILDINGS:
		total_weight += b.get("weight", 1)
	var r = randi_range(1, total_weight)
	var cumulative = 0
	for b in BUILDINGS:
		cumulative += b.get("weight", 1)
		if r <= cumulative:
			return b
	return BUILDINGS[0]
	
#Ограничения карты
func create_invisible_walls() -> void:
	var map_px_size = Vector2(map_size) * get_tile_px()
	var wall_thickness = 64.0
	_add_wall(Rect2(Vector2(0, -wall_thickness), Vector2(map_px_size.x, wall_thickness)))
	_add_wall(Rect2(Vector2(0, map_px_size.y), Vector2(map_px_size.x, wall_thickness)))
	_add_wall(Rect2(Vector2(-wall_thickness, 0), Vector2(wall_thickness, map_px_size.y)))
	_add_wall(Rect2(Vector2(map_px_size.x, 0), Vector2(wall_thickness, map_px_size.y)))

	
func _add_wall(rect: Rect2) -> void:
	var wall = StaticBody2D.new()
	var collider = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.size * 0.5
	wall.add_child(collider)
	wall.position = rect.position
	add_child(wall)
	
#Конвертеры

func _v2i_to_arr(v: Vector2i) -> Array:
	return [v.x, v.y]

func _arr_to_v2i(a: Array) -> Vector2i:
	return Vector2i(int(a[0]), int(a[1]))
	
# проверка близости к зданиям
func is_near_building(cell: Vector2i, radius: int = 2) -> bool:
	for occ in occupied_cells:
		if cell.distance_to(occ) <= radius:
			return true
	return false
	
func get_map_px_size() -> Vector2:
	return Vector2(map_size) * Vector2(ground_layer.tile_set.tile_size) * ground_layer.scale
	
func is_inside_map_with_margin(pos: Vector2, margin: float = 64.0) -> bool:
	var map_px_size = get_map_px_size()
	return pos.x >= margin and pos.y >= margin \
		and pos.x <= map_px_size.x - margin \
		and pos.y <= map_px_size.y - margin
		
#размер тайла с учётом масштаба	
func get_tile_px() -> Vector2:
	return Vector2(ground_layer.tile_set.tile_size) * ground_layer.scale
	
# клетка -> позиция в пикселях	
func cell_to_px(cell: Vector2i) -> Vector2:
	return Vector2(cell) * get_tile_px()
	
# позиция в пикселях -> клетка
func px_to_cell(pos: Vector2) -> Vector2i:
	var tile_px = get_tile_px()
	return Vector2i(floor(pos.x / tile_px.x), floor(pos.y / tile_px.y))
	
#центр карты в пикселях
func get_map_center_px() -> Vector2:
	return Vector2(map_size) * get_tile_px() * 0.5
	
func is_inside_map(pos: Vector2) -> bool:
	var cell_px := Vector2(ground_layer.tile_set.tile_size) * ground_layer.scale
	var map_px_size := Vector2(map_size) * cell_px
	return pos.x >= 0.0 and pos.y >= 0.0 and pos.x < map_px_size.x and pos.y < map_px_size.y
	
func is_cell_occupied(cell: Vector2i) -> bool:
	return cell in occupied_cells
	
func is_near_border(cell: Vector2i) -> bool:
	return cell.x <= 0 or cell.y <= 0 or cell.x >= map_size.x - 1 or cell.y >= map_size.y - 1
	
func _process(delta: float) -> void:
	enemy_timer += delta
	if enemy_timer >= enemy_spawn_interval:
		spawn_enemy_outside_screen()
		enemy_timer = 0.0
		
func spawn_enemies_across_map() -> void:
	#размещает врагов по карте при старте
	if enemy_scene == null:
		return
	var tile_px: Vector2 = Vector2(ground_layer.tile_set.tile_size) * ground_layer.scale
	var tile_center_offset: Vector2 = tile_px * 0.5
	var spawned: int = 0
	var tries: int = 0
	var max_tries: int = enemy_initial_count * 20
	var positions: Array[Vector2] = []
	var map_px_size: Vector2 = cell_to_px(map_size)
	var margin: float = 64.0
	
	while spawned < enemy_initial_count and tries < max_tries:
		tries += 1
		var cell: Vector2i = Vector2i(randi() % map_size.x, randi() % map_size.y)
		
		if is_near_border(cell):
			continue
		if is_cell_occupied(cell):
			continue
			
		var player_cell = px_to_cell(player.global_position)
		if cell.distance_to(player_cell) < player_safe_radius:
			continue
			
		var pos: Vector2 = cell_to_px(cell) + tile_center_offset
		pos.x = clamp(pos.x, margin, map_px_size.x - margin)
		pos.y = clamp(pos.y, margin, map_px_size.y - margin)
		
		var bad := false
		for p in positions:
			if pos.distance_to(p) < enemy_min_spacing:
				bad = true
				break
		if bad:
			continue
			
		var enemy = enemy_scene.instantiate()
		enemy.global_position = pos
		add_child(enemy)
		_register_object(enemy)
		enemy.speed = enemy_speed
		positions.append(pos)
		spawned += 1
		
	if spawned < enemy_initial_count:
		print("spawned %d of %d (tries %d)" % [spawned, enemy_initial_count, tries])
		
#Спавн игрока
func spawn_player_safe() -> void:
	#ставит игрока в безопасное место
	var tile_px := Vector2(ground_layer.tile_set.tile_size) * ground_layer.scale
	var tile_center_offset := tile_px * 0.5
	var max_tries := 500
	var tries := 0
	# ограничиваем область поиска центральной зоной карты
	var margin := map_size / 3
	var min_x := margin.x
	var max_x := map_size.x - margin.x
	var min_y := margin.y
	var max_y := map_size.y - margin.y
	while tries < max_tries:
		tries += 1
		var cell: Vector2i = Vector2i(
			randi_range(min_x, max_x - 1),
			randi_range(min_y, max_y - 1)
		)
		# нельзя на границе
		if is_near_border(cell):
			continue
		# нельзя на здании или занятой клетке
		if is_cell_occupied(cell):
			continue
		# нельзя рядом со зданием (радиус 2 клетки)
		if is_near_building(cell, 2):
			continue
		# проверка окружения (чтобы рядом не было плотных объектов)
		if not is_valid_spawn(cell, 6, 6):
			continue
		# ставим игрока
		var pos: Vector2 = cell_to_px(cell) + tile_center_offset
		player.global_position = pos
		if not player.is_inside_tree():
			add_child(player)
			_register_object(player)
		return
	#центр карты
	push_warning("spawn_player_safe: не нашли безопасную клетку, ставим игрока в центр")
	player.global_position = get_map_center_px()
	if not player.is_inside_tree():
		add_child(player)
		_register_object(player)

#Сохранение и загрузка  
func save_game() -> void:
	#собирает данные: очки, игрока, здания, врагов, монеты
	#сохраняет их через SaveManager
	var state: Dictionary = {}
	state["score"] = score
	state["player"] = {
		"pos": [player.global_position.x, player.global_position.y],
		"hp": player.health
	}
	
	state["atlas"] = {
		"grass": _v2i_to_arr(ATLAS_GRASS),
		"sand":  _v2i_to_arr(ATLAS_SAND),
		"rock":  _v2i_to_arr(ATLAS_ROCK)
	}
	var defs: Array = []
	for b in BUILDINGS:
		defs.append({
			"id": b["id"],
			"cells": b["cells"].map(func(c): return _v2i_to_arr(c)),
			"ground": _v2i_to_arr(b["ground"]),
			"weight": b["weight"]
		})
	state["building_defs"] = defs
	
	var enemies: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		enemies.append({
			"name": e.name,
			"pos": [e.global_position.x, e.global_position.y],
			"hp": e.hp if "hp" in e else null,
			"scene": e.get_scene_file_path() if e.has_method("get_scene_file_path") else ""
		})
	state["enemies"] = enemies
	var coins: Array = []
	for c in get_tree().get_nodes_in_group("coins"):
		coins.append({
			"name": c.name,
			"pos": [c.global_position.x, c.global_position.y],
			"scene": c.get_scene_file_path() if c.has_method("get_scene_file_path") else ""
		})
	state["coins"] = coins
	state["buildings"] = saved_buildings.duplicate(true)
	SaveManager.save_game(state)
	
func load_game() -> void:
	#загружает данные через SaveManager
	#восстанавливает игрока, здания, врагов и монеты
	var state: Dictionary = SaveManager.load_game()
	if state.is_empty():
		return
		
	if state.has("score"):
		score = state["score"]
		score_label.text = "Score %d/%d" % [score, coins_count]
		
	if state.has("player"):
		var pdata = state["player"]
		player.global_position = Vector2(pdata["pos"][0], pdata["pos"][1])
		player.health = pdata["hp"]
		
	if state.has("atlas"):
		var a = state["atlas"]
		ATLAS_GRASS = _arr_to_v2i(a["grass"])
		ATLAS_SAND  = _arr_to_v2i(a["sand"])
		ATLAS_ROCK  = _arr_to_v2i(a["rock"])
		
	if state.has("building_defs"):
		BUILDINGS.clear()
		for bd in state["building_defs"]:
			BUILDINGS.append({
				"id": bd["id"],
				"cells": bd["cells"].map(func(c): return _arr_to_v2i(c)),
				"ground": _arr_to_v2i(bd["ground"]),
				"weight": bd["weight"]
			})
			
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await get_tree().process_frame
	if state.has("enemies"):
		for edata in state["enemies"]:
			var packed: PackedScene = load(edata["scene"])
			if packed:
				var e = packed.instantiate()
				add_child(e)
				e.name = edata["name"]
				e.global_position = Vector2(edata["pos"][0], edata["pos"][1])
				if edata.has("hp") and edata["hp"] != null:
					e.hp = edata["hp"]
					
	for c in get_tree().get_nodes_in_group("coins"):
		c.queue_free()
	await get_tree().process_frame
	if state.has("coins"):
		for cdata in state["coins"]:
			var packed: PackedScene = load(cdata["scene"])
			if packed:
				var c = packed.instantiate()
				add_child(c)
				c.name = cdata["name"]
				c.global_position = Vector2(cdata["pos"][0], cdata["pos"][1])
				if c.has_signal("collected"):
					c.collected.connect(_on_coin_collected)
				_register_object(c)
				
	saved_buildings.clear()
	occupied_cells.clear()
	if state.has("buildings"):
		for b in state["buildings"]:
			saved_buildings.append(b.duplicate(true))
	generate_map()
