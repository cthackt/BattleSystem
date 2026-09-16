extends Control

@onready var player_health = $TexturePlayerHealthBar
@onready var player_stamina = $TexturePlayerStaminaBar
var normal_stamina_texture = preload("res://staminabarProgress.png")
var recovery_stamina_texture = preload("res://StaminaRecovery.png")

@onready var enemy_health = $VBoxContainer/EnemyStats/EnemyHealthBar
@onready var enemy_stamina = $VBoxContainer/EnemyStats/EnemyStaminaBar

@onready var log_text = $VBoxContainer/BattleLog/MarginContainer/LogText

@onready var target_zone_label = $TargetZoneLabel

var log_entries = []
var max_log_entries = 5

func _ready():
	# This will be called by BattleManager.setup()
	pass

func setup(player_stats, enemy_stats):
	player_health.max_value = player_stats["max_health"]
	player_stamina.max_value = player_stats["max_stamina"]
	#player_mana.max_value = player_stats["max_mana"]
	
	enemy_health.max_value = enemy_stats["max_health"]
	enemy_stamina.max_value = enemy_stats["max_stamina"]

func update_bars(player_stats, enemy_stats):
	# Player bars
	player_health.value = player_stats["health"]
	player_stamina.value = player_stats["stamina"]
	#player_mana.value = player_stats["mana"]
	
	# Enemy bars
	enemy_health.value = enemy_stats["health"]
	enemy_stamina.value = enemy_stats["stamina"]
	
func set_stamina_recovery(is_recovering):
	if is_recovering:
		player_stamina.texture_progress = recovery_stamina_texture
	else:
		player_stamina.texture_progress = normal_stamina_texture

func log_action(text):
	log_entries.append(text)
	if log_entries.size() > max_log_entries:
		log_entries.pop_front()
	
	log_text.text = "\n".join(log_entries)
	
func update_target_zone(zone_name):
	target_zone_label.text = "Targeting: %s" % zone_name
