extends Node

# Путь к файлу сохранения
const SAVE_PATH: String = "user://savegame.json"

# Проверка, есть ли сохранение
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

# Удаление сохранения
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
		print("Сохранение удалено:", SAVE_PATH)

# Сохранение игры
func save_game(state: Dictionary) -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE) # открыть файл
	if f == null: # если ошибка
		push_error("Не удалось открыть файл: " + SAVE_PATH)
		return
	f.store_string(JSON.stringify(state)) # записать данные
	f.close() # закрыть файл
	print("Игра сохранена в:", SAVE_PATH)

# Загрузка игры
func load_game() -> Dictionary:
	if not has_save(): # если нет файла
		return {}
	var text := FileAccess.get_file_as_string(SAVE_PATH) # читаем файл
	var data: Variant = JSON.parse_string(text) # превращаем JSON в данные
	if typeof(data) != TYPE_DICTIONARY: # если не словарь
		push_warning("Сохранение повреждено")
		return {}
	return data # вернуть данные
