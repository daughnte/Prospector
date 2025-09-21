extends CharacterBody3D

# Movement and physics
@export var walk_speed = 8
@export var fall_acceleration = 75
var target_velocity = Vector3.ZERO
@export var jump_velocity := 20.0
@export var run_speed = 16
# var attacks = ["attack1", "attack2"]
var run_toggle = false
@onready var state_machine = $Pivot/city_dwellers_1/AnimationTree["parameters/playback"]
@onready var animation_tree = $Pivot/city_dwellers_1/AnimationTree

var is_first_person = true # Set this to true or false to switch view

#region Camera Variables
@export var mouse_sensitivity := 0.003
var yaw := 0.0
var pitch := 0.0

@onready var third_person_camera_pivot = $ThirdPersonCameraPivot
@onready var third_person_camera = $ThirdPersonCameraPivot/ThirdPersonCamera3D

@onready var first_person_camera_pivot = $FirstPersonCameraPivot
@onready var first_person_camera = $FirstPersonCameraPivot/FirstPersonCamera3D

@onready var skeleton = %GeneralSkeleton
@onready var head_bone = skeleton.find_bone("Head")

#endregion

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	# Initialize yaw and pitch from current camera rotation
	if is_first_person:
		yaw = first_person_camera_pivot.rotation.y
		pitch = first_person_camera.rotation.x
	else:
		yaw = third_person_camera_pivot.rotation.y
		pitch = third_person_camera.rotation.x

func _physics_process(delta):
	target_velocity = Vector3.ZERO
	var direction = Vector3.ZERO
	print("Y Velocity:", velocity.y, "Is on floor:", is_on_floor())
	
	#region Movement input relative to camera
	if Input.is_action_pressed("move_forward"):
		if is_first_person:
			direction += first_person_camera_pivot.global_transform.basis.z
		else:
			direction += third_person_camera_pivot.global_transform.basis.z
	if Input.is_action_pressed("move_backward"):
		if is_first_person:
			direction -= first_person_camera_pivot.global_transform.basis.z
		else:
			direction -= third_person_camera_pivot.global_transform.basis.z
	if Input.is_action_pressed("move_left"):
		if is_first_person:
			direction += first_person_camera_pivot.global_transform.basis.x
		else:
			direction += third_person_camera_pivot.global_transform.basis.x
	if Input.is_action_pressed("move_right"):
		if is_first_person:
			direction -= first_person_camera_pivot.global_transform.basis.x
		else:
			direction -= third_person_camera_pivot.global_transform.basis.x
	#endregion
	
	#region Toggle Between First and Third Person
	if is_first_person:
		# Set up first-person camera and model visibility
		first_person_camera_pivot.visible = true
		first_person_camera.current = true
		third_person_camera_pivot.visible = false
		# Hide third-person-only body parts
	else:
		# Set up third-person camera and model visibility
		first_person_camera_pivot.visible = false
		third_person_camera_pivot.visible = true
		third_person_camera.current = true
		# Show third-person-only body parts
	#endregion
	
	#region Normalize and rotate
	if direction != Vector3.ZERO:
		direction = direction.normalized()
		# Rotate character to face movement direction (even in air)
		var movement_yaw = atan2(direction.x, direction.z)
		$Pivot.rotation.y = lerp_angle($Pivot.rotation.y, movement_yaw, delta * 10.0)

		if is_on_floor():
			state_machine.travel("Movement")
	else:
		run_toggle = false
		if is_on_floor():
			state_machine.travel("Idle")

		# Always rotate character to face camera yaw when not moving
		if is_first_person:
			$Pivot.rotation.y = lerp_angle($Pivot.rotation.y, first_person_camera_pivot.rotation.y, delta * 10.0)
		else:
			$Pivot.rotation.y = lerp_angle($Pivot.rotation.y, third_person_camera_pivot.rotation.y, delta * 10.0)
	#endregion
	
	# Apply velocity
	var current_speed = run_speed if run_toggle else walk_speed
	target_velocity.x = direction.x * current_speed
	target_velocity.z = direction.z * current_speed

	
	#region Jump input
	if Input.is_action_just_pressed("jump") and is_on_floor():
		target_velocity.y = jump_velocity
		state_machine.travel("Jump")
		
	if not is_on_floor():
		target_velocity.y -= fall_acceleration * delta
	#endregion

	velocity = target_velocity
	update_animation_parameters()
	move_and_slide()


func _input(event):
	if event.is_action_pressed("esc"):
		if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	if Input.is_action_just_pressed("run"):
		run_toggle = !run_toggle
	
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
	
		# Apply different pitch limits based on view mode
		if is_first_person:
			pitch = clamp(pitch, deg_to_rad(-60), deg_to_rad(60)) # wider range for first-person
			first_person_camera_pivot.rotation.y = yaw
			first_person_camera.rotation.x = pitch
		else:
			pitch = clamp(pitch, deg_to_rad(-30), deg_to_rad(45)) # narrower range for third-person
			third_person_camera_pivot.rotation.y = yaw
			third_person_camera.rotation.x = pitch
			# Apply pitch to head bone
			# Apply pitch to head bone
			var head_pitch = clamp(pitch, deg_to_rad(-20), deg_to_rad(20))
			var rotation_quat = Quaternion(Vector3(1, 0, 0), head_pitch) # rotate around X-axis
			skeleton.set_bone_pose_rotation(head_bone, rotation_quat)
			
	if event.is_action_pressed("switch_view"): # Example input action
		toggle_view()
		
func toggle_view():
	is_first_person = !is_first_person

func update_animation_parameters():
	var speed = velocity.length()
	var is_idle = speed < 0.1
	animation_tree.set("parameters/conditions/idle", is_idle)
	animation_tree.set("parameters/conditions/is_moving", !is_idle)
	animation_tree.set("parameters/conditions/is_jumping", Input.is_action_just_pressed("jump"))

	# Normalize speed to range [0, 2]
	var blend_y = clamp(speed / walk_speed, 0.0, 2.0)

	# If speed exceeds walk_speed, scale linearly to 2
	if speed > walk_speed:
		blend_y = 1.0 + ((speed - walk_speed) / (run_speed - walk_speed))

	# Clamp to ensure exact values at boundaries
	blend_y = clamp(blend_y, 0.0, 2.0)

	# Smoothly interpolate blend position
	var current_blend = animation_tree.get("parameters/Movement/blend_position")
	var target_blend = Vector2(0, blend_y)
	var new_blend = current_blend.lerp(target_blend, 0.2)  # Adjust 0.1 for smoothness
	animation_tree.set("parameters/Movement/blend_position", new_blend)
	
	
