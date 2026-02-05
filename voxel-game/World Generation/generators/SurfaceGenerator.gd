class_name SurfaceGenerator
extends Resource

@export var noise_scale: float = 0.02
@export var ground_level: int = 16
@export var stone_depth: int = 8

var noise: FastNoiseLite

func _init() -> void:
	noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN

func generate_chunk(world: World, chunk_coord: Vector2i) -> Array:
	var origin: Vector3i = Vector3i(
		chunk_coord.x * world.chunk_size,
		0,
		chunk_coord.y * world.chunk_size
	)
	
	var voxels: Array = []
	voxels.resize(world.chunk_size)
	
	for x in range(world.chunk_size):
		voxels[x] = []  # Create empty array for this X column
		for z in range(world.chunk_size):
			var stack: Array = []
			stack.resize(world.chunk_height)
			
			var world_x: int = origin.x + x
			var world_z: int = origin.z + z
			var height: int = get_height(world, world_x, world_z)
			
			for y in range(world.chunk_height):
				var world_y: int = origin.y + y
				var block_id: int = world.BLOCK_AIR
				
				if world_y <= height:
					if world_y > height - self.stone_depth and world_y < height:
						block_id = world.BLOCK_STONE
					elif world_y == height:
						block_id = world.BLOCK_GRASS
					else:
						block_id = world.BLOCK_DIRT
				
				stack[y] = block_id
			
			voxels[x].append(stack)  # ← FIXED: Use append() instead of [z]
	
	return voxels

func get_height(world: World, x: int, z: int) -> int:
	noise.seed = world.world_seed
	var nx: float = float(x) * self.noise_scale
	var nz: float = float(z) * self.noise_scale
	var h: float = noise.get_noise_2d(nx, nz)
	var normalized: float = (h + 1.0) * 0.5
	return self.ground_level + int(float(world.chunk_height - self.ground_level) * 0.4 * normalized)
	
