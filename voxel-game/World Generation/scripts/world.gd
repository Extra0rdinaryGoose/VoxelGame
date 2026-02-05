class_name World
extends Node3D

@export var chunk_size: int = 16
@export var chunk_height: int = 64
@export var voxel_size: float = 1.0
@export var world_seed: int = 12345
@export var chunks_radius: int = 1

@export var surface_generator: SurfaceGenerator
var chunks: Dictionary = {}
var noise: FastNoiseLite

const BLOCK_AIR: int = 0
const BLOCK_STONE: int = 1
const BLOCK_DIRT: int = 2
const BLOCK_GRASS: int = 3

func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.02
	
	#if surface_generator == null:
		#printerr("SurfaceGenerator not assigned!")
		#return
	
	generate_initial_chunks()

func generate_initial_chunks() -> void:
	for cx in range(-chunks_radius, chunks_radius + 1):
		for cz in range(-chunks_radius, chunks_radius + 1):
			var coord: Vector2i = Vector2i(cx, cz)
			generate_chunk(coord)

func generate_chunk(chunk_coord: Vector2i) -> void:
	if chunks.has(chunk_coord):
		return
	
	#var voxels: Array = surface_generator.generate_chunk(self, chunk_coord)
	#set_chunk_data(chunk_coord, voxels)
	#spawn_chunk(chunk_coord)

func set_chunk_data(chunk_coord: Vector2i, voxel_data: Array) -> void:
	chunks[chunk_coord] = voxel_data

func get_chunk_data(chunk_coord: Vector2i) -> Array:
	if chunks.has(chunk_coord):
		return chunks[chunk_coord]
	return []

func get_block(world_pos: Vector3i) -> int:
	var cx: int = int(floor(float(world_pos.x) / float(chunk_size)))
	var cz: int = int(floor(float(world_pos.z) / float(chunk_size)))
	var lx: int = world_pos.x - cx * chunk_size
	var ly: int = world_pos.y
	var lz: int = world_pos.z - cz * chunk_size
	
	var coord: Vector2i = Vector2i(cx, cz)
	if not chunks.has(coord):
		return BLOCK_AIR
	
	var voxels: Array = chunks[coord]
	if lx < 0 or lx >= chunk_size or ly < 0 or ly >= chunk_height or lz < 0 or lz >= chunk_size:
		return BLOCK_AIR
	
	return voxels[lx][lz][ly]

func spawn_chunk(chunk_coord: Vector2i) -> void:
	# Chunk.tscn will be created next
	push_error("Chunk.tscn not created yet - skipping spawn")
