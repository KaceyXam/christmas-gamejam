package game

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

VIRTUAL_WIDTH :: 1920
VIRTUAL_HEIGHT :: 1080
FLOOR_HEIGHT :: 100

PLAYER_HEIGHT :: 120
PLAYER_WIDTH :: 75
PLAYER_SPEED :: 15
JUMP_HEIGHT :: 10

ITEM_SIZE :: 50

GRAVITY :: 25
ITEM_DROP_SPEED :: 5

MenuState :: enum {
	MainMenu,
	Game,
}

ItemType :: enum {
	Coal,
	Gingerbread = 25,
	CandyCane = 50,
	Present = 100,
}

Item :: struct {
	pos:  rl.Vector2,
	vel:  rl.Vector2,
	type: ItemType,
}

Player :: struct {
	pos:      rl.Vector2,
	vel:      rl.Vector2,
	on_floor: bool,
}

GlobalState :: struct {
	player: Player,
	items:  [dynamic]Item,
	score:  int,
	lives:  int,
	menu:   MenuState,
}

reset_state :: proc() {
	using global
	items = {}
	score = 0
	lives = 3

	player.pos = rl.Vector2 {
		VIRTUAL_WIDTH / 2 - PLAYER_WIDTH / 2,
		VIRTUAL_HEIGHT - FLOOR_HEIGHT - PLAYER_HEIGHT,
	}
	player.vel = rl.Vector2{}
	player.on_floor = true
}

global: GlobalState

spawn_item :: proc() {
	item_pos := rl.Vector2{rand.float32_range(0, VIRTUAL_WIDTH - ITEM_SIZE), -ITEM_SIZE}
	item_type := rand.choice_enum(ItemType)

	append(&global.items, Item{item_pos, 0, item_type})
}

gui_button :: proc(bounds: rl.Rectangle, text: cstring, font_size: i32) -> (res: bool) {
	text_width := rl.MeasureText(text, font_size)

	mouse_pos := rl.GetMousePosition()
	if rl.IsWindowFocused() && rl.CheckCollisionPointRec(mouse_pos, bounds) {
		if rl.IsMouseButtonReleased(.LEFT) {
			res = true
		}
	}

	rl.DrawRectangleRec(bounds, rl.GRAY)
	rl.DrawText(
		text,
		i32(bounds.x) + (i32(bounds.width) - text_width) / 2,
		i32(bounds.y) + (i32(bounds.height) - font_size) / 2,
		font_size,
		rl.WHITE,
	)

	return res
}

update :: proc(delta: f32) {
	using global

	switch menu {
	case .MainMenu:
		if rl.IsKeyPressed(.SPACE) {
			menu = .Game
		}
	case .Game:
		if rl.IsKeyDown(.LEFT) {
			player.vel.x -= PLAYER_SPEED * delta
		}
		if rl.IsKeyDown(.RIGHT) {
			player.vel.x += PLAYER_SPEED * delta
		}
		if rl.IsKeyPressed(.SPACE) && player.on_floor {
			player.vel.y -= JUMP_HEIGHT
			player.on_floor = false
		}

		player.pos += player.vel
		player.vel *= 0.99
		player.vel.y += GRAVITY * delta

		if player.pos.x < -PLAYER_WIDTH {
			player.pos.x = VIRTUAL_WIDTH + PLAYER_WIDTH
		} else if player.pos.x > VIRTUAL_WIDTH + PLAYER_WIDTH {
			player.pos.x = -PLAYER_WIDTH
		}
		if player.pos.y >= VIRTUAL_HEIGHT - FLOOR_HEIGHT - PLAYER_HEIGHT {
			player.pos.y = VIRTUAL_HEIGHT - FLOOR_HEIGHT - PLAYER_HEIGHT
			player.vel.y = 0
			player.on_floor = true
		}

		if rl.IsKeyPressed(.Q) {
			spawn_item()
		}

		for &item, i in global.items {
			item.vel.y += ITEM_DROP_SPEED * delta
			item.pos += item.vel

			if rl.CheckCollisionCircleRec(
				item.pos,
				ITEM_SIZE,
				{player.pos.x, player.pos.y, PLAYER_WIDTH, PLAYER_HEIGHT},
			) {
				if item.type == .Coal {
					lives -= 1
				} else {
					score += int(item.type)
				}

				unordered_remove(&items, i)
			}

			if item.pos.y > VIRTUAL_HEIGHT {
				unordered_remove(&items, i)
			}
		}
	}

}

render :: proc(camera: ^rl.Camera2D) {
	using global

	switch menu {
	case .MainMenu:
		if gui_button({10, 10, 500, 200}, "Play Game", 24) {menu = .Game}

	case .Game:
		rl.BeginMode2D(camera^)
		rl.DrawRectangleV(
			{0, VIRTUAL_HEIGHT - FLOOR_HEIGHT},
			{VIRTUAL_WIDTH, FLOOR_HEIGHT},
			rl.GREEN,
		)
		rl.DrawRectangleV(player.pos, {PLAYER_WIDTH, PLAYER_HEIGHT}, rl.RED)
		for item in global.items {
			color := rl.GREEN
			if item.type == .Coal {
				color = rl.RED
			}
			rl.DrawCircleV(item.pos, ITEM_SIZE, color)
		}
		rl.EndMode2D()

		score_text := fmt.caprintf("Score: %d", global.score)
		lives_text := fmt.caprintf("Lives: %d", global.lives)
		rl.DrawText(score_text, 10, 10, 24, rl.BLACK)
		rl.DrawText(lives_text, 10, 42, 24, rl.BLACK)
	}
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, "Christmas Game")
	defer rl.CloseWindow()

	reset_state()
	global.menu = .MainMenu

	for !rl.WindowShouldClose() {
		delta := rl.GetFrameTime()
		scale := min(
			f32(rl.GetScreenWidth()) / VIRTUAL_WIDTH,
			f32(rl.GetScreenHeight()) / VIRTUAL_HEIGHT,
		)

		update(delta)

		camera := rl.Camera2D{0, 0, 0, scale}

		rl.BeginDrawing()
		rl.ClearBackground(rl.SKYBLUE)

		render(&camera)

		rl.EndDrawing()
	}
}
