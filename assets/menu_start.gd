extends VBoxContainer

#При запуске сцены
func _ready() -> void:
	#Кнопка "Продолжить" будет доступна только если есть сохранение
	$Continue.disabled = not SaveManager.has_save()

#Кнопка "Выход"
func _on_exit_pressed() -> void:
	get_tree().quit() # закрыть игру

#Кнопка "Старт"
func _on_start_gam_pressed() -> void:
	get_tree().paused = false # снять паузу
	get_tree().change_scene_to_file("res://main.tscn") #загрузить основную сцену

#Кнопка "Новая игра"
func _on_new_game_pressed() -> void:
	SaveManager.delete_save() #удалить сохранение
	get_tree().paused = false #снять паузу
	get_tree().change_scene_to_file("res://main.tscn") #загрузить основную сцену
