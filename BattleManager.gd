extends Node3D

@onready var player = $Player
@onready var enemy = $Enemy
@onready var ui = $CanvasLayer/UI
@onready var animations = [$Player/PCSlashAnim, $Enemy/NMESlashAnim, $Player/PlayerGuardAnim]
var body_part_nodes = {}
var normal_color = Color(1, 0, 0)  # red
var highlight_color = Color(1, 1, 0)  # yellow

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


var enemy_stats = {
	"health": 80,
	"max_health": 80,
	"stamina": 0,
	"max_stamina": 40,
	"mana": 0,
	"max_mana": 0,
	"stamina_regen": 4
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

var battle_active = true

# Combo tracking
var combo_count = 0
var combo_window = 0.6  # seconds to press next attack
var combo_timer = 0.0
var in_recovery = false
var recovery_threshold = 0.5  # 50% of max stamina

func _ready():
	body_part_nodes = {
		BodyZone.HEAD: $Enemy/Head,
		BodyZone.TORSO: $Enemy/Torso,
		BodyZone.LEFT_ARM: $Enemy/LeftArm,
		BodyZone.RIGHT_ARM: $Enemy/RightArm,
		BodyZone.LEFT_LEG: $Enemy/LeftLeg,
		BodyZone.RIGHT_LEG: $Enemy/RightLeg
	}
	ui.setup(player_stats, enemy_stats)
	update_ui()
	

func _process(delta):
	if not battle_active:
		print("Battle not active")
		return
	
	# Stamina regeneration
	player_stats["stamina"] = min(player_stats["stamina"] + player_stats["stamina_regen"] * delta, player_stats["max_stamina"])
	enemy_stats["stamina"] = min(enemy_stats["stamina"] + enemy_stats["stamina_regen"] * delta, enemy_stats["max_stamina"])
	
	if in_recovery:
		if player_stats["stamina"] >= player_stats["max_stamina"] * recovery_threshold:
			in_recovery = false
			ui.set_stamina_recovery(false)
	
	update_ui()
	handle_enemy_action()
	
	if not in_recovery:
		handle_player_input(delta)
		update_targeting()

func handle_player_input(delta):
	# Combo window countdown
	if combo_timer > 0:
		combo_timer -= delta
		if combo_timer <= 0:
			combo_count = 0  # Reset combo if window expires
	
	# Basic attack
	if Input.is_action_just_pressed("Attack") && player_stats["guard"] == false:
		if player_stats["stamina"] >= 10:
			player_attack()
	if Input.is_action_pressed("Guard"):
		player_stats["guard"] = true
		player_guard()
	else: 
		player_stats["guard"] = false
		$Player/PlayerGuardAnim.visible = false
		player_stats["stamina_regen"] = 10
	if Input.is_action_pressed("AimRight"):
		if Input.is_action_just_pressed("Dodge"):
			move_right(PI / 2)  # 90 degrees
	if Input.is_action_pressed("AimLeft"):
		if Input.is_action_just_pressed("Dodge"):
			move_left(PI / 2)  # 90 degrees

func player_attack():
	combo_count += 1
	combo_timer = combo_window
	
	if combo_count < 3:
		# Normal hit
		var damage = randi_range(8, 15)
		player_stats["stamina"] -= 15
		$Player/PCSlashAnim.visible = true
		$Player/PCSlashAnim.play()
		await $Player/PCSlashAnim.animation_finished
		$Player/PCSlashAnim.visible = false
		enemy_stats["health"] -= damage
		ui.log_action("Player hits for %d damage! (Combo x%d)" % [damage, combo_count])
	else:
		# Finisher hit
		var damage = randi_range(25, 35)
		player_stats["stamina"] = 0
		$Player/PCSlashAnim.visible = true
		$Player/PCSlashAnim.play()
		await $Player/PCSlashAnim.animation_finished
		$Player/PCSlashAnim.visible = false
		enemy_stats["health"] -= damage
		ui.log_action("FINISHER! %d damage!" % damage)
		
		combo_count = 0
		combo_timer = 0
		in_recovery = true
		ui.set_stamina_recovery(true)
	
	if enemy_stats["health"] <= 0:
		end_battle("Player wins!")
		
func player_guard():
	$Player/PlayerGuardAnim.visible = true
	player_stats["stamina_regen"] = 5
	
func update_targeting():
	var stick_input = Vector2(
		Input.get_joy_axis(0, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(0, JOY_AXIS_LEFT_Y)
	)
	
	var magnitude = stick_input.length()
	
	if magnitude < torso_radius_threshold:
		current_zone = BodyZone.TORSO
		update_highlight()
		ui.update_target_zone(zone_names[current_zone])
		return
	
	# Angle in degrees, 0 = right, 90 = down (Godot Y is inverted for sticks)
	# We want 0 = up (head), going clockwise
	var angle = rad_to_deg(atan2(-stick_input.y, stick_input.x))  # Standard math angle, up = 90
	angle = 90 - angle  # Rotate so "up" = 0
	if angle < 0:
		angle += 360
	
	# 5 wedges of 72 degrees each, head centered on 0
	# Wedge boundaries: head is -36 to 36, then going clockwise every 72
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
	ui.update_target_zone(zone_names[current_zone])


func update_highlight():
	for zone in body_part_nodes:
		var mesh = body_part_nodes[zone]
		var mat = mesh.get_surface_override_material(0)
		if zone == current_zone:
			mat.albedo_color = highlight_color
		else:
			mat.albedo_color = normal_color
	
func move_right(angle):
	var enemy_pos = enemy.global_position
	
	# Rotate player around enemy
	var player_offset = player.global_position - enemy_pos
	player_offset = player_offset.rotated(Vector3.UP, angle)
	player.global_position = enemy_pos + player_offset
	
	# Rotate camera around enemy
	var camera_pos = $Camera3D.global_position
	var camera_offset = camera_pos - enemy_pos
	camera_offset = camera_offset.rotated(Vector3.UP, angle)
	$Camera3D.global_position = enemy_pos + camera_offset
	$Camera3D.look_at(enemy_pos, Vector3.UP)
	
	# Rotate animations around enemy
	for anim in animations:
		var pos_offset = anim.global_position - enemy_pos
		pos_offset = pos_offset.rotated(Vector3.UP, angle)
		anim.global_position = enemy_pos + pos_offset

func move_left(angle):
	var enemy_pos = enemy.global_position
	
	# Rotate player around enemy
	var player_offset = player.global_position - enemy_pos
	player_offset = player_offset.rotated(Vector3.DOWN, angle)
	player.global_position = enemy_pos + player_offset
	
	# Rotate camera around enemy
	var camera_pos = $Camera3D.global_position
	var camera_offset = camera_pos - enemy_pos
	camera_offset = camera_offset.rotated(Vector3.DOWN, angle)
	$Camera3D.global_position = enemy_pos + camera_offset
	$Camera3D.look_at(enemy_pos, Vector3.UP)
	
	# Rotate animations around enemy
	for anim in animations:
		var pos_offset = anim.global_position - enemy_pos
		pos_offset = pos_offset.rotated(Vector3.DOWN, angle)
		anim.global_position = enemy_pos + pos_offset
	
func handle_enemy_action():
	if enemy_stats["stamina"] >= 10:		
		var damage = randi_range(5, 12)
		enemy_stats["stamina"] -= 10
		$Enemy/NMESlashAnim.visible = true
		$Enemy/NMESlashAnim.play()
		await $Enemy/NMESlashAnim.animation_finished
		$Enemy/NMESlashAnim.visible = false
		if player_stats["guard"] == false:
			player_stats["health"] -= damage
		else: 
			damage /= 2
			player_stats["health"] -= damage
			player_stats["stamina"] -= 10
		ui.log_action("Enemy attacks for %d damage!" % damage)
	
	#if player_stats["health"] <= 0:
		#end_battle("Player defeated!")

func end_battle(result):
	battle_active = false
	ui.log_action(result)

func update_ui():
	ui.update_bars(player_stats, enemy_stats)
