# SPDX-FileCopyrightText: The Threadbare Authors
# SPDX-License-Identifier: MPL-2.0
class_name FormulaEffectDamageDeuda extends FormulaEffectDamage
## Fórmula de daño de efecto configurable para La Deuda del Sol.
##
## Daño = base_damage + attack_scale * STAT(atacante) - defense_scale * STAT(defensor),
## más un azar opcional de ±variance. Con los defaults replica la fórmula RPG Maker
## del addon (4*INT - 2*INT), pero deja elegir stats y escalas, lo que cubre skills
## físicas (Ciro/Ferra), drenajes suaves (Salu) y el azar salvaje de Fiel.

@export var base_damage: int = 0
## Azar: se suma randi_range(-variance, +variance) al resultado.
@export var variance: int = 0
## Stat del atacante que escala el daño (clave de [method Stats.get_stat_by_name]).
@export var attack_stat: StringName = &"intelligence"
## Stat del defensor que mitiga el daño.
@export var defense_stat: StringName = &"intelligence"
@export var attack_scale: float = 4.0
@export var defense_scale: float = 2.0


func calculate(param: FormulaEffectDamageParameter) -> int:
	var atk_value: int = param.attacker.stats.get_stat_by_name(attack_stat).get_value()
	var def_value: int = param.defender.stats.get_stat_by_name(defense_stat).get_value()
	var result: int = base_damage + int(attack_scale * atk_value) - int(defense_scale * def_value)
	if variance > 0:
		result += randi_range(-variance, variance)
	return maxi(1, result)
