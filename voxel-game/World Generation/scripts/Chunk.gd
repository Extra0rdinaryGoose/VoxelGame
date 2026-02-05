class_name Chunk
extends Node3D

var chunk_coord: Vector2i
var world: World

var directions: Array[Vector3i] = [
	Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
	Vector3i(0, 1, 0), Vector3i(0, -1, 0),
	Vector3i(0, 0, 1), Vector3i(0, 0, -1)
]

var face_normals: Array[Vector3] = [
	Vector3(1, 0, 0), Vector3(-1, 0, 0),
	Vector3(0, 1, 0), Vector3(0, -1, 0),
	Vector3(0, 0, 1), Vector3(0, 0, -1)
]

var face_vertices: Array[Array] = [
	[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)],
	[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)],
	[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)],
	[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)],
	[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)],
	[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]
]

func setup(coord: Vector2i, world_ref: World) -> void:
	chunk_coord = coord
	world = world_ref
	name = "Chunk_%d_%d" % [coord.x, coord.y]
	build_mesh()

func build_mesh_arrays(voxels: Array, _origin: Vector3i) -> Array:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var colors: PackedColorArray = PackedColorArray()

	var face_uvs: Array[Vector2] = [
		Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)
	]

	# CORRECTED: Vertex winding for Godot's clockwise culling
	# Faces are: Right, Left, Top, Bottom, Front, Back
	var local_face_vertices: Array[Array] = [
		[Vector3(1, 0, 0), Vector3(1, 1, 0), Vector3(1, 1, 1), Vector3(1, 0, 1)], # Right
		[Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(0, 1, 0), Vector3(0, 0, 0)], # Left
		[Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 1, 0), Vector3(0, 1, 0)], # Top
		[Vector3(0, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 1)], # Bottom (Floor)
		[Vector3(0, 0, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 1)], # Front
		[Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(1, 1, 0)]  # Back
	]

	for x in range(world.chunk_size):
		for z in range(world.chunk_size):
			for y in range(world.chunk_height):
				var block_id: int = voxels[x][z][y]
				if block_id == world.BLOCK_AIR:
					continue

				# Check all 6 directions to decide which faces to draw
				for i in range(6):
					var dir: Vector3i = directions[i]
					var neighbor_pos: Vector3i = Vector3i(x, y, z) + dir
					var neighbor_id: int = world.BLOCK_AIR

					# Check local chunk data first for efficiency
					if (neighbor_pos.x >= 0 and neighbor_pos.x < world.chunk_size and 
						neighbor_pos.y >= 0 and neighbor_pos.y < world.chunk_height and 
						neighbor_pos.z >= 0 and neighbor_pos.z < world.chunk_size):
						neighbor_id = voxels[neighbor_pos.x][neighbor_pos.z][neighbor_pos.y]
					else:
						# If neighbor is outside this chunk, check the world map
						var world_neighbor = Vector3i(_origin.x + x, y, _origin.z + z) + dir
						neighbor_id = world.get_block(world_neighbor)

					# Only draw the face if it touches Air (transparency check)
					if neighbor_id != world.BLOCK_AIR:
						continue

					var base_index: int = vertices.size()
					var fv: Array = local_face_vertices[i]
					var normal: Vector3 = face_normals[i]

					# Generate the 4 vertices for this quad
					for v in range(4):
						# Use LOCAL x,y,z so the Chunk node handles the world position
						var pos: Vector3 = Vector3(x, y, z) + fv[v]
						vertices.append(pos)
						normals.append(normal)
						uvs.append(face_uvs[v])

						# Apply basic vertex colors
						match block_id:
							world.BLOCK_GRASS: colors.append(Color(0.2, 0.8, 0.2))
							world.BLOCK_DIRT:  colors.append(Color(0.4, 0.3, 0.1))
							world.BLOCK_STONE: colors.append(Color(0.5, 0.5, 0.5))
							_:                 colors.append(Color.WHITE)

					# Add indices for two triangles forming the quad
					indices.append(base_index + 0)
					indices.append(base_index + 1)
					indices.append(base_index + 2)
					indices.append(base_index + 0)
					indices.append(base_index + 2)
					indices.append(base_index + 3)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays

func build_mesh() -> void:
	print("Chunk ", chunk_coord, " building mesh...")
	var voxels: Array = world.get_chunk_data(chunk_coord)
	print("Voxels size: ", voxels.size())
	if voxels.is_empty():
		print("NO VOXELS - aborting")
		return

	print("Voxels OK, building arrays...")
	var origin: Vector3i = Vector3i(
		chunk_coord.x * world.chunk_size,
		0,
		chunk_coord.y * world.chunk_size
	)

	var arrays: Array = build_mesh_arrays(voxels, origin)
	print("Arrays size: ", arrays.size())
	if arrays.is_empty():
		print("EMPTY ARRAYS - no solid voxels!")
		return

	# VALIDATION
	var vertices = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	var indices = arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
	var normals = arrays[Mesh.ARRAY_NORMAL] as PackedVector3Array
	var uvs = arrays[Mesh.ARRAY_TEX_UV] as PackedVector2Array
	var colors = arrays[Mesh.ARRAY_COLOR] as PackedColorArray

	print("Array validation:")
	print("  vertices: ", vertices.size())
	print("  indices:  ", indices.size())
	print("  normals:  ", normals.size())
	print("  uvs:      ", uvs.size())
	print("  colors:   ", colors.size())

	if vertices.size() != normals.size() or vertices.size() != uvs.size() or vertices.size() != colors.size():
		print("❌ ARRAY LENGTH MISMATCH!")
		return

	print("Creating ArrayMesh...")
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	print("Surface count: ", mesh.get_surface_count())
	if mesh.get_surface_count() > 0:
		print("✅ TERRAIN RENDERING!")

	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	add_child(mesh_instance)

	# Material (fallback if missing)
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.3, 0.6, 0.3)
	material.cull_mode = BaseMaterial3D.CULL_BACK
	material.vertex_color_use_as_albedo = true
	mesh_instance.material_override = material

	# Collision
	var shape = mesh.create_trimesh_shape()
	var collider = StaticBody3D.new()
	var col_shape = CollisionShape3D.new()
	col_shape.shape = shape
	collider.add_child(col_shape)
	add_child(collider)
	print("Chunk ", chunk_coord, " COMPLETE")
