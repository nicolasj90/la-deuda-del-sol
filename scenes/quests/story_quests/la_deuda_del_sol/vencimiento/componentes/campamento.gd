# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
extends EscenaGuionada
## E07 — «El primer campamento»: trigger de campamento para el camino real.
##
## Se instancia en un mapa de ruta (hoy [code]camino_del_diezmo.tscn[/code]) y se
## dispara cuando el jugador entra al claro, ya con la bandera de E06 puesta. Corre
## el diálogo entero de E07 —nace el farol humano de Ferra, la sección «Ferra» de la
## libreta y suena la SEGUNDA CAMPANADA— y al terminar:
## [br]— deja a Ferra confirmada en la party global ([code]GameManager.party[/code]);
## [br]— cura a la party (el descanso del tutorial de campamento);
## [br]— marca la bandera de E07.
##
## El área es de un disparo: con la bandera puesta, volver al claro no repite la
## escena (el campamento como sistema recurrente llega en F2b/E12).

const DIALOGO: String = "res://scenes/quests/story_quests/la_deuda_del_sol/vencimiento/componentes/e07_primer_campamento.dialogue"

## Emitida en cada campanada de la prenda. Acá suena la segunda de la curva del
## § 5b del INDICE (E04 → E07 → E15 → E19 → E27): la primera que Ferra escucha.
signal campanada_sonada(numero: int)

## El área que detecta al jugador.
@export var zona: Area2D

## Campana de la prenda: misma campana de mano grave que la ceremonia de E04
## (placeholder de sonido). La dispara [method campanada] desde el diálogo.
@export var campana: AudioStreamPlayer

var _corriendo: bool = false


func _ready() -> void:
	if zona != null:
		zona.body_entered.connect(_al_entrar, CONNECT_DEFERRED)


func _al_entrar(cuerpo: Node2D) -> void:
	if cuerpo == null or not cuerpo.is_in_group("player"):
		return
	if _corriendo or BanderasDeuda.tiene(BanderasDeuda.E07_CAMPAMENTO):
		return
	if not BanderasDeuda.tiene(BanderasDeuda.E06_BOSS_DECANO):
		# Todavía no es esta noche: el campamento nace después del boss 1.
		return
	await correr()


## Corre E07 entera.
func correr() -> bool:
	if _corriendo:
		return false
	_corriendo = true

	await correr_dialogo(DIALOGO, "e07_campamento")

	# Ferra queda de la casa, con los PV llenos: es su primera noche en la party.
	BanderasDeuda.sumar_ferra()
	# Tutorial de campamento: descanso y curación.
	BanderasDeuda.curar_party()
	BanderasDeuda.marcar(BanderasDeuda.E07_CAMPAMENTO)
	print("[E07] party después del campamento: %s" % ", ".join(BanderasDeuda.nombres_de_party()))

	_corriendo = false
	escena_terminada.emit(true)
	return true


## La prenda suena: SEGUNDA CAMPANADA. La llama el diálogo
## ([code]do campanada()[/code]) en el punto exacto del guion, después de «Te prometo
## que vamos a entender qué sos».
##
## Va por acá y [b]no[/b] como línea de diálogo a propósito: la campanada es sonido
## (campana grave + shake suave), nunca un cartel en pantalla — el guion la escribe
## como acotación, y § 4f.2 pide que jamás se lea como remate.
func campanada() -> int:
	var numero: int = BanderasDeuda.sonar_campanada()
	if campana != null and campana.stream != null:
		campana.play()
	_sacudir_camara()
	print("[%s] CAMPANADA %d (la prenda suena; los bichos se callan)" % [_quien(), numero])
	campanada_sonada.emit(numero)
	return numero


func _sacudir_camara() -> void:
	# En headless no hay cámara: el shake se saltea sin ruido.
	if CameraShake == null:
		return
	var vista: Viewport = get_viewport()
	if vista == null or vista.get_camera_2d() == null:
		return
	CameraShake.shake()
