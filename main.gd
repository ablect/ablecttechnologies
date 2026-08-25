extends Node2D

const W := 1152.0
const H := 648.0
const ROAD_X := 255.0
const ROAD_W := 642.0
const PLAYER_Y := 520.0

var state := "menu"
var score := 0
var coins := 0
var best := 0
var speed := 300.0
var distance := 0.0
var spawn_timer := 0.0
var coin_timer := 0.0
var road_offset := 0.0
var car_x := W * 0.5
var boost_time := 0.0
var shake := 0.0
var rng := RandomNumberGenerator.new()
var obstacles: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var particles: Array[Dictionary] = []

var title_font := ThemeDB.fallback_font
var ui_font := ThemeDB.fallback_font

func _ready() -> void:
    rng.randomize()
    best = int(load_value("best", 0))
    queue_redraw()

func _process(delta: float) -> void:
    if state == "playing":
        update_game(delta)
    elif state == "gameover":
        update_particles(delta)
    queue_redraw()

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ENTER:
            if state == "menu" or state == "gameover":
                start_game()
        elif event.keycode == KEY_ESCAPE and state == "playing":
            state = "menu"
        elif event.keycode == KEY_SPACE and state == "playing":
            if boost_time <= 0.0:
                boost_time = 1.25

func start_game() -> void:
    state = "playing"
    score = 0
    coins = 0
    distance = 0.0
    speed = 300.0
    car_x = W * 0.5
    spawn_timer = 0.25
    coin_timer = 0.8
    road_offset = 0.0
    boost_time = 0.0
    shake = 0.0
    obstacles.clear()
    pickups.clear()
    particles.clear()

func update_game(delta: float) -> void:
    var left := Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT)
    var right := Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)
    var boost_pressed := Input.is_key_pressed(KEY_SPACE)

    var steer := 0.0
    if left:
        steer -= 1.0
    if right:
        steer += 1.0
    car_x += steer * 430.0 * delta
    car_x = clamp(car_x, ROAD_X + 68.0, ROAD_X + ROAD_W - 68.0)

    if boost_pressed and boost_time <= 0.0:
        boost_time = 0.12
    if boost_time > 0.0:
        boost_time -= delta

    var current_speed := speed + (185.0 if boost_time > 0.0 else 0.0)
    road_offset = fmod(road_offset + current_speed * delta, 96.0)
    distance += current_speed * delta * 0.035
    score = int(distance) + coins * 25
    speed = min(610.0, 300.0 + distance * 0.72)

    spawn_timer -= delta
    coin_timer -= delta
    if spawn_timer <= 0.0:
        spawn_obstacle()
        spawn_timer = max(0.32, 0.78 - distance * 0.00055) + rng.randf_range(0.0, 0.22)
    if coin_timer <= 0.0:
        spawn_coin_line()
        coin_timer = rng.randf_range(1.0, 1.8)

    for o in obstacles:
        o.y += current_speed * delta
    for c in pickups:
        c.y += current_speed * delta * 0.95

    for i in range(obstacles.size() - 1, -1, -1):
        if obstacles[i].y > H + 100.0:
            obstacles.remove_at(i)
        elif rect_circle_collision(Rect2(car_x - 34, PLAYER_Y - 54, 68, 108), Vector2(obstacles[i].x, obstacles[i].y), 34.0):
            crash()
            return

    for i in range(pickups.size() - 1, -1, -1):
        if pickups[i].y > H + 60.0:
            pickups.remove_at(i)
        elif Rect2(car_x - 38, PLAYER_Y - 58, 76, 116).has_point(Vector2(pickups[i].x, pickups[i].y)):
            coins += 1
            make_coin_particles(pickups[i].x, pickups[i].y)
            pickups.remove_at(i)

    update_particles(delta)

func crash() -> void:
    state = "gameover"
    shake = 0.35
    best = max(best, score)
    save_value("best", best)
    for i in range(22):
        particles.append({"x": car_x, "y": PLAYER_Y, "vx": rng.randf_range(-240.0, 240.0), "vy": rng.randf_range(-260.0, 40.0), "life": rng.randf_range(0.35, 0.8), "max": 0.8})

func spawn_obstacle() -> void:
    var lane := rng.randi_range(0, 2)
    var lane_w := ROAD_W / 3.0
    var x := ROAD_X + lane_w * (lane + 0.5)
    obstacles.append({"x": x, "y": -90.0, "kind": rng.randi_range(0, 2)})

func spawn_coin_line() -> void:
    var lane := rng.randi_range(0, 2)
    var lane_w := ROAD_W / 3.0
    var x := ROAD_X + lane_w * (lane + 0.5)
    for j in range(3):
        pickups.append({"x": x, "y": -70.0 - j * 78.0})

