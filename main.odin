package game

import rl "vendor:raylib"

VIRTUAL_WIDTH :: 1280
VIRTUAL_HEIGHT :: 720

WORLD_WIDTH :: VIRTUAL_WIDTH * 3
WORLD_WIDTH_HALF :: WORLD_WIDTH / 2
FLOOR_HEIGHT :: 100

PLAYER_HEIGHT :: 50
PLAYER_WIDTH :: 50
PLAYER_SPEED :: 10
JUMP_HEIGHT :: 10

GRAVITY :: 25

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT, .WINDOW_RESIZABLE})
	rl.InitWindow(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, "Christmas Game")
	defer rl.CloseWindow()

	player_pos := rl.Vector2{0, VIRTUAL_HEIGHT - FLOOR_HEIGHT - PLAYER_HEIGHT}
	player_vel := rl.Vector2{}
	player_on_floor := true

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		scale := min(
			f32(rl.GetScreenWidth()) / VIRTUAL_WIDTH,
			f32(rl.GetScreenHeight()) / VIRTUAL_HEIGHT,
		)

		if rl.IsKeyDown(.LEFT) {
			player_vel.x -= PLAYER_SPEED * delta
		}
		if rl.IsKeyDown(.RIGHT) {
			player_vel.x += PLAYER_SPEED * delta
		}
		if rl.IsKeyPressed(.SPACE) && player_on_floor {
			player_vel.y -= JUMP_HEIGHT
			player_on_floor = false
		}

		player_pos += player_vel
		player_vel *= 0.98
		player_vel.y += GRAVITY * delta

		if player_pos.x < -WORLD_WIDTH_HALF {
			player_pos.x = -WORLD_WIDTH_HALF
			player_vel.x = 0
		} else if player_pos.x > WORLD_WIDTH_HALF + PLAYER_WIDTH {
			player_pos.x = WORLD_WIDTH_HALF + PLAYER_WIDTH
			player_vel.x = 0
		}

		if player_pos.y >= VIRTUAL_HEIGHT - FLOOR_HEIGHT - PLAYER_HEIGHT {
			player_pos.y = VIRTUAL_HEIGHT - FLOOR_HEIGHT - PLAYER_HEIGHT
			player_vel.y = 0
			player_on_floor = true
		}

		camera_pos := player_pos
		if camera_pos.x < -WORLD_WIDTH_HALF + VIRTUAL_WIDTH / 2 + PLAYER_WIDTH / 2 {
			camera_pos.x = -WORLD_WIDTH_HALF + VIRTUAL_WIDTH / 2 + PLAYER_WIDTH / 2
		} else if camera_pos.x > WORLD_WIDTH_HALF - VIRTUAL_WIDTH / 2 - PLAYER_WIDTH / 2 {
			camera_pos.x = WORLD_WIDTH_HALF - VIRTUAL_WIDTH / 2 - PLAYER_WIDTH / 2
		}
		camera_pos.y = 0

		camera := rl.Camera2D{{VIRTUAL_WIDTH / 2 - PLAYER_WIDTH / 2, 0}, camera_pos, 0, scale}

		rl.BeginDrawing()
		rl.ClearBackground(rl.SKYBLUE)

		rl.BeginMode2D(camera)

		rl.DrawRectangleV({10, 40}, {500, 500}, rl.BLUE)
		rl.DrawRectangleV({-WORLD_WIDTH / 2, VIRTUAL_HEIGHT - 100}, {WORLD_WIDTH, 100}, rl.GREEN)
		rl.DrawRectangleV(player_pos, {50, 50}, rl.RED)

		rl.EndMode2D()

		rl.EndDrawing()
	}
}
