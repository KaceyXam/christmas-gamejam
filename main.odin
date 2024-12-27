package game

import rl "vendor:raylib"

main :: proc() {
	rl.InitWindow(800, 600, "Christmas Game")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.EndDrawing()
	}
}