func update_particles(delta: float) -> void:
    for i in range(particles.size() - 1, -1, -1):
        var p = particles[i]
        p.x += p.vx * delta
        p.y += p.vy * delta
        p.vy += 380.0 * delta
        p.life -= delta
        particles[i] = p
        if p.life <= 0.0:
            particles.remove_at(i)
    shake = max(0.0, shake - delta)

func make_coin_particles(x: float, y: float) -> void:
    for i in range(8):
        particles.append({"x": x, "y": y, "vx": rng.randf_range(-100.0, 100.0), "vy": rng.randf_range(-150.0, 20.0), "life": 0.35, "max": 0.35})

func rect_circle_collision(rect: Rect2, center: Vector2, radius: float) -> bool:
    var closest := Vector2(clamp(center.x, rect.position.x, rect.end.x), clamp(center.y, rect.position.y, rect.end.y))
    return closest.distance_to(center) < radius

func _draw() -> void:
    draw_rect(Rect2(0, 0, W, H), Color("081018"))
    draw_background()
    draw_road()
    draw_entities()
    draw_particles()
    draw_hud()
    if state == "menu":
        draw_menu()
    elif state == "gameover":
        draw_gameover()

func draw_background() -> void:
    draw_rect(Rect2(0, 0, ROAD_X, H), Color("102b1b"))
    draw_rect(Rect2(ROAD_X + ROAD_W, 0, W - (ROAD_X + ROAD_W), H), Color("102b1b"))
    for y in range(0, int(H), 54):
        var yy := fmod(y + road_offset * 0.28, H)
        draw_circle(Vector2(65, yy), 12, Color("1d4a2d"))
        draw_circle(Vector2(110, yy + 18), 9, Color("1a3d27"))
        draw_circle(Vector2(1050, yy + 10), 12, Color("1d4a2d"))
        draw_circle(Vector2(1095, yy + 28), 9, Color("1a3d27"))

func draw_road() -> void:
    draw_rect(Rect2(ROAD_X, 0, ROAD_W, H), Color("20242b"))
    draw_rect(Rect2(ROAD_X, 0, 12, H), Color("d6b04e"))
    draw_rect(Rect2(ROAD_X + ROAD_W - 12, 0, 12, H), Color("d6b04e"))
    var lane_w := ROAD_W / 3.0
    for lane in range(1, 3):
        var x := ROAD_X + lane_w * lane
        for y in range(-96, int(H) + 96, 96):
            var yy := fmod(y + road_offset, H + 96.0) - 48.0
            draw_rect(Rect2(x - 4, yy, 8, 46), Color("cbd0d6"))
    for y in range(-120, int(H) + 120, 120):
        var yy := fmod(y + road_offset * 0.8, H + 120.0) - 60.0
        draw_rect(Rect2(ROAD_X - 25, yy, 10, 55), Color("f0f0f0"))
        draw_rect(Rect2(ROAD_X + ROAD_W + 15, yy, 10, 55), Color("f0f0f0"))

func draw_entities() -> void:
    for o in obstacles:
        draw_traffic_car(Vector2(o.x, o.y), int(o.kind))
    for c in pickups:
        draw_coin(Vector2(c.x, c.y))
    draw_player_car(Vector2(car_x, PLAYER_Y))

func draw_player_car(pos: Vector2) -> void:
    draw_rect(Rect2(pos.x - 34, pos.y - 54, 68, 108), Color("0b0b10"), true)
    draw_rect(Rect2(pos.x - 29, pos.y - 49, 58, 98), Color("e63b2e"), true)
    draw_rect(Rect2(pos.x - 22, pos.y - 37, 44, 28), Color("86c5dd"), true)
    draw_rect(Rect2(pos.x - 22, pos.y + 17, 44, 25), Color("7d1e1b"), true)
    draw_circle(Vector2(pos.x - 28, pos.y - 35), 6, Color("f6e4b3"))
    draw_circle(Vector2(pos.x + 28, pos.y - 35), 6, Color("f6e4b3"))
    draw_rect(Rect2(pos.x - 40, pos.y - 35, 10, 22), Color("0a0a0d"), true)
    draw_rect(Rect2(pos.x + 30, pos.y - 35, 10, 22), Color("0a0a0d"), true)
    draw_rect(Rect2(pos.x - 40, pos.y + 14, 10, 22), Color("0a0a0d"), true)
    draw_rect(Rect2(pos.x + 30, pos.y + 14, 10, 22), Color("0a0a0d"), true)
    if boost_time > 0.0 and state == "playing":
        draw_colored_polygon(PackedVector2Array([Vector2(pos.x - 16, pos.y + 49), Vector2(pos.x - 5, pos.y + 88), Vector2(pos.x + 5, pos.y + 49)]), Color("ffb000"))
        draw_colored_polygon(PackedVector2Array([Vector2(pos.x + 5, pos.y + 49), Vector2(pos.x + 16, pos.y + 82), Vector2(pos.x + 25, pos.y + 49)]), Color("ff4b24"))

