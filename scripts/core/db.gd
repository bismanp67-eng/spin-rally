extends Node
# Autoload: content tables (data/*.json) and the save file.
const SAVE_PATH := "user://save.json"
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
			crowd = 0.7, assist = true, fp_cam = false, trail = true, vibrate = true, replay = true},
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
