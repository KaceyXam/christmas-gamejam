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

HEART_SIZE :: 50
HEART_PADDING :: 5

GRAVITY :: 25
ITEM_DROP_SPEED :: 5

MenuState :: enum {
	MainMenu,
	Game,
	GameOver,
}

ItemSize :: enum {
	Small  = 25,
	Medium = 50,
	Large  = 75,
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
	size: ItemSize,
}

Player :: struct {
	pos:      rl.Vector2,
	vel:      rl.Vector2,
	on_floor: bool,
}

GlobalState :: struct {
	player:      Player,
	items:       [dynamic]Item,
	spawn_timer: f32,
	score:       int,
	lives:       int,
	menu:        MenuState,
}

reset_state :: proc() {
	using global
	items = {}
	score = 0
	lives = 3

	spawn_timer = 0

	player.pos = rl.Vector2 {
		VIRTUAL_WIDTH / 2 - PLAYER_WIDTH / 2,
		VIRTUAL_HEIGHT - FLOOR_HEIGHT - PLAYER_HEIGHT,
	}
	player.vel = rl.Vector2{}
	player.on_floor = true
}

global: GlobalState

rand_type :: proc() -> ItemType {
	rn := rand.float32()
	if rn < .5 {
		return .Coal
	} else if rn < .75 {
		return .Gingerbread
	} else if rn < .9 {
		return .CandyCane
	} else {
		return .Present
	}
}

spawn_item :: proc() {
	item_pos := rl.Vector2{rand.float32_range(100, VIRTUAL_WIDTH - 100), -100}
	item_type := rand_type()
	item_size := rand.choice_enum(ItemSize)

	append(&global.items, Item{item_pos, 0, item_type, item_size})
}

score_multiplier :: proc(size: ItemSize) -> int {
	switch size {
	case .Small:
		return 1
	case .Medium:
		return 2
	case .Large:
		return 4
	}
	return 0
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
	case .GameOver:
		if rl.IsKeyPressed(.SPACE) {
			menu = .MainMenu
		}
	case .Game:
		spawn_timer -= delta
		if spawn_timer <= 0 {
			spawn_item()
			spawn_timer = rand.float32_range(0, 0.5)
		}

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

		for &item, i in global.items {
			item.vel.y += ITEM_DROP_SPEED * delta
			item.pos += item.vel

			if rl.CheckCollisionCircleRec(
				item.pos,
				f32(item.size),
				{player.pos.x, player.pos.y, PLAYER_WIDTH, PLAYER_HEIGHT},
			) {
				if item.type == .Coal {
					lives -= 1
				} else {
					score += int(item.type) * score_multiplier(item.size)
				}

				unordered_remove(&items, i)
			}

			if item.pos.y > VIRTUAL_HEIGHT {
				unordered_remove(&items, i)
			}
		}

		if lives <= 0 {
			menu = .GameOver
		}
	}

}

render_lives :: proc(lives: int) {
	start := rl.Vector2{10, 10}

	for i in 0 ..< lives {
		pos := start + {f32(i) * (HEART_SIZE + HEART_PADDING), 0}
		rl.DrawRectangleV(pos, {HEART_SIZE, HEART_SIZE}, rl.RED)
	}
}

render :: proc(camera: ^rl.Camera2D) {
	using global

	switch menu {
	case .MainMenu:
		if gui_button({10, 10, 500, 200}, "Play Game", 24) {
			menu = .Game
			reset_state()
		}

	case .GameOver:
		score_text := fmt.caprintf("Score: %d", global.score)
		rl.DrawText(score_text, 10, 10, 24, rl.BLACK)

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
			rl.DrawCircleV(item.pos, f32(item.size), color)
		}
		rl.EndMode2D()

		score_text := fmt.caprint(global.score)
		score_text_width := rl.MeasureText(score_text, 48)
		rl.DrawText(score_text, VIRTUAL_WIDTH - score_text_width - 10, 10, 48, rl.BLACK)

		render_lives(lives)
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
