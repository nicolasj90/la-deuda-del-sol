class_name EffectStatusCure extends SkillEffect

@export var status: BattlerStatus

func apply(target: Battler, _attacker: Battler = null, _engine: BattleEngine = null):
	target.remove_status(status)
