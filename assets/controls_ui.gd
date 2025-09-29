extends CanvasLayer

#Параметры  
@export var show_time: float = 6.0
var timer: float = 0.0

#Узлы
@onready var panel: Panel = $Panel
@onready var label: Label = $Panel/Label

#При запуске
func _ready() -> void:
	#Формируем текст подсказки (клавиши берутся из InputMap)
	label.text = "Controls:\n" + \
		get_key_name("button_w") + "/" + get_key_name("button_a") + "/" + \
		get_key_name("button_s") + "/" + get_key_name("button_d") + " — Move\n" + \
		get_key_name("dash") + " — Dash\n" + \
		get_key_name("shoot") + " — Shoot"
	#Если нужно показывать ограниченное время — запускаем таймер
	if show_time > 0:
		timer = show_time
		
#Каждый кадр
func _process(delta: float) -> void:
	if show_time > 0 and timer > 0:
		timer -= delta
		# Когда время вышло — скрываем панель
		if timer <= 0:
			_hide_with_slide()
			
#Получение названия клавиши по имени действия
func get_key_name(action: String) -> String:
	var events = InputMap.action_get_events(action)
	if events.is_empty():
		return "???"
	return events[0].as_text().replace("(Physical)", "").strip_edges()
	
#Скрытие панели плавным слайдом вниз
func _hide_with_slide() -> void:
	var tween := create_tween()
	tween.tween_property(panel, "position:y", panel.position.y + 200, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(Callable(self, "_on_slide_finished"))
	
#Когда слайд закончился
func _on_slide_finished() -> void:
	visible = false