func draw_traffic_car(pos: Vector2, kind: int) -> void:
    var body := Color("2e7bd6")
    if kind == 1:
        body = Color("f0c343")
    elif kind == 2:
        body = Color("27a36a")
    draw_rect(Rect2(pos.x - 31, pos.y - 46, 62, 92), Color("08090c"), true)
    draw_rect(Rect2(pos.x - 27, pos.y - 41, 54, 82), body, true)
    draw_rect(Rect2(pos.x - 20, pos.y - 31, 40, 24), Color("8ac4d8"), true)
    draw_rect(Rect2(pos.x - 18, pos.y + 12, 36, 20), Color("681b22"), true)
    draw_circle(Vector2(pos.x - 25, pos.y - 31), 5, Color("f4efe2"))
    draw_circle(Vector2(pos.x + 25, pos.y - 31), 5, Color("f4efe2"))
    draw_rect(Rect2(pos.x - 36, pos.y - 26, 9, 18), Color("090a0d"), true)
    draw_rect(Rect2(pos.x + 27, pos.y - 26, 9, 18), Color("090a0d"), true)
    draw_rect(Rect2(pos.x - 36, pos.y + 12, 9, 18), Color("090a0d"), true)
    draw_rect(Rect2(pos.x + 27, pos.y + 12, 9, 18), Color("090a0d"), true)

func draw_coin(pos: Vector2) -> void:
    draw_circle(pos, 14, Color("f7c84b"))
    draw_circle(pos, 9, Color("fff0a6"))
    draw_circle(pos, 5, Color("f1ad22"))
    draw_string(ui_font, Vector2(pos.x - 4, pos.y + 6), "$", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("805500"))

func draw_particles() -> void:
    for p in particles:
        var alpha: float = clamp(float(p.life) / float(p.max), 0.0, 1.0)
        draw_circle(Vector2(p.x, p.y), 4.0, Color(1.0, 0.68, 0.12, alpha))

func draw_hud() -> void:
    draw_rect(Rect2(24, 20, W - 48, 64), Color(0.02, 0.03, 0.05, 0.85), true)
    draw_string(ui_font, Vector2(45, 62), "NAIJA STREET RUSH", HORIZONTAL_ALIGNMENT_LEFT, -1, 25, Color("ffffff"))
    draw_string(ui_font, Vector2(430, 60), "SCORE  %05d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f6d365"))
    draw_string(ui_font, Vector2(640, 60), "COINS  %02d" % coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("f7c84b"))
    draw_string(ui_font, Vector2(850, 60), "BEST  %05d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("8bd5ff"))

func draw_menu() -> void:
    draw_rect(Rect2(210, 140, 732, 382), Color(0.02, 0.03, 0.05, 0.94), true)
    draw_string(title_font, Vector2(305, 250), "NAIJA STREET RUSH", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color("f6d365"))
    draw_string(ui_font, Vector2(382, 292), "Traffic. Speed. Survival.", HORIZONTAL_ALIGNMENT_LEFT, -1, 23, Color("c9d1d9"))
    draw_rect(Rect2(405, 345, 342, 76), Color("e63b2e"), true)
    draw_string(ui_font, Vector2(488, 395), "PRESS ENTER TO START", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffffff"))
    draw_string(ui_font, Vector2(410, 455), "A / D or Arrow Keys  =  Steer", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("9aa4b2"))
    draw_string(ui_font, Vector2(410, 485), "SPACE  =  Turbo Boost", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("9aa4b2"))

func draw_gameover() -> void:
    draw_rect(Rect2(280, 145, 592, 350), Color(0.02, 0.03, 0.05, 0.95), true)
    draw_string(title_font, Vector2(425, 245), "CRASHED!", HORIZONTAL_ALIGNMENT_LEFT, -1, 54, Color("ff6b55"))
    draw_string(ui_font, Vector2(465, 295), "Score: %d" % score, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color("ffffff"))
    draw_string(ui_font, Vector2(465, 333), "Coins: %d" % coins, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("f7c84b"))
    draw_string(ui_font, Vector2(465, 369), "Best: %d" % best, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("8bd5ff"))
    draw_rect(Rect2(425, 402, 302, 60), Color("2b79c2"), true)
    draw_string(ui_font, Vector2(492, 440), "ENTER  -  PLAY AGAIN", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("ffffff"))

func save_value(key: String, value: Variant) -> void:
    var f := FileAccess.open("user://save.dat", FileAccess.WRITE)
    if f:
        f.store_var({key: value})
        f.close()

func load_value(key: String, fallback: Variant) -> Variant:
    if not FileAccess.file_exists("user://save.dat"):
        return fallback
    var f := FileAccess.open("user://save.dat", FileAccess.READ)
    if not f:
        return fallback
    var data = f.get_var()
    f.close()
    if data is Dictionary and data.has(key):
        return data[key]
    return fallback
