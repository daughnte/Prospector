extends CharacterBody3D

# IMPORTANT!!
#Go to Project -> Project Settings -> Input Map and set following actions, even if you don't need all of them:
#left, right, forward, backward, run, jump, crouch

@export_category("Character")
@export var sensitivity: float = 0.2
@export var normal_speed: float = 5.0
@export var acceleration: float = 15.0
@export var gravity: float = 30.0
@export_subgroup("Jump")
@export var allow_jump: bool = true
@export var jump_force: float = 10.0
@export_subgroup("Run")
@export var allow_run: bool = true
@export var run_speed: float = 8.0
@export_subgroup("Crouch")
@export var allow_crouch: bool = false
@export var crouch_height: float = 1.0
@export var crouch_speed: float = 3.0
@export_range(1, 50) var smooth_transition: float = 30.0
@export var disable_run_on_chrouch: bool = true
@export var disable_jump_on_crouch: bool = true

@onready var cam = $CollisionShape3D/head/Camera3D
@onready var head = $CollisionShape3D/head

var speed: float
var crouch_toogle = false
var running = false

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	speed = normal_speed

func _physics_process(delta):
	var direction = Vector3(
		Input.get_axis("left", "right"), 0, Input.get_axis("forward", "backward")
	).normalized().rotated(Vector3.UP, rotation.y)

	velocity.x = lerp(velocity.x, direction.x*speed, acceleration*delta)
	velocity.z = lerp(velocity.z, direction.z*speed, acceleration*delta)

	if Input.is_action_pressed("run") and can_run()==true:
		speed = run_speed
	elif crouch_toogle==true:
		speed = crouch_speed
	else:
		speed = normal_speed

	if allow_crouch == true:
		if Input.is_action_just_pressed("crouch"):
			if crouch_toogle==false:
				$crouch_shape.disabled = false
				$CollisionShape3D.disabled = true
				crouch_toogle = true
			else:
				$CollisionShape3D.disabled = false
				$crouch_shape.disabled = true
				crouch_toogle = false
		if crouch_toogle == true:
			head.position.y = lerp(head.position.y, 1-crouch_height, (50-smooth_transition)*delta)
		else:
			head.position.y = lerp(head.position.y, 0.8, (50-smooth_transition)*delta)

	if is_on_floor():
		if Input.is_action_pressed("jump") and can_jump()==true:
			velocity.y = jump_force
	else:
		velocity.y -= gravity*delta

	move_and_slide()


func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode()==Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x*sensitivity))
		cam.rotate_x(deg_to_rad(-event.relative.y*sensitivity))
		cam.rotation_degrees.x = clamp(cam.rotation_degrees.x, -89, 89)

func can_jump() -> bool:
	if allow_jump == true:
		if crouch_toogle==true and disable_jump_on_crouch==true:
			return false
		else:
			return true
	else:
		return false

func can_run() -> bool:
	if allow_run == true:
		if crouch_toogle==true and disable_run_on_chrouch==true:
			return false
		else:
			return true
	else:
		return false
