extends HBoxContainer

@onready var panelmenu: Panel = $"../../../Menu"        # ссылка на панель меню
@onready var game: Node = get_tree().root.get_node("main") # главный узел игры (main.tscn)

# Кнопка "Заново"
func _on_restart_pressed() -> void:
	get_tree().paused = false         # снять паузу
	get_tree().reload_current_scene() # перезапустить текущую сцену

# Кнопка "Выход"
func _on_exit_button_down() -> void:
	get_tree().change_scene_to_file("res://start_menu.tscn") # перейти в главное меню

#Кнопка "Продолжить"
func _on_continue_pressed() -> void:
	panelmenu.visible = false #скрыть меню
	get_tree().paused = false #снять паузу

#Кнопка "Меню"
func _on_menu_pressed() -> void:
	get_tree().paused = false #снять паузу
	get_tree().change_scene_to_file("res://start_menu.tscn") # перейти в меню

#Кнопка "Сохранить"
func _on_save_pressed() -> void:
	if game == null: #если главный узел не найден
		push_error("Game node not found!")
		return
	game.save_game() #вызываем функцию сохранения в main

#Кнопка "Загрузить"
func _on_load_pressed() -> void:
	if game == null: #если главный узел не найден
		push_error("Game node not found!")
		return
	game.load_game() #вызываем функцию загрузки в main
