#+feature dynamic-literals
package app

import "core:image/qoi"
import "render"

Resources :: struct
{
  textures: [render.Texture_ID]render.Texture,
  shaders:  [Shader_Name]render.Shader,
  sprites:  [Sprite_Name]Sprite,
}

Shader_Name :: enum
{
  Sprite,
}

Sprite_Name :: enum
{
  Missing,
  Rect,
  Circle,
  Cloud,
}

res: Resources

init_resources :: proc()
{
  // - Shaders ---
  {
    res.shaders[.Sprite] = render.create_shader(#load("../res/shaders/sprite.vert.glsl"),
                                                #load("../res/shaders/sprite.frag.glsl"))
  }

  // - Textures ---
  {
    img: ^qoi.Image
    err: qoi.Error

    img, err = qoi.load_from_bytes(#load("../res/textures/sprites.qoi"))
    res.textures[.Sprites] = render.Texture{
      data = img.pixels.buf[:],
      width = cast(i32) img.width,
      height = cast(i32) img.height,
      cell = 16,
    }

    // img, err = qoi.load_from_bytes(#load("../res/textures/background.qoi"))
    // res.textures[.BACKGROUND] = render.Texture{
    //   data = img.pixels.buf[:],
    //   width = cast(i32) img.width,
    //   height = cast(i32) img.height,
    // }
  }

  // - Sprites ---
  {
    res.sprites = #partial [Sprite_Name]Sprite{
      .Missing = {coords={0, 0}, grid={1, 1}, pivot={0, 0}},
      .Rect    = {coords={1, 0}, grid={1, 1}, pivot={0, 0}},
    }

    for &sprite in res.sprites
    {
      sprite.texture = .Sprites
      sprite.pivot /= array_cast(sprite.grid, f32) * 16
    }
  }
}
