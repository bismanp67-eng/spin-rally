extends Node
# Autoload: content tables (data/*.json) and the save file.
const SAVE_PATH := "user://save.json"
const World := preload("res://scripts/game/world.gd")
var bats: Array
var tables: Array
var arenas: Array
var balls: Array
var bots: Array
var serves: Array
var levels: Array
var challenges: Array
var save := {}

func defaults() -> Dictionary:
	return {
		settings = {quality = 1, fps = 60, lefty = false, colorblind = false, sens = 1.0, sfx = 0.8, music = 0.5,
			crowd = 0.7, assist = true, assist_lv = 1, auto_q = true, fp_cam = false, trail = true, vibrate = true, replay = true},
		equip = {bat = "allround_classic", table = "classic_blue", arena = "club", ball = "white",
			fh = "", bh = "", handle = "", shape = 0},
		stats = {matches = 0, wins = 0, points_won = 0, points_lost = 0, longest_rally = 0, fastest = 0.0,
			aces = 0, tournaments = 0, vs = {}},
		ladder = {}, challenges = {}, tutorial_done = false,
		last = {bot = "tomasz", level = 1, best_of = 3, serve = "pendulum", bracket = 8},
	}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	bats = load_json("bats")
	tables = load_json("tables")
	arenas = load_json("arenas")
	balls = load_json("balls")
	bots = load_json("bots")
	serves = load_json("serves")
	levels = load_json("levels")
	challenges = load_json("challenges")
	save = defaults()
	if FileAccess.file_exists(SAVE_PATH):
		var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if d is Dictionary:
			_merge(save, d)
			# saves from v1 have no auto flag: keep an explicit choice, auto-tune the untouched default
			if not d.get("settings", {}).has("assist_lv"):
				save.settings.assist_lv = 1 if save.settings.assist else 0
			if not d.get("settings", {}).has("auto_q"):
				save.settings.auto_q = int(save.settings.quality) == 1
	if save.settings.auto_q:
		save.settings.quality = detect_quality()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		write()

func detect_quality() -> int:
	var cores := OS.get_processor_count()
	var mem := float(OS.get_memory_info().get("physical", 0)) / 1073741824.0
	if mem <= 0.5:
		return 2 if cores >= 8 else 1
	if cores >= 8 and mem >= 10.5:
		return 3
	if cores >= 8 and mem >= 5.2:
		return 2
	if cores >= 6 and mem >= 3.2:
		return 1
	return 0

var dyn_scale := 1.0

# Low / Medium / High / Ultra. High and Ultra render at native resolution with 4x MSAA.
func apply_quality(vp: Viewport) -> void:
	var q := clampi(int(save.settings.quality), 0, 3)
	World.Q = q
	dyn_scale = [0.75, 0.9, 1.0, 1.0][q]
	vp.scaling_3d_scale = dyn_scale
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X, Viewport.MSAA_4X][q]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if q == 3 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = q >= 2

# Called every few seconds in a match: if the frame rate sags on auto quality, lower the render scale.
func adapt_quality(vp: Viewport) -> void:
	if not save.settings.auto_q:
		return
	var target := minf(float(save.settings.fps), 60.0)
	var fps := Engine.get_frames_per_second()
	if fps < target * 0.8 and dyn_scale > 0.6:
		dyn_scale -= 0.1
		vp.scaling_3d_scale = dyn_scale
		if dyn_scale < 0.85:
			vp.msaa_3d = Viewport.MSAA_2X if int(save.settings.quality) >= 2 else Viewport.MSAA_DISABLED

static func load_json(n: String) -> Array:
	var path := "res://data/%s.json" % n
	if not FileAccess.file_exists(path):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Array else []

func _merge(base: Dictionary, over: Dictionary) -> void:
	for k in over:
		if base.has(k) and base[k] is Dictionary and over[k] is Dictionary and not base[k].is_empty():
			_merge(base[k], over[k])
		else:
			base[k] = over[k]

func write() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))

static func find(list: Array, id: String) -> Dictionary:
	for e in list:
		if e.id == id:
			return e
	return list[0] if list.size() > 0 else {}

func opt(k: String):
	return save.settings[k]

# The player's bat with customizer colours applied.
func my_bat() -> Dictionary:
	var b: Dictionary = find(bats, save.equip.bat).duplicate()
	for k in ["fh", "bh", "handle"]:
		if save.equip[k] != "":
			b[k] = save.equip[k]
	b.shape = int(save.equip.shape)
	return b
