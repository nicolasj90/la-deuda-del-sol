class_name EffectStatusAdd extends SkillEffect

@export var status: BattlerStatus

func apply(target: Battler, _attacker: Battler = null, _engine: BattleEngine = null):
	target.add_status(status)
