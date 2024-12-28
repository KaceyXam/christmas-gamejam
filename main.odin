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
BUTTON_HEIGHT :: 100

LIGHT_GREEN: rl.Color : {109, 241, 129, 255}
DARK_GREEN: rl.Color : {31, 97, 41, 255}
LIGHT_RED: rl.Color : {241, 109, 109, 255}
DARK_RED: rl.Color : {108, 19, 19, 255}

font: rl.Font
logo: rl.Texture2D
floor: rl.Texture2D
heart: rl.Texture2D
robot: rl.Texture2D
textures: map[ItemType]rl.Texture2D = {}
background: rl.Texture2D
sounds: map[SoundEffect]rl.Sound

MenuState :: enum {
	MainMenu,
	Game,
	GameOver,
}

SoundEffect :: enum {
	Menu,
	Collect,
	Hurt,
	Explode,
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
	is_left:  bool,
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
	player.is_left = true
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

render_item :: proc(item: Item) {
	using item

	fsize := f32(size)

	rect := rl.Rectangle{pos.x - fsize, pos.y - fsize, fsize * 2, fsize * 2}
	adjusted_pos := pos - fsize / 2

	rl.DrawTexturePro(textures[type], {0, 0, 150, 150}, rect, {}, 0, rl.WHITE)
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
			rl.PlaySound(sounds[.Menu])
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
			rl.PlaySound(sounds[.Menu])
		}
	case .GameOver:
		if rl.IsKeyPressed(.SPACE) {
			menu = .MainMenu
			rl.PlaySound(sounds[.Menu])
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

		if player.vel.x > 0 {
			player.is_left = false
		} else if player.vel.x < 0 {
			player.is_left = true
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
					if lives >= 1 {
						rl.PlaySound(sounds[.Hurt])
					} else {
						rl.PlaySound(sounds[.Explode])
					}
				} else {
					score += int(item.type) * score_multiplier(item.size)
					rl.PlaySound(sounds[.Collect])
				}

				unordered_remove(&items, i)
			}

			if item.pos.y > VIRTUAL_HEIGHT + f32(item.size) {
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
		rl.DrawTextureV(heart, pos, rl.WHITE)
	}
}

render :: proc(camera: ^rl.Camera2D) {
	using global

	rl.BeginMode2D(camera^)

	rl.DrawTextureRec(background, {0, 0, 1920, 1080}, {}, rl.WHITE)

	switch menu {
	case .MainMenu:
		rl.DrawTextureV(logo, {VIRTUAL_WIDTH / 2 - LOGO_WIDTH / 2, 10}, rl.WHITE)

		play_rect := rl.Rectangle {
			VIRTUAL_WIDTH / 2 - BUTTON_WIDTH / 2,
			LOGO_HEIGHT + 50,
			BUTTON_WIDTH,
			BUTTON_HEIGHT,
		}

		if gui_button(
			play_rect,
			"Play Game",
			64,
			LIGHT_GREEN,
			DARK_GREEN,
			DARK_GREEN,
			0.1,
			5,
			camera,
		) {
			menu = .Game
			reset_state()
		}

		exit_rect := play_rect
		exit_rect.y += BUTTON_HEIGHT + 50

		if gui_button(exit_rect, "Exit Game", 64, LIGHT_RED, DARK_RED, DARK_RED, 0.1, 5, camera) {
			exit = true
		}

	case .GameOver:
		score_text := fmt.caprintf("Final Score: %d", global.score)
		text_width := rl.MeasureTextEx(font, score_text, 128, 1).x
		rl.DrawRectangleRounded(
			{
				VIRTUAL_WIDTH / 2 - (text_width + 40) / 2,
				VIRTUAL_HEIGHT / 3 - 128,
				text_width + 40,
				128,
			},
			0.5,
			10,
			{50, 50, 50, 100},
		)
		rl.DrawTextEx(
			font,
			score_text,
			{VIRTUAL_WIDTH / 2 - text_width / 2, VIRTUAL_HEIGHT / 3 - 128},
			128,
			1,
			rl.WHITE,
		)

		menu_rect := rl.Rectangle {
			VIRTUAL_WIDTH / 2 - BUTTON_WIDTH / 2,
			VIRTUAL_HEIGHT / 2 + BUTTON_HEIGHT,
			BUTTON_WIDTH,
			BUTTON_HEIGHT,
		}

		if gui_button(
			menu_rect,
			"Main Menu",
			64,
			LIGHT_GREEN,
			DARK_GREEN,
			DARK_GREEN,
			0.1,
			5,
			camera,
		) {
			menu = .MainMenu
		}

		exit_rect := menu_rect
		exit_rect.y += BUTTON_HEIGHT + 50

		if gui_button(exit_rect, "Exit Game", 64, LIGHT_RED, DARK_RED, DARK_RED, 0.1, 5, camera) {
			exit = true
		}

	case .Game:
		rl.DrawTextureV(floor, {0, VIRTUAL_HEIGHT - FLOOR_HEIGHT}, rl.WHITE)

		player_src_rect := rl.Rectangle{0, 0, 150, 240}
		if !player.is_left {
			player_src_rect.width *= -1
		}
		rl.DrawTexturePro(
			robot,
			player_src_rect,
			{player.pos.x, player.pos.y, PLAYER_WIDTH, PLAYER_HEIGHT},
			{},
			0,
			rl.WHITE,
		)

		for item in global.items {
			render_item(item)
		}

		score_text := fmt.caprint(global.score)
		score_text_width := rl.MeasureTextEx(font, score_text, 48, 1).x
		rl.DrawTextEx(
			font,
			score_text,
			{VIRTUAL_WIDTH - score_text_width - 10, 10},
			48,
			1,
			rl.WHITE,
		)

		render_lives(lives)
	}

	rl.EndMode2D()
}

