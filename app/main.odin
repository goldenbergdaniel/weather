package app

import "base:intrinsics"
import "core:fmt"
import "core:time"
import ft "ext:freetype"
import "basic"
import "basic/mem"
import "platform"
import "render"

WORLD_WIDTH  :: 320.0
WORLD_HEIGHT :: 180.0
WORLD_TEXEL  :: 16.0

User :: struct
{
  window:      platform.Window,
  viewport:    f32x4,
  perm_arena:  mem.Arena,
  frame_arena: mem.Arena,
  show_dbgui:  bool,
}

user: User

@(private="file")
app: App

update_start_tick, update_end_tick: time.Tick
render_start_tick, render_end_tick: time.Tick

main :: proc()
{
  _ = mem.arena_init_static(&user.perm_arena)
  _ = mem.arena_init_growing(&user.frame_arena)

  window_desc := platform.Window_Desc{
    title = "WEATHER",
    width = 960,
    height = 540,
    props = {.VSYNC, .RESIZEABLE},
  }

  user.window = platform.create_window(window_desc, &user.perm_arena)
  defer platform.destroy_window(&user.window)

  render.init(&user.window)
  init_resources()
  render.setup_resources(&res.textures)

  app_init(&app)

  elapsed_time: f64
  start_tick := time.tick_now()

  for !user.window.should_close
  {
    platform.pump_events(&user.window)
    
    curr_time := time.duration_seconds(time.tick_since(start_tick))
    frame_time := curr_time - elapsed_time
    elapsed_time = curr_time

    // - Update viewport ---
    {
      window_size := basic.array_cast(platform.window_size(&user.window), f32)
      ratio := window_size.x / window_size.y
      if ratio >= WORLD_WIDTH / WORLD_HEIGHT
      {
        img_width := window_size.x / (ratio * (WORLD_HEIGHT / WORLD_WIDTH))
        user.viewport = {(window_size.x - img_width) / 2, 0, img_width, window_size.y}
      }
      else
      {
        img_height := window_size.y * (ratio / (WORLD_WIDTH / WORLD_HEIGHT))
        user.viewport = {0, (window_size.y - img_height) / 2, window_size.x, img_height}
      } 
    }

    app_update(&app, f32(frame_time))
    // app_render(&app)

    app_gui_update(&app)
    app_gui_render(&app)

    platform.remember_prev_input()
    platform.window_swap(&user.window)
  }
}

f32x2 :: [2]f32
f32x3 :: [3]f32
f32x4 :: [4]f32

Range :: basic.Range

range_overlap :: basic.range_overlap
array_cast    :: basic.array_cast
approx        :: basic.approx
rad_from_deg  :: basic.rad_from_deg
deg_from_rad  :: basic.deg_from_rad

print   :: fmt.print
printf  :: fmt.printf
println :: fmt.println
panicf  :: fmt.panicf
