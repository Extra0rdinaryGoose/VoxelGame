class_name WorldGenerator
extends Node3D

@export var chunk_size: int = 16
@export var chunk_height: int = 32
@export var voxel_size: float = 1.0
@export var world_seed: int = 12345
@export var noise_scale: float = 0.1
@export var ground_level: int = 8
@export var chunks_radius: int = 1 # 1 = 3x3, 2 = 5x5

var noise: FastNoiseLite

func _ready() -> void:
	noise = FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = noise_scale
	generate_initial_chunks()


func generate_initial_chunks() -> void:
	for cx in range(-chunks_radius, chunks_radius + 1):
		for cz in range(-chunks_radius, chunks_radius + 1):
			var coord: Vector2i = Vector2i(cx, cz)
			generate_chunk(coord)


func get_height(x: int, z: int) -> int:
	var nx: float = float(x) * noise_scale
	var nz: float = float(z) * noise_scale
	var h: float = noise.get_noise_2d(nx, nz)
	var normalized: float = (h + 1.0) * 0.5
	var max_height: int = ground_level + int(float(chunk_height - ground_level) * normalized)
	return max_height


func generate_voxel_data(chunk_origin: Vector3i) -> Array:
	var voxels: Array = []
	voxels.resize(chunk_size)
	for x in range(chunk_size):
		var column: Array = []
		column.resize(chunk_size)
		for z in range(chunk_size):
			var stack: Array = []
			stack.resize(chunk_height)
			var world_x: int = chunk_origin.x + x
			var world_z: int = chunk_origin.z + z
			var height_at: int = get_height(world_x, world_z)
			for y in range(chunk_height):
				var world_y: int = chunk_origin.y + y
				var solid: bool = world_y <= height_at
				stack[y] = solid
			column[z] = stack
		voxels[x] = column
	return voxels


func generate_chunk(chunk_coord: Vector2i) -> void:
	var origin: Vector3i = Vector3i(
		chunk_coord.x * chunk_size,
		0,
		chunk_coord.y * chunk_size
	)
	
	var voxel_data: Array = generate_voxel_data(origin)
	var arrays: Array = build_mesh_arrays(voxel_data, origin)
	if arrays.is_empty():
		return
		
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var terrain_material: Material = load("res://World Generation/materials/VoxelTerrainMaterial.tres")
	
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.name = "Chunk_%d_%d" % [chunk_coord.x, chunk_coord.y]
	mesh_instance.material_override = terrain_material
	add_child(mesh_instance)
	
	var shape: Shape3D = mesh.create_trimesh_shape()
	var collider: StaticBody3D = StaticBody3D.new()
	var col_shape: CollisionShape3D = CollisionShape3D.new()
	col_shape.shape = shape
	collider.add_child(col_shape)
	add_child(collider)


func build_mesh_arrays(voxels: Array, origin: Vector3i) -> Array:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var index_offset: int = 0
	var directions: Array = [
		Vector3i(1, 0, 0),
		Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0),
		Vector3i(0, -1, 0),
		Vector3i(0, 0, 1),
		Vector3i(0, 0, -1)
	]

	var face_normals: Array = [
		Vector3(1, 0, 0),
		Vector3(-1, 0, 0),
		Vector3(0, 1, 0),
		Vector3(0, -1, 0),
		Vector3(0, 0, 1),
		Vector3(0, 0, -1)
	]

	var face_vertices: Array = [
		[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
		[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
		[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
		[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
		[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]
	]

	var face_uvs: Array = [
		Vector2(0, 0),
		Vector2(1, 0),
		Vector2(1, 1),
		Vector2(0, 1)
	]

	for x in range(chunk_size):
		for z in range(chunk_size):
			var column: Array = voxels[x]
			for y in range(chunk_height):
				var solid: bool = column[z][y]
				if not solid:
					continue

				var voxel_world_pos: Vector3 = Vector3(
					origin.x + x,
					origin.y + y,
					origin.z + z
				) * voxel_size

				for i in range(6):
					var dir: Vector3i = directions[i]
					var nx: int = x + dir.x
					var ny: int = y + dir.y
					var nz: int = z + dir.z
					var neighbor_solid: bool = false

					if nx >= 0 and nx < chunk_size and ny >= 0 and ny < chunk_height and nz >= 0 and nz < chunk_size:
						neighbor_solid = voxels[nx][nz][ny]

					if neighbor_solid:
						continue

					var base_index: int = vertices.size()
					var fv: Array = face_vertices[i]
					var normal: Vector3 = face_normals[i]

					for v in range(4):
						var pos: Vector3 = voxel_world_pos + fv[v] * voxel_size
						vertices.append(pos)
						normals.append(normal)
						uvs.append(face_uvs[v])

					indices.append(base_index + 0)
					indices.append(base_index + 1)
					indices.append(base_index + 2)
					indices.append(base_index + 0)
					indices.append(base_index + 2)
					indices.append(base_index + 3)

	if vertices.is_empty():
		return []

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
