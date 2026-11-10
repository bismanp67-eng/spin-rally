extends Node
# Autoload "Sfx": every sound is synthesized at startup. Buses: SFX, Music, Crowd.
const RATE := 22050
var streams := {}
var pool: Array = []
var pool_i := 0
var crowd_p: AudioStreamPlayer
var ambience_p: AudioStreamPlayer
var music_p: AudioStreamPlayer
var music_task := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["SFX", "Music", "Crowd"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)
	crowd_p = _player("Crowd")
	ambience_p = _player("Crowd")
	music_p = _player("Music")
	# name: [freq, seconds, decay, noise mix, freq sweep]
	var defs := {
		hit = [1500.0, 0.05, 70.0, 0.25, 0.0], brush = [900.0, 0.07, 45.0, 0.7, 0.0],
		wood = [1050.0, 0.06, 60.0, 0.1, 0.0], concrete = [520.0, 0.05, 80.0, 0.45, 0.0],
		glass = [2300.0, 0.09, 40.0, 0.05, 0.0], metal = [1700.0, 0.16, 22.0, 0.08, 0.0],
		net = [180.0, 0.12, 30.0, 0.8, 0.0], floor = [420.0, 0.06, 55.0, 0.3, 0.0],
		ui = [880.0, 0.05, 50.0, 0.0, 0.0], good = [660.0, 0.22, 10.0, 0.0, 660.0], bad = [330.0, 0.25, 9.0, 0.0, -160.0],
	}
	for k in defs:
		streams[k] = _tone(defs[k][0], defs[k][1], defs[k][2], defs[k][3], defs[k][4])
	streams.cheer = _noise(1.6, 0.9, 1400.0)
	streams.aww = _noise(1.1, 0.5, 500.0)
	streams.murmur = _noise(2.0, 0.25, 700.0, true)
	apply_volumes()
	music_task = WorkerThreadPool.add_task(_make_music)

func _player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _wav(data: PackedByteArray, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = data.size() / 2
	return w

func _tone(freq: float, dur: float, decay: float, noise: float, sweep: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedByteArray()
	d.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * (freq + sweep * t / dur) / RATE
		var v := (sin(ph) * (1.0 - noise) + randf_range(-1.0, 1.0) * noise) * exp(-decay * t) * minf(1.0, i / 30.0)
		d.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	return _wav(d)

func _noise(dur: float, level: float, cutoff: float, loop: bool = false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var d := PackedByteArray()
	d.resize(n * 2)
	var lp := 0.0
	var a := clampf(cutoff / RATE * 3.0, 0.01, 1.0)
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * a
		var envl := 1.0 if loop else sin(PI * pow(t, 0.6)) * (0.8 + 0.2 * sin(t * 40.0))
		d.encode_s16(i * 2, int(clampf(lp * envl * level * 3.0, -1.0, 1.0) * 24000.0))
	return _wav(d, loop)

func _make_music() -> void:
	# A light 8-bar loop: bass + plucked arpeggio.
	var bpm := 104.0
	var beat := 60.0 / bpm
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7], [164.8, 207.7, 246.9]]
	var n := int(beat * 32 * RATE)
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var b := t / beat
		var ch: Array = chords[int(b / 8.0) % 4]
		var eighth := int(b * 2.0)
		var nt := fmod(b * 2.0, 1.0) * beat * 0.5
		var f: float = ch[[0, 1, 2, 1, 0, 2, 1, 2][eighth % 8]] * 2.0
		var v := sin(TAU * f * t) * exp(-9.0 * nt) * 0.22
		var bt := fmod(b, 2.0) * beat
		v += sin(TAU * ch[0] * 0.5 * t) * exp(-2.5 * bt) * 0.3
		if eighth % 4 == 2:
			v += randf_range(-1.0, 1.0) * exp(-60.0 * nt) * 0.08
		d.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 22000.0))
	call_deferred("_music_ready", d)

func _music_ready(d: PackedByteArray) -> void:
	music_p.stream = _wav(d, true)
	music_p.play()

func apply_volumes() -> void:
	for pair in [["SFX", "sfx"], ["Music", "music"], ["Crowd", "crowd"]]:
		var i := AudioServer.get_bus_index(pair[0])
		var v: float = DB.opt(pair[1])
		AudioServer.set_bus_mute(i, v <= 0.01)
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.01)))

func play(n: String, pitch: float = 1.0, vol: float = 1.0) -> void:
	var p: AudioStreamPlayer = pool[pool_i]
	pool_i = (pool_i + 1) % pool.size()
	p.stream = streams[n]
	p.pitch_scale = clampf(pitch, 0.3, 3.0)
	p.volume_db = linear_to_db(clampf(vol, 0.05, 1.5))
	p.play()

# Bat contact: more spin = brushier and lower.
func hit(speed: float, spin: float) -> void:
	var s := clampf(spin / 120.0, 0.0, 1.0)
	play("brush" if s > 0.55 else "hit", lerpf(1.15, 0.8, s) + speed * 0.01, 0.5 + speed / 20.0)

func bounce(surface: String, speed: float, spin: float) -> void:
	play(surface if streams.has(surface) else "wood", 1.0 + clampf(spin / 400.0, 0.0, 0.25), 0.35 + speed / 8.0)

func crowd(kind: String, amount: float) -> void:
	if amount <= 0.02:
		return
	crowd_p.stream = streams[kind]
	crowd_p.volume_db = linear_to_db(clampf(amount, 0.05, 1.2))
	crowd_p.pitch_scale = randf_range(0.9, 1.1)
	crowd_p.play()

func ambience(amount: float) -> void:
	if amount <= 0.02:
		ambience_p.stop()
		return
	ambience_p.stream = streams.murmur
	ambience_p.volume_db = linear_to_db(amount * 0.35)
	ambience_p.play()
