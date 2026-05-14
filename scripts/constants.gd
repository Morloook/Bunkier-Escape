extends Node

enum Cell {
	WALL          = 0,
	FLOOR         = 1,
	SLOT          = 2,
	CRATE         = 3,
	CRATE_SLOTTED = 4,
	DOOR_LOCKED   = 5,
	DOOR_OPEN     = 6,
	# Para B — beczka (3,6) + kratka (6,9)
	SLOT_B          = 7,
	CRATE_B         = 8,
	CRATE_B_SLOTTED = 9,
	# Beczka na złej kratce — kratka nie ginie gdy beczka odjedzie
	CRATE_ON_SLOT_B  = 10,  # beczka A stoi na kratce B
	CRATE_B_ON_SLOT  = 11,  # beczka B stoi na kratce A
}

const DIR_VECTORS: Array[Vector2i] = [
	Vector2i( 0, -1),
	Vector2i( 0,  1),
	Vector2i(-1,  0),
	Vector2i( 1,  0),
]
