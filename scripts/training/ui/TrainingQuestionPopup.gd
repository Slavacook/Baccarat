# res://scripts/training/ui/TrainingQuestionPopup.gd
# ═══════════════════════════════════════════════════════════════════════════
# ПОПАП ВОПРОСА ЭТАПА ОБУЧЕНИЯ
# ═══════════════════════════════════════════════════════════════════════════
# Вопрос и варианты ответов (Да/Нет, выбор действия, два вопроса).
# Эмитит answer_selected(ответ) и hint_requested().
# ═══════════════════════════════════════════════════════════════════════════

class_name TrainingQuestionPopup
extends PopupPanel

## Типы вопроса для UI
enum QuestionType {
	BINARY,        ## Да/Нет
	ACTION_CHOICE, ## Выбор действия (3 варианта)
	DOUBLE_BINARY  ## Два вопроса Да/Нет
}

var question_label: Label
var answer_buttons_container: Container
var hint_button: Button

signal answer_selected(answer: Variant)
signal hint_requested()

# ═══════════════════════════════════════════════════════════════════════════
# ИНИЦИАЛИЗАЦИЯ
# ═══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	question_label = get_node_or_null("MarginContainer/VBox/QuestionLabel") as Label
	answer_buttons_container = get_node_or_null("MarginContainer/VBox/AnswerButtonsContainer") as Container
	hint_button = get_node_or_null("MarginContainer/VBox/HintButton") as Button
	if hint_button:
		hint_button.pressed.connect(_on_hint_button_pressed)

# ═══════════════════════════════════════════════════════════════════════════
# ПУБЛИЧНЫЕ МЕТОДЫ
# ═══════════════════════════════════════════════════════════════════════════

## Настроить попап: текст вопроса, тип и массив вариантов ответов.
func setup(question_text: String, question_type: QuestionType, answer_options: Array) -> void:
	if question_label:
		question_label.text = question_text
	if not answer_buttons_container:
		return
	# Сначала убираем старые кнопки из контейнера, потом освобождаем — иначе при повторном setup()
	# в контейнере остаются старые узлы до конца кадра и раскладка/показ следующего вопроса ломаются.
	var old_children: Array = []
	for child in answer_buttons_container.get_children():
		old_children.append(child)
	for child in old_children:
		answer_buttons_container.remove_child(child)
		child.queue_free()
	match question_type:
		QuestionType.BINARY:
			_create_binary_buttons(answer_options)
		QuestionType.ACTION_CHOICE:
			_create_action_buttons(answer_options)
		QuestionType.DOUBLE_BINARY:
			_create_double_binary_buttons(answer_options)

# ═══════════════════════════════════════════════════════════════════════════
# СОЗДАНИЕ КНОПОК ОТВЕТОВ
# ═══════════════════════════════════════════════════════════════════════════

func _create_binary_buttons(options: Array) -> void:
	var container: HBoxContainer = HBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.add_theme_constant_override("separation", 24)
	for opt in options:
		var btn: Button = Button.new()
		btn.text = str(opt)
		btn.custom_minimum_size = Vector2(120, 48)
		btn.pressed.connect(_on_answer_button_pressed.bind(opt))
		container.add_child(btn)
	answer_buttons_container.add_child(container)

func _create_action_buttons(options: Array) -> void:
	var container: VBoxContainer = VBoxContainer.new()
	container.add_theme_constant_override("separation", 12)
	for opt in options:
		var btn: Button = Button.new()
		btn.text = str(opt)
		btn.custom_minimum_size = Vector2(200, 44)
		btn.pressed.connect(_on_answer_button_pressed.bind(opt))
		container.add_child(btn)
	answer_buttons_container.add_child(container)

func _create_double_binary_buttons(_options: Array) -> void:
	## Заглушка для этапов с двумя вопросами Да/Нет — реализовать при добавлении этапа.
	var container: VBoxContainer = VBoxContainer.new()
	var lbl: Label = Label.new()
	lbl.text = "Двойной вопрос (заглушка)"
	container.add_child(lbl)
	answer_buttons_container.add_child(container)

# ═══════════════════════════════════════════════════════════════════════════
# ОБРАБОТЧИКИ
# ═══════════════════════════════════════════════════════════════════════════

func _on_answer_button_pressed(answer: Variant) -> void:
	answer_selected.emit(answer)
	hide()

func _on_hint_button_pressed() -> void:
	hint_requested.emit()
