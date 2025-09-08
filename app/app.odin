package app

import "core:os"
import "basic"
import "basic/vector_math"
import "platform"
import "render"
import "ui"

App :: struct
{
  gui_tree: ui.Tree,
  camera: struct
  {
    pos: f32x2,
    scl: f32x2,
    rot: f32,
  },
}

app_init :: proc(app: ^App)
{
  ui.tree_init(&app.gui_tree, 1024, &user.perm_arena)
  // ui.test()
  // os.exit(0)
}

app_update :: proc(app: ^App, dt: f32)
{
  if platform.key_just_pressed(.ESCAPE)
  {
    platform.window_close(&user.window)
  }
  
  if platform.key_just_pressed(.ENTER) && platform.key_pressed(.LEFT_CTRL)
  {
    platform.window_toggle_fullscreen(&user.window)
  }
}

app_render :: proc(app: ^App)
{
  render.begin_pass({
    shader = res.shaders[.Sprite],
    camera = vector_math.xform_3x3f(expand_values(app.camera)),
    projection = vector_math.orthographic_3x3f(0, WORLD_WIDTH, 0, WORLD_HEIGHT),
    viewport = basic.array_cast(user.viewport, i32),
    clear_color = {0.01, 0.01, 0.05, 1},
  })

  draw_sprite({10, 10}, {10, 10})

  render.end_pass()
}

app_gui_update :: proc(app: ^App)
{
  ui.begin_layout(&app.gui_tree)

  window_size := platform.window_size(&user.window)

  if ui.box("A")
  {
    ui.layout_offset({0, 0})
    ui.layout_size_x(.Pixels, window_size.x/2)
    ui.layout_size_y(.Pixels, window_size.y)
    ui.layout_fill_color({1, 0, 0, 1})

    if ui.box("C") {}
    if ui.box("D") {}
  }

  if ui.box("B")
  {
    ui.layout_offset({window_size.x/2, 0})
    ui.layout_size_x(.Pixels, window_size.x/2)
    ui.layout_size_y(.Pixels, window_size.y)
    ui.layout_fill_color({0, 0, 1, 1})

    if ui.box("E") {}
    if ui.box("F") {}
  }

  ui.end_layout()
  println("---")
  ui.tree_print_dfs(&app.gui_tree, .Postorder)
  if true do os.exit(0)
}

app_gui_render :: proc(app: ^App)
{
  window_size := platform.window_size(&user.window)

  render.begin_pass({
    shader = res.shaders[.Sprite],
    camera = vector_math.translation_3x3f({0, 0}),
    projection = vector_math.orthographic_3x3f(0, window_size.x, 0, window_size.y),
    viewport = {0, 0, i32(window_size.x), i32(window_size.y)},
    clear_color = {1, 1, 1, 1},
  })

  for node in app.gui_tree.data[1:app.gui_tree.count]
  {
    draw_sprite(
      pos=node.offset,
      scl={node.size.x.value, node.size.y.value},
      color=vector_math.concat(node.color.rgb, 0),
      tint={1, 1, 1, node.color.a},
      sprite=.Rect,
      mult=1,
    )
  }

  render.end_pass()
}
