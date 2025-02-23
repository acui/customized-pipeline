@tool
extends CompositorEffect
class_name CustomizedPipeline

var rd: RenderingDevice
var pipeline: RID
var shader: RID
var vertex_position_buffer: RID
var vertex_color_buffer: RID
var vertex_array: RID
var clear_colors: Array[Color]
var image_texture: RID
var depth_texture: RID
var screen_buffer: RID

func _initialize_rendering():
	rd = RenderingServer.get_rendering_device()
	if !rd:
		return
	# Loads a shader file and compiles it to SPIR-V format, then creates a shader resource from the compiled SPIR-V.
	var shader_file: RDShaderFile = load("res://shaders/triangle.glsl")
	var shader_spirv: RDShaderSPIRV = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)


	# Creates a new vertex attribute for position data.
	var vertex_attribute_position = RDVertexAttribute.new()
	# The format is set to 32-bit float with 2 components (x, y).
	vertex_attribute_position.format = RenderingDevice.DATA_FORMAT_R32G32_SFLOAT
	# The attribute is set to be used per vertex.
	vertex_attribute_position.frequency = RenderingDevice.VERTEX_FREQUENCY_VERTEX
	# The location of the attribute in the shader is set to 0.
	vertex_attribute_position.location = 0
	# The offset within the data is set to 0 bytes.
	vertex_attribute_position.offset = 0
	# The stride (size of each vertex attribute) is set to 8 bytes (4 bytes per component * 2 components).
	vertex_attribute_position.stride = 4*2
	
	# Creates a new vertex attribute for color data.
	var vertex_attribute_color = RDVertexAttribute.new()
	# The color data is stored in a 32-bit float format with 3 components (R, G, B).
	vertex_attribute_color.format = RenderingDevice.DATA_FORMAT_R32G32B32_SFLOAT
	# The attribute is set to be used per vertex.
	vertex_attribute_color.frequency = RenderingDevice.VERTEX_FREQUENCY_VERTEX
	# The location of the attribute in the shader is set to 1.
	vertex_attribute_color.location = 1
	# The offset within the data is set to 0 bytes.
	vertex_attribute_color.offset = 0
	# The stride (size of each vertex attribute) is set to 12 bytes (4 bytes per component * 3 components).
	vertex_attribute_color.stride = 4*3
	
	# This format will be used to define the structure of vertex data in a rendering pipeline.
	var vertex_format = rd.vertex_format_create([vertex_attribute_position, vertex_attribute_color])
	
	# Create a vertex buffer for positions
	var vertices_position_packed = PackedFloat32Array([
		0.0, -0.5,
		0.5, 0.5,
		-0.5, 0.5,
	]).to_byte_array()
	vertex_position_buffer = rd.vertex_buffer_create(vertices_position_packed.size(), vertices_position_packed, false)
	
	# Create a vertex buffer for colors
	var vertices_color_packed = PackedFloat32Array([
		1.0, 0.0, 0.0,
		0.0, 1.0, 0.0,
		0.0, 0.0, 1.0,
	]).to_byte_array()
	var vertices_color_buffer = rd.vertex_buffer_create(vertices_color_packed.size(), vertices_color_packed)
	
	# Create a vertex array object (VAO) that encapsulates the vertex buffers and their attributes.
	vertex_array = rd.vertex_array_create(3, vertex_format, [vertex_position_buffer, vertices_color_buffer])
	
	# Initializes a new rasterization state for the rendering pipeline.
	var rasterization_state = RDPipelineRasterizationState.new()
	# The polygon mode is set to fill, meaning polygons will be filled with color.
	rasterization_state.wireframe = false
	# The cull mode is set to disabled, meaning no polygons will be culled.
	rasterization_state.cull_mode = RenderingDevice.POLYGON_CULL_DISABLED
	# Depth clamping is disabled, meaning depth values will not be clamped.
	rasterization_state.enable_depth_clamp = false
	# Line width is set to 1.0.
	rasterization_state.line_width = 1.0;
	# The front face of polygons is set to be clockwise.
	rasterization_state.front_face = RenderingDevice.POLYGON_FRONT_FACE_CLOCKWISE
	# Depth bias is disabled, meaning no depth bias will be applied.
	rasterization_state.depth_bias_enabled = false
	
	# Initializes a new multisample state for the rendering pipeline.
	var multisample_state = RDPipelineMultisampleState.new()
	# Multisampling is disabled
	multisample_state.enable_sample_shading = false
	multisample_state.sample_count = RenderingDevice.TEXTURE_SAMPLES_1
	multisample_state.min_sample_shading = 1.0;
	
	# Initializes a depth-stencil state for the rendering pipeline.
	# The depth test is disabled.
	var stencil_state = RDPipelineDepthStencilState.new()
	stencil_state.enable_depth_test = false
	
	# Initializes a color blend state for the rendering pipeline.
	var color_blend_state = RDPipelineColorBlendState.new()
	# Initializes a color blend state attachment for first and only color attachment.
	# The resulting color is the new color.
	var color_attachment = RDPipelineColorBlendStateAttachment.new()
	color_attachment.enable_blend = true
	color_attachment.write_a = true
	color_attachment.write_b = true
	color_attachment.write_g = true
	color_attachment.write_r = true
	color_attachment.alpha_blend_op = RenderingDevice.BLEND_OP_ADD
	color_attachment.color_blend_op = RenderingDevice.BLEND_OP_ADD
	color_attachment.src_color_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	color_attachment.dst_color_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
	color_attachment.src_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ONE
	color_attachment.dst_alpha_blend_factor = RenderingDevice.BLEND_FACTOR_ZERO
	color_blend_state.attachments.push_back(color_attachment)
	color_blend_state.enable_logic_op = false
	color_blend_state.logic_op = RenderingDevice.LOGIC_OP_COPY
	
	# Get the screen framebuffer format for output.
	var fb_format = rd.screen_get_framebuffer_format()

	# Create the render pipeline with the above states.
	pipeline = rd.render_pipeline_create(
		shader, fb_format, vertex_format, rd.RENDER_PRIMITIVE_TRIANGLES,
		rasterization_state, multisample_state, stencil_state, color_blend_state, 
		0, 0, []
	)
	clear_colors = [Color(0.2, 0.2, 0.2, 1.0)]
	
