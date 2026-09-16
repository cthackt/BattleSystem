extends Node3D

@onready var animations = [$NMESlashAnim]

var enemy_stats = {
	"health": 80,
	"max_health": 80,
	"stamina": 0,
	"max_stamina": 40,
	"mana": 0,
	"max_mana": 0,
	"stamina_regen": 4
}

func regen_stamina(delta):
	enemy_stats["stamina"] = min(enemy_stats["stamina"] + enemy_stats["stamina_regen"] * delta, enemy_stats["max_stamina"])

func take_damage(damage):
	enemy_stats["health"] -= damage

func handle_enemy_action(battle_manager):
	if enemy_stats["stamina"] >= 10:
		var damage = randi_range(5, 12)
		enemy_stats["stamina"] -= 10
		$NMESlashAnim.visible = true
		$NMESlashAnim.play()
		await $NMESlashAnim.animation_finished
		$NMESlashAnim.visible = false
		
		var player_stats = battle_manager.player.player_stats
		if player_stats["guard"] == false:
			pass  # damage applied below, unmodified
		else:
			damage /= 2
			player_stats["stamina"] -= 10
		
		battle_manager.log_action("Enemy attacks for %d damage!" % damage)
		battle_manager.enemy_attack_hit(damage)
