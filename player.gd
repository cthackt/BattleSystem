extends Node3D

@onready var animations = [$PCSlashAnim, $PlayerGuardAnim]

var player_stats = {
	"health": 100,
	"max_health": 100,
	"stamina": 0,
	"max_stamina": 100,
	"mana": 30,
	"max_mana": 30,
	"stamina_regen": 10,
	"guard": false
}

enum BodyZone {
	TORSO,
	HEAD,
	LEFT_ARM,
	RIGHT_ARM,
	LEFT_LEG,
	RIGHT_LEG
}
var zone_names = {
	BodyZone.TORSO: "Torso",
	BodyZone.HEAD: "Head",
	BodyZone.LEFT_ARM: "Left Arm",
	BodyZone.RIGHT_ARM: "Right Arm",
	BodyZone.LEFT_LEG: "Left Leg",
	BodyZone.RIGHT_LEG: "Right Leg"
}
var current_zone = BodyZone.TORSO
var torso_radius_threshold = 0.4
var body_part_nodes = {}
var normal_color = Color(1, 0, 0)
var highlight_color = Color(1, 1, 0)

# Combo tracking
var combo_count = 0
var combo_window = 0.6
var combo_timer = 0.0
var in_recovery = false
var recovery_threshold = 0.5


func setup_targeting(enemy_node):
	body_part_nodes = {
		BodyZone.HEAD: enemy_node.get_node("Head"),
		BodyZone.TORSO: enemy_node.get_node("Torso"),
		BodyZone.LEFT_ARM: enemy_node.get_node("LeftArm"),
		BodyZone.RIGHT_ARM: enemy_node.get_node("RightArm"),
		BodyZone.LEFT_LEG: enemy_node.get_node("LeftLeg"),
		BodyZone.RIGHT_LEG: enemy_node.get_node("RightLeg")
	}

func regen_stamina(delta):
	player_stats["stamina"] = min(player_stats["stamina"] + player_stats["stamina_regen"] * delta, player_stats["max_stamina"])

func take_damage(damage):
	player_stats["health"] -= damage

func handle_player_input(delta, battle_manager):
	# Combo window countdown
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0
	
	# Basic attack
	if Input.is_action_just_pressed("Attack") and player_stats["guard"] == false:
		if player_stats["stamina"] >= 10:
			await player_attack(battle_manager)
	
	if Input.is_action_pressed("Guard"):
		player_stats["guard"] = true
		player_guard()
	else:
		player_stats["guard"] = false
		$PlayerGuardAnim.visible = false
		player_stats["stamina_regen"] = 10
	
	if Input.is_action_pressed("AimRight"):
		if Input.is_action_just_pressed("Dodge"):
			battle_manager.rotate_scene_right(PI / 2)
	if Input.is_action_pressed("AimLeft"):
		if Input.is_action_just_pressed("Dodge"):
			battle_manager.rotate_scene_left(PI / 2)
	
	update_targeting(battle_manager)


func player_attack(battle_manager):
	combo_count += 1
	combo_timer = combo_window
	
	var is_finisher = combo_count >= 3
	
	if not is_finisher:
		var damage = randi_range(8, 15)
		player_stats["stamina"] -= 15
		$PCSlashAnim.visible = true
		$PCSlashAnim.play()
		await $PCSlashAnim.animation_finished
		$PCSlashAnim.visible = false
		battle_manager.log_action("Player hits for %d damage! (Combo x%d)" % [damage, combo_count])
		battle_manager.player_attack_hit(damage, false)
	else:
		var damage = randi_range(25, 35)
		player_stats["stamina"] = 0
		$PCSlashAnim.visible = true
		$PCSlashAnim.play()
		await $PCSlashAnim.animation_finished
		$PCSlashAnim.visible = false
		battle_manager.log_action("FINISHER! %d damage!" % damage)
		
		combo_count = 0
		combo_timer = 0
		in_recovery = true
		battle_manager.player_attack_hit(damage, true)

func player_guard():
	$PlayerGuardAnim.visible = true
	player_stats["stamina_regen"] = 5

func check_recovery(battle_manager):
	if in_recovery:
		if player_stats["stamina"] >= player_stats["max_stamina"] * recovery_threshold:
			in_recovery = false
			battle_manager.player_recovered()

func update_targeting(battle_manager):
	var stick_input = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	
	var magnitude = stick_input.length()
	
	if magnitude < torso_radius_threshold:
		current_zone = BodyZone.TORSO
		update_highlight()
		battle_manager.ui.update_target_zone(zone_names[current_zone])
		return
	
	var angle = rad_to_deg(atan2(-stick_input.y, stick_input.x))
	angle = 90 - angle
	if angle < 0:
		angle += 360
	
	if angle >= 324 or angle < 36:
		current_zone = BodyZone.HEAD
	elif angle < 108:
		current_zone = BodyZone.LEFT_ARM
	elif angle < 180:
		current_zone = BodyZone.LEFT_LEG
	elif angle < 252:
		current_zone = BodyZone.RIGHT_LEG
	else:
		current_zone = BodyZone.RIGHT_ARM
	
	update_highlight()
	battle_manager.ui.update_target_zone(zone_names[current_zone])

func update_highlight():
	for zone in body_part_nodes:
		var mesh = body_part_nodes[zone]
		var mat = mesh.get_surface_override_material(0)
		if zone == current_zone:
			mat.albedo_color = highlight_color
		else:
			mat.albedo_color = normal_color