func _init():
	effect_callback_type = EFFECT_CALLBACK_TYPE_POST_TRANSPARENT
	RenderingServer.call_on_render_thread(_initialize_rendering)
	
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_PREDELETE:
			if shader.is_valid():
				rd.free_rid(shader)
			if vertex_array.is_valid():
				rd.free_rid(vertex_array)
			if vertex_position_buffer.is_valid():
				rd.free_rid(vertex_position_buffer)
			if vertex_color_buffer.is_valid():
				rd.free_rid(vertex_color_buffer)
			if rd.framebuffer_is_valid(screen_buffer):
				rd.free_rid(screen_buffer)
			
func _render_callback(callback_type: int, render_data: RenderData) -> void:
	if rd and callback_type == EFFECT_CALLBACK_TYPE_POST_TRANSPARENT:
		var render_scene_buffers : RenderSceneBuffersRD = render_data.get_render_scene_buffers()

		if render_scene_buffers:
			var size = render_scene_buffers.get_internal_size()
			if size.x == 0 and size.y == 0:
				return
			var new_image_texture = render_scene_buffers.get_color_texture()
			var new_depth_texture = render_scene_buffers.get_depth_texture()
			if new_image_texture != image_texture or new_depth_texture != depth_texture:
				image_texture = new_image_texture
				depth_texture = new_depth_texture
				if rd.framebuffer_is_valid(screen_buffer):
					rd.free_rid(screen_buffer)
				# Creates a framebuffer object (FBO) that encapsulates the color and depth textures.
				# The FBO is used as the target for rendering operations
				screen_buffer = rd.framebuffer_create([image_texture, depth_texture])

			rd.draw_command_begin_label("Draw a triangle", Color(1.0, 1.0, 1.0, 1.0))

			var draw_list = rd.draw_list_begin(screen_buffer, RenderingDevice.DRAW_CLEAR_COLOR_0, clear_colors)
			rd.draw_list_bind_render_pipeline(draw_list, pipeline)
			rd.draw_list_bind_vertex_array(draw_list, vertex_array)
			rd.draw_list_draw(draw_list, false, 1, 0)
			rd.draw_list_end()

			rd.draw_command_end_label()
