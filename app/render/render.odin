package render

import "../platform"

when ODIN_OS == .Darwin  do BACKEND :: "metal"
when ODIN_OS == .Linux   do BACKEND :: "opengl"
when ODIN_OS == .Windows do BACKEND :: "dx11"

@(private="file")
BACKEND :: #config(RENDER_BACKEND, "opengl")

i32x2   :: [2]i32
i32x4   :: [4]i32
f32x2   :: [2]f32
f32x4   :: [4]f32
m3x3f32 :: matrix[3,3]f32
m4x4f32 :: matrix[4,4]f32

Vertex :: struct
{
  pos:   f32x2,
  tint:  f32x4,
  color: f32x4,
  uv:    f32x2,
}

Texture :: struct
{
  data:   []byte,
  width:  i32,
  height: i32,
  cell:   i32,
}

Texture_ID :: enum
{
  Sprites,
  // BACKGROUND,
}

Shader :: struct
{
  id: u32,
}

Pass :: struct
{
  shader:      Shader,
  texture:     Texture,
  projection:  m3x3f32,
  camera:      m3x3f32,
  viewport:    i32x4,
  clear_color: f32x4,
}

Renderer :: struct
{
  initialized:  bool,
  window:       ^platform.Window,
  textures:     [Texture_ID]u32,
  vertices:     [40000]Vertex,
  vertex_count: int,
  indices:      [60000]u16,
  index_count:  int,
  pass:         Pass,
  pass_open:    bool,
  uniforms:     struct
  {
    projection: m4x4f32,
    camera:     m4x4f32,
  },
  ubo:          u32,
  ssbo:         u32,
  ibo:          u32,
}

renderer: ^Renderer = &{}

init :: #force_inline proc(window: ^platform.Window)
{
  /**/ when BACKEND == "opengl" do gl_init(window)
  else                          do panic("Invalid render backend selected!")
}

setup_resources :: #force_inline proc(textures: ^[Texture_ID]Texture)
{
  when BACKEND == "opengl" do gl_setup_resources(textures)

  renderer.initialized = true
}

create_shader :: proc(vsrc, fsrc: string) -> Shader
{
  when BACKEND == "opengl" do return gl_create_shader(vsrc, fsrc)
}

begin_pass :: proc(pass: Pass)
{
  if !renderer.initialized do panic("Renderer not initialized!")
  if renderer.pass_open do panic("Render pass is already open!")

  renderer.pass = pass
  renderer.pass_open = true
  
  clear(pass.clear_color)
}

end_pass :: proc()
{
  if !renderer.initialized do panic("Renderer not initialized!")
  if !renderer.pass_open do panic("Render pass is already closed!")

  flush()

  renderer.pass = {}
  renderer.pass_open = false
}

clear :: #force_inline proc(color: f32x4)
{
  when BACKEND == "opengl" do gl_clear(color)
}

flush :: #force_inline proc()
{
  when BACKEND == "opengl" do gl_flush()
}

push_vertex :: proc(vertex: Vertex)
{
  if renderer.vertex_count == len(renderer.vertices)
  {
    flush()
  }

  renderer.vertices[renderer.vertex_count] = Vertex{
    pos = vertex.pos,
    tint = vertex.tint,
    color = vertex.color,
    uv = vertex.uv,
  }

  renderer.vertex_count += 1
}

push_tri :: proc(v1, v2, v3: Vertex)
{
  push_vertex(v1)
  push_vertex(v2)
  push_vertex(v3)
  push_tri_indices()
}

push_quad :: proc(v1, v2, v3, v4: Vertex)
{
  push_vertex(v1)
  push_vertex(v2)
  push_vertex(v3)
  push_vertex(v4)
  push_rect_indices()
}

push_tri_indices :: proc()
{
  @(static)
  layout: [3]u16 = {
    0, 1, 2,
  }

  offset := cast(u16) renderer.vertex_count - 3
  index_count := renderer.index_count + 3
  renderer.index_count += 3

  renderer.indices[index_count - 3] = layout[0] + offset
  renderer.indices[index_count - 2] = layout[1] + offset
  renderer.indices[index_count - 1] = layout[2] + offset
}

push_rect_indices :: proc()
{
  @(static)
  layout: [6]u16 = {
    0, 1, 3,
    1, 2, 3,
  }

  offset := cast(u16) renderer.vertex_count - 4
  index_count := renderer.index_count + 6
  renderer.index_count += 6

  renderer.indices[index_count - 6] = layout[0] + offset
  renderer.indices[index_count - 5] = layout[1] + offset
  renderer.indices[index_count - 4] = layout[2] + offset
  renderer.indices[index_count - 3] = layout[3] + offset
  renderer.indices[index_count - 2] = layout[4] + offset
  renderer.indices[index_count - 1] = layout[5] + offset
}

coords_from_texture :: proc(texture: ^Texture, coords, grid: f32x2) -> (tl, tr, br, bl: f32x2)
{
  cell := cast(f32) texture.cell
  width := cast(f32) texture.width
  height := cast(f32) texture.height

  tl = f32x2{
    (f32(coords.x) * cell) / width, 
    (f32(coords.y) * cell) / height,
  }

  tr = f32x2{
    (f32(coords.x+(grid.x)) * cell) / width, 
    (f32(coords.y) * cell) / height,
  }

  br = f32x2{
    (f32(coords.x+(grid.x)) * cell) / width, 
    (f32(coords.y+(grid.y)) * cell) / height,
  }

  bl = f32x2{
    (f32(coords.x) * cell) / width, 
    (f32(coords.y+(grid.y)) * cell) / height,
  }

  return
}
