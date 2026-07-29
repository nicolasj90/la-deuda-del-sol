class_name BattleTarget extends Resource

enum Scope { ONE, ALL }
enum Side { ENEMIES, ALLIES, BOTH, SELF, EVERYONE }

@export var scope: BattleTarget.Scope = Scope.ONE
@export var side: BattleTarget.Side = Side.ENEMIES
@export var include_dead: bool = false

# --- Check sides ---
static func is_target_side_enemies(side: BattleTarget.Side):
	return side == BattleTarget.Side.ENEMIES

static func is_target_side_allies(side: BattleTarget.Side):
	return side == BattleTarget.Side.ALLIES

static func is_target_side_both(side: BattleTarget.Side):
	return side == BattleTarget.Side.BOTH

static func is_target_side_self(side: BattleTarget.Side):
	return side == BattleTarget.Side.SELF

static func is_target_side_everyone(side: BattleTarget.Side):
	return side == BattleTarget.Side.EVERYONE

# --- Check scopes ---
static func is_target_scope_one(scope: BattleTarget.Scope):
	return scope == BattleTarget.Scope.ONE

static func is_target_scope_all(scope: BattleTarget.Scope):
	return scope == BattleTarget.Scope.ALL

## Returns a human-readable label for an all-scope message (e.g. "all enemies").
static func all_label(side: BattleTarget.Side) -> String:
	match side:
		Side.ENEMIES: return "all enemies"
		Side.ALLIES: return "all allies"
		Side.BOTH, Side.EVERYONE: return "everyone"
		_: return "all targets"
