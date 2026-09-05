class_name ExclamationBoxSpawnableObjects
extends Resource

@export_enum("Triple Coins", "Coin", "1-Up", "Star", "Bob-omb")
var object_type: String = "Triple Coins"

func obj_matching_spawning(object_spawnable: ExclamationBoxSpawnableObjects) -> void:
	match object_spawnable.object_type:
		"Triple Coins":
			# Spawn triple coins
			pass

		"Coin":
			# Spawn coin
			pass

		"1-Up":
			# Spawn 1-Up
			pass

		"Star":
			# Spawn star
			pass

		"Bob-omb":
			# Spawn Bob-omb
			pass
