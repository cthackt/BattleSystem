extends Node3D

@onready var player = $OrbitPivot/Player
@onready var enemy = $Enemy
@onready var ui = $CanvasLayer/UI
@onready var orbit_pivot = $OrbitPivot

var battle_active = true

func _ready():
	player.setup_targeting(enemy)
	ui.setup(player.player_stats, enemy.enemy_stats)
	update_ui()

func _process(delta):
	if not battle_active:
		return
	
	player.regen_stamina(delta)
	enemy.regen_stamina(delta)
	
	player.check_recovery(self)
	
	update_ui()
	
	enemy.handle_enemy_action(self)
	
	if not player.in_recovery:
		player.handle_player_input(delta, self)


# --- Called by Player ---

func player_attack_hit(damage, is_finisher):
	enemy.take_damage(damage)
	
	if is_finisher:
		ui.set_stamina_recovery(true)
	
	if enemy.enemy_stats["health"] <= 0:
		end_battle("Player wins!")

func player_recovered():
	ui.set_stamina_recovery(false)

func rotate_scene_right(angle):
	orbit_pivot.rotate_y(-angle)

func rotate_scene_left(angle):
	orbit_pivot.rotate_y(angle)

# --- Called by Enemy ---

func enemy_attack_hit(damage):
	player.take_damage(damage)
	
	if player.player_stats["health"] <= 0:
		end_battle("Player defeated!")


func end_battle(result):
	battle_active = false
	ui.log_action(result)

func update_ui():
	ui.update_bars(player.player_stats, enemy.enemy_stats)

func log_action(text):
	ui.log_action(text)
