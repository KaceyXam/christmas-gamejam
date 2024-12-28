package game

import "core:fmt"
import "core:math/rand"
import rl "vendor:raylib"

VIRTUAL_WIDTH :: 1920
VIRTUAL_HEIGHT :: 1080
FLOOR_HEIGHT :: 100

LOGO_WIDTH :: 1000
LOGO_HEIGHT :: 600

PLAYER_HEIGHT :: 120
PLAYER_WIDTH :: 75
PLAYER_SPEED :: 15
JUMP_HEIGHT :: 10

HEART_SIZE :: 50
HEART_PADDING :: 5

GRAVITY :: 25
ITEM_DROP_SPEED :: 5

BUTTON_WIDTH :: 500
BUTTON_HEIGHT :: 75

font: rl.Font
logo: rl.Texture2D

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
	exit:        bool,
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
		return 4
	case .Medium:
		return 2
	case .Large:
		return 1
	}
	return 0
}

gui_button :: proc(
	bounds: rl.Rectangle,
	text: cstring,
	font_size: f32,
	button_color, border_color, font_color: rl.Color,
	border_radius, border_size: f32,
	camera: ^rl.Camera2D,
) -> (
	res: bool,
) {
	text_width := rl.MeasureTextEx(font, text, font_size, 1.0)

	mouse_pos := rl.GetScreenToWorld2D(rl.GetMousePosition(), camera^)
	if rl.IsWindowFocused() && rl.CheckCollisionPointRec(mouse_pos, bounds) {
		if rl.IsMouseButtonReleased(.LEFT) {
			res = true
		}
	}

	rl.DrawRectangleRounded(bounds, border_radius, 10, button_color)
	rl.DrawRectangleRoundedLinesEx(bounds, border_radius, 100, border_size, border_color)
	rl.DrawTextEx(
		font,
		text,
		rl.Vector2 {
			(bounds.x) + ((bounds.width) - f32(text_width.x)) / 2,
			bounds.y + ((bounds.height) - f32(font_size)) / 2,
		},
		f32(font_size),
		1.0,
		font_color,
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
			spawn_timer = rand.float32_range(0.1, 0.5)
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

	rl.BeginMode2D(camera^)

	switch menu {
	case .MainMenu:
		rl.DrawTextureV(logo, {VIRTUAL_WIDTH / 2 - LOGO_WIDTH / 2, 10}, rl.WHITE)

		play_rect := rl.Rectangle {
			VIRTUAL_WIDTH / 2 - BUTTON_WIDTH / 2,
			LOGO_HEIGHT + 50,
			BUTTON_WIDTH,
			BUTTON_HEIGHT,
		}

		if gui_button(play_rect, "Play Game", 64, rl.GRAY, rl.DARKGRAY, rl.WHITE, 0.1, 5, camera) {
			menu = .Game
			reset_state()
		}

		exit_rect := play_rect
		exit_rect.y += BUTTON_HEIGHT + 50

		if gui_button(exit_rect, "Exit Game", 64, rl.GRAY, rl.DARKGRAY, rl.WHITE, 0.1, 5, camera) {
			exit = true
		}

	case .GameOver:
		score_text := fmt.caprintf("Final Score: %d", global.score)
		text_width := rl.MeasureTextEx(font, score_text, 128, 1).x
		rl.DrawTextEx(
			font,
			score_text,
			{VIRTUAL_WIDTH / 2 - text_width / 2, VIRTUAL_HEIGHT / 2 - 128},
			128,
			1,
			rl.BLACK,
		)

		menu_rect := rl.Rectangle {
			VIRTUAL_WIDTH / 2 - BUTTON_WIDTH / 2,
			VIRTUAL_HEIGHT / 2 + BUTTON_HEIGHT,
			BUTTON_WIDTH,
			BUTTON_HEIGHT,
		}

		if gui_button(menu_rect, "Main Menu", 64, rl.GRAY, rl.DARKGRAY, rl.WHITE, 0.1, 5, camera) {
			menu = .MainMenu
		}

	case .Game:
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

		score_text := fmt.caprint(global.score)
		score_text_width := rl.MeasureTextEx(font, score_text, 48, 1).x
		rl.DrawTextEx(
			font,
			score_text,
			{VIRTUAL_WIDTH - score_text_width - 10, 10},
			48,
			1,
			rl.BLACK,
		)

		render_lives(lives)
	}

	rl.EndMode2D()
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, "Christmas Game")
	defer rl.CloseWindow()

	font = rl.LoadFontEx("assets/Kanit-Bold.ttf", 128, nil, 0)

	rl.SetTextureFilter(rl.GetFontDefault().texture, .POINT)
	rl.SetTextureFilter(font.texture, .POINT)

	logo = rl.LoadTextureFromImage(rl.LoadImage("assets/logo.png"))

	rl.SetExitKey(nil)

	reset_state()
	global.menu = .MainMenu

	for !global.exit {
		if rl.WindowShouldClose() {
			global.exit = true
		}

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
