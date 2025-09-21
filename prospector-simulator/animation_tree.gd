extends AnimationTree


@onready var player = get_owner()
@onready var animation_tree: AnimationTree




animation_tree.set("parameters/idle/blend_position", player.velocity.normalized())
