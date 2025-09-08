#+build linux
#+private
package render

import "core:fmt"
import "core:os"
import gl "ext:opengl"
import vmath "../basic/vector_math"
import "../platform"

@(private)
gl_init :: proc(window: ^platform.Window)
{
  renderer.window = window
  gl.load_up_to(4, 6, platform.gl_set_proc_address)
}

@(private)
gl_setup_resources :: proc(textures: ^[Texture_ID]Texture)
{
  // - Textures ---
  {
    gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)
    gl.Enable(gl.BLEND)
		gl.Enable(gl.MULTISAMPLE)

    gl.CreateTextures(gl.TEXTURE_2D, len(renderer.textures), raw_data(&renderer.textures))

    for tex, id in renderer.textures
    {
      gl.TextureStorage2D(tex, 1, gl.RGBA8, textures[id].width, textures[id].height)
      gl.TextureSubImage2D(texture=tex, 
                           level=0, 
                           xoffset=0, 
                           yoffset=0, 
                           width=textures[id].width, 
                           height=textures[id].height, 
                           format=gl.RGBA, 
                           type=gl.UNSIGNED_BYTE, 
                           pixels=raw_data(textures[id].data))
      gl.TextureParameteri(tex, gl.TEXTURE_MIN_FILTER, gl.NEAREST)
      gl.TextureParameteri(tex, gl.TEXTURE_MAG_FILTER, gl.NEAREST)
      gl.BindTextureUnit(u32(id), tex)
    }
  }

  // - Vertex array object ---
  vao: u32
  gl.GenVertexArrays(1, &vao)
  gl.BindVertexArray(vao)

  // - Uniform buffer ---
  gl.CreateBuffers(1, &renderer.ubo)
  gl.UniformBlockBinding(renderer.pass.shader.id, 0, 0)
  gl.BindBufferBase(gl.UNIFORM_BUFFER, 0, renderer.ubo)
  gl.NamedBufferStorage(renderer.ubo, 
                        size_of(renderer.uniforms), 
                        &renderer.uniforms, 
                        gl.DYNAMIC_STORAGE_BIT)

  // - Shader storage buffer ---
  gl.CreateBuffers(1, &renderer.ssbo)
  gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, renderer.ssbo)
  gl.NamedBufferStorage(renderer.ssbo, 
                        size_of(renderer.vertices),
                        raw_data(&renderer.vertices), 
                        gl.DYNAMIC_STORAGE_BIT)

  // - Index buffer ---
  gl.CreateBuffers(1, &renderer.ibo)
  gl.VertexArrayElementBuffer(vao, renderer.ibo)
  gl.NamedBufferData(renderer.ibo,
                     size_of(renderer.indices),
                     raw_data(&renderer.indices),
                     gl.DYNAMIC_DRAW)
}

@(private)
gl_clear :: proc(color: f32x4)
{
  gl.ClearColor(color.r, color.g, color.b, color.a)
  gl.Clear(gl.COLOR_BUFFER_BIT)
}

@(private)
gl_flush :: proc()
{
  if renderer.vertex_count == 0 do return

  renderer.uniforms.projection = cast(m4x4f32) renderer.pass.projection
  renderer.uniforms.camera = cast(m4x4f32) renderer.pass.camera

  gl.Viewport(expand_values(renderer.pass.viewport))

  gl.NamedBufferSubData(buffer=renderer.ssbo,
                        offset=0,
                        size=renderer.vertex_count * size_of(Vertex),
                        data=&renderer.vertices[0])

  gl.NamedBufferSubData(buffer=renderer.ibo,
                        offset=0,
                        size=renderer.index_count * size_of(u16),
                        data=&renderer.indices[0])
  
  gl.UseProgram(renderer.pass.shader.id)
  // gl.UniformBlockBinding(renderer.pass.shader.id, 0, 0)

  u_tex_loc := gl.GetUniformLocation(renderer.pass.shader.id, "u_tex")
  gl.Uniform1i(u_tex_loc, i32(Texture_ID.Sprites))
  gl.NamedBufferSubData(buffer=renderer.ubo,
                        offset=0,
                        size=size_of(renderer.uniforms),
                        data=&renderer.uniforms)

  gl.DrawElements(gl.TRIANGLES, i32(renderer.index_count), gl.UNSIGNED_SHORT, nil)

  gl.UseProgram(0)

  renderer.vertex_count = 0
  renderer.index_count = 0
}

@(private)
gl_create_shader :: proc(vsrc, fsrc: string) -> Shader
{
  result: Shader

  vsrc := vsrc
  fsrc := fsrc

  verify_shader :: proc(id, type: u32)
  {
    success: i32 = 1
    log: [1000]byte

    if type == gl.COMPILE_STATUS
    {
      gl.GetShaderiv(id, type, &success);
      if success != 1
      {
        length: i32
        gl.GetShaderiv(id, gl.INFO_LOG_LENGTH, &length)
        gl.GetShaderInfoLog(id, length, &length, &log[0])

        fmt.eprintln("[ERROR]: Shader compile error!")
        fmt.eprintln(cast(string) log[:])

        os.exit(1)
      }
    }
    else if type == gl.LINK_STATUS
    {
      gl.ValidateProgram(id);
      gl.GetProgramiv(id, type, &success)
      if success != 1
      {
        length: i32
        gl.GetProgramiv(id, gl.INFO_LOG_LENGTH, &length)
        gl.GetProgramInfoLog(id, length, &length, &log[0])

        fmt.eprintln("[ERROR]: Shader link error!")
        fmt.eprintln(cast(string) log[:length])
        
        os.exit(1)
      }
    }
  }
  
  vs := gl.CreateShader(gl.VERTEX_SHADER)
  defer gl.DeleteShader(vs)
  gl.ShaderSource(vs, 1, cast([^]cstring) &vsrc, nil)
  gl.CompileShader(vs)
  when ODIN_DEBUG do verify_shader(vs, gl.COMPILE_STATUS)
  
  fs := gl.CreateShader(gl.FRAGMENT_SHADER)
  defer gl.DeleteShader(fs)
  gl.ShaderSource(fs, 1, cast([^]cstring) &fsrc, nil)
  gl.CompileShader(fs)
  when ODIN_DEBUG do verify_shader(fs, gl.COMPILE_STATUS)

  result.id = gl.CreateProgram()
  gl.AttachShader(result.id, vs)
  gl.AttachShader(result.id, fs)
  gl.LinkProgram(result.id)
  when ODIN_DEBUG do verify_shader(result.id, gl.LINK_STATUS)

  renderer.pass.shader = result

  // - Uniform buffer ---
  // gl.BindBufferBase(gl.UNIFORM_BUFFER, 0, renderer.ubo)

  // - Storage buffer ---
  // gl.BindBufferBase(gl.SHADER_STORAGE_BUFFER, 1, renderer.ssbo)

  return result
}
