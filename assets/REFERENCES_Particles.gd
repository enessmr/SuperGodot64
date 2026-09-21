extends Node3D

@export var sprite: AnimatedSprite3D

# references for particles
# NOTE: Pixel Size is being used for scale, so it can have same scale compared to others. Scale the sprite/pixel size down if you want to scale it.
# Explosion: 17fps. Pixel size reccomended is 0.002 m.
# Billboard reccomended.
# Flame: 28 FPS. Pixel size same.
# Billboard reccomended
# Impact Smoke: 5 fps. On frame 2 (or 3 if we count from 1), make pixel size 0.0005. Again, billboard reccomended.
# Sparkle: 13 fps. Billboard reccomended. 0.002 m pixel size.
# Sparkle Anim: 10 fps. Billboard reccomended. 0.005 m pixel size.
# Stomp Smoke: 12.5 fps. Billboard reccomended. 0.002 m pixel size.
# Walk Smoke: 13fps. Billboard reccomended. 0.002 m pixel size.
# Water Bubble: 15fps. Y-Billboard reccomended. Same pixel size.
# Water Wave:  8.5fps. 0.03m pixel size.
# Yoshi Egg: 20fps. Y-Billboard reccomended. 0.002m pixel size.

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
