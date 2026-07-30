class_name BattleInputHandler extends Node

signal action_pressed
signal cancel_pressed
## LA DEUDA PATCH: click izquierdo del mouse (solo lo consume el arranque de
## batalla; ver abajo).
signal click_pressed

var assignment: InputAssignment

func _init(_assignment: InputAssignment) -> void:
	assignment = _assignment

func _unhandled_input(event: InputEvent) -> void:
	# LA DEUDA PATCH: con party de 5, InputManager solo tiene 4 assignments
	# (0..3) y el handler del 5.o jugador queda sin device; sin este guard,
	# cualquier tecla crasheaba por deref de null. El líder maneja los menús
	# igual, así que el jugador sin device no pierde nada.
	if assignment == null: return

	# LA DEUDA PATCH (bug bloqueante): el filtro original era
	# [code]if event.device != assignment.device_id: return[/code] y comía TODO
	# el teclado. En Godot 4.5+ los eventos de teclado ya no vienen con
	# device 0 sino con [constant InputEvent.DEVICE_ID_KEYBOARD] (16; el mouse
	# usa 17), mientras que [InputManager.setup_hardware] sigue asignando
	# device_id 0 al jugador de teclado. Resultado: en la batalla no respondía
	# NINGUNA tecla — ni "action" en «Enemies appeared!» ni el menú — así que la
	# batalla era imposible de jugar sin joystick.
	#
	# Arreglo: el device_id se compara SOLO para joypads (que es donde
	# distinguir dispositivos importa, para el multijugador local). Para el
	# jugador de teclado basta con descartar los eventos de joypad.
	if assignment.device_type == InputAssignment.DeviceType.KEYBOARD:
		if event is InputEventJoypadButton or event is InputEventJoypadMotion: return
	elif assignment.device_type == InputAssignment.DeviceType.JOYPAD:
		if event is InputEventKey: return
		if event.device != assignment.device_id: return
	else:
		if event.device != assignment.device_id: return


	if event.is_action_pressed("action"):
		action_pressed.emit()

	if event.is_action_pressed("cancel"):
		cancel_pressed.emit()

	# LA DEUDA PATCH: «¡Aparecieron enemigos!» tiene que avanzar también con el
	# mouse (un jugador solo-mouse quedaba trabado al arrancar CADA batalla).
	# Es una señal aparte para que un click no se confunda con "action" en los
	# menús: solo la consume el arranque de batalla (player_manual_controller).
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		click_pressed.emit()