main :: proc() {
	rl.SetConfigFlags({.VSYNC_HINT})
	rl.InitWindow(VIRTUAL_WIDTH, VIRTUAL_HEIGHT, "Christmas Game")
	defer rl.CloseWindow()
	rl.InitAudioDevice()
	defer rl.CloseAudioDevice()

	font = rl.LoadFontEx("assets/Kanit-Bold.ttf", 128, nil, 0)

	rl.SetTextureFilter(rl.GetFontDefault().texture, .POINT)
	rl.SetTextureFilter(font.texture, .POINT)

	logo = rl.LoadTextureFromImage(rl.LoadImage("assets/logo.png"))
	rl.SetTextureFilter(logo, .POINT)
	defer rl.UnloadTexture(logo)
	floor = rl.LoadTextureFromImage(rl.LoadImage("assets/floor.png"))
	rl.SetTextureFilter(floor, .POINT)
	defer rl.UnloadTexture(floor)
	heart = rl.LoadTextureFromImage(rl.LoadImage("assets/heart.png"))
	rl.SetTextureFilter(heart, .POINT)
	defer rl.UnloadTexture(heart)
	robot = rl.LoadTextureFromImage(rl.LoadImage("assets/robot.png"))
	rl.SetTextureFilter(robot, .POINT)
	defer rl.UnloadTexture(robot)

	textures[.CandyCane] = rl.LoadTextureFromImage(rl.LoadImage("assets/candycane.png"))
	defer rl.UnloadTexture(textures[.CandyCane])
	textures[.Gingerbread] = rl.LoadTextureFromImage(rl.LoadImage("assets/gingerbread.png"))
	defer rl.UnloadTexture(textures[.Gingerbread])
	textures[.Present] = rl.LoadTextureFromImage(rl.LoadImage("assets/present.png"))
	defer rl.UnloadTexture(textures[.Present])
	textures[.Coal] = rl.LoadTextureFromImage(rl.LoadImage("assets/coal.png"))
	defer rl.UnloadTexture(textures[.Coal])

	background = rl.LoadTextureFromImage(rl.LoadImage("assets/background.png"))
	defer rl.UnloadTexture(background)

	sounds[.Menu] = rl.LoadSound("assets/menuSelect.wav")
	defer rl.UnloadSound(sounds[.Menu])
	sounds[.Collect] = rl.LoadSound("assets/pickupCoin.wav")
	defer rl.UnloadSound(sounds[.Collect])
	sounds[.Hurt] = rl.LoadSound("assets/hitHurt.wav")
	defer rl.UnloadSound(sounds[.Hurt])
	sounds[.Explode] = rl.LoadSound("assets/explosion.wav")
	defer rl.UnloadSound(sounds[.Explode])

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
