extends Node
# Autoload "Sfx": every sound is synthesized at startup. Buses: SFX, Music, Crowd.
# Ball sounds are layered (resonant partials + contact click + brush noise) and are pitched and
# mixed at play time from the hit's speed and spin and the surface it struck.
const RATE := 22050
var streams := {}
var pool: Array = []
var pool_i := 0
var crowd_p: AudioStreamPlayer
var ambience_p: AudioStreamPlayer
var music_p: AudioStreamPlayer
var music_task := -1
var amb_base := 0.0
var mode := "menu"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["SFX", "Music", "Crowd"]:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, b)
	for i in 10:
		pool.append(_player("SFX"))
	crowd_p = _player("Crowd")
	ambience_p = _player("Crowd")
	music_p = _player("Music")
	# name: [seconds, noise level, noise decay, partials [freq, decay, amp, sweep]...]
	var defs := {
		hit = [0.09, 0.5, 260.0, [1180.0, 55.0, 0.6, -120.0], [2350.0, 80.0, 0.3, 0.0], [640.0, 40.0, 0.25, 0.0]],
		brush = [0.12, 0.9, 60.0, [820.0, 45.0, 0.4, -80.0], [1650.0, 70.0, 0.15, 0.0]],
		wood = [0.1, 0.35, 300.0, [860.0, 50.0, 0.6, -60.0], [1720.0, 75.0, 0.3, 0.0], [2900.0, 110.0, 0.15, 0.0]],
		concrete = [0.07, 0.7, 180.0, [520.0, 85.0, 0.5, -40.0], [1300.0, 120.0, 0.2, 0.0]],
		glass = [0.16, 0.25, 320.0, [2250.0, 32.0, 0.5, 0.0], [3380.0, 40.0, 0.3, 0.0], [5100.0, 60.0, 0.15, 0.0]],
		metal = [0.28, 0.25, 280.0, [1480.0, 16.0, 0.4, 0.0], [2230.0, 14.0, 0.3, 0.0], [3710.0, 20.0, 0.2, 0.0]],
		net = [0.16, 0.9, 38.0, [170.0, 30.0, 0.5, -60.0]],
		floor = [0.1, 0.45, 160.0, [420.0, 50.0, 0.6, -50.0], [980.0, 80.0, 0.2, 0.0]],
		ui = [0.06, 0.15, 400.0, [1400.0, 70.0, 0.5, 300.0]],
		select = [0.16, 0.1, 400.0, [880.0, 22.0, 0.45, 0.0], [1320.0, 22.0, 0.3, 0.0]],
		back = [0.1, 0.1, 300.0, [660.0, 40.0, 0.5, -200.0]],
		good = [0.34, 0.0, 1.0, [660.0, 9.0, 0.4, 0.0], [990.0, 9.0, 0.3, 0.0], [1320.0, 12.0, 0.2, 0.0]],
		bad = [0.3, 0.05, 30.0, [310.0, 9.0, 0.5, -90.0], [233.0, 9.0, 0.3, -60.0]],
	}
	for k in defs:
		streams[k] = _synth(defs[k])
	streams.whoosh = _noise(0.22, 0.35, 2400.0)
	streams.cheer = _crowd(2.4, 1.0)
	streams.aww = _noise(1.3, 0.5, 420.0)
	streams.murmur = _noise(2.0, 0.25, 700.0, true)
	apply_volumes()
	music_task = WorkerThreadPool.add_task(_make_music)

func _exit_tree() -> void:
	if music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(music_task)

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

func _synth(d: Array) -> AudioStreamWAV:
	var n := int(d[0] * RATE)
	var out := PackedByteArray()
	out.resize(n * 2)
	var ph := [0.0, 0.0, 0.0, 0.0]
	for i in n:
		var t := float(i) / RATE
		var v: float = randf_range(-1.0, 1.0) * d[1] * exp(-d[2] * t)
		for k in range(3, d.size()):
			var pt: Array = d[k]
			ph[k - 3] += TAU * (pt[0] + pt[3] * t / d[0]) / RATE
			v += sin(ph[k - 3]) * pt[2] * exp(-pt[1] * t)
		v *= minf(1.0, i / 12.0) * minf(1.0, (n - i) / 60.0)
		out.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	return _wav(out)

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

# Applause: hundreds of individual claps over a roar of filtered noise.
func _crowd(dur: float, level: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		lp += (randf_range(-1.0, 1.0) - lp) * 0.16
		buf[i] = lp * sin(PI * pow(t, 0.5)) * 1.4
	for c in 420:
		var start := int(pow(randf(), 0.8) * (n - 600))
		var amp := randf_range(0.15, 0.45) * sin(PI * pow(float(start) / n, 0.5))
		for j in 260:
			buf[start + j] += randf_range(-1.0, 1.0) * amp * exp(-j / 40.0)
	var d := PackedByteArray()
	d.resize(n * 2)
	for i in n:
		d.encode_s16(i * 2, int(clampf(buf[i] * level * 0.6, -1.0, 1.0) * 26000.0))
	return _wav(d)

func _make_music() -> void:
	var trng := RandomNumberGenerator.new()  # own generator: this runs on a worker thread
	# 16-bar loop: warm pad, bass, plucked arpeggio, soft hats and kick.
	var bpm := 108.0
	var beat := 60.0 / bpm
	var chords := [[220.0, 261.6, 329.6], [174.6, 220.0, 261.6], [196.0, 246.9, 293.7], [164.8, 207.7, 246.9]]
	var n := int(beat * 32 * RATE)
	var d := PackedByteArray()
	d.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var b := t / beat
		var ch: Array = chords[int(b / 8.0) % 4]
		var eighth := int(b * 2.0)
		var nt := fmod(b * 2.0, 1.0) * beat * 0.5
		var f: float = ch[[0, 1, 2, 1, 0, 2, 1, 2][eighth % 8]] * 2.0
		var v := sin(TAU * f * t) * exp(-8.0 * nt) * 0.16
		var cb := fmod(b, 8.0) / 8.0
		var pad_env := minf(1.0, cb * 8.0) * minf(1.0, (1.0 - cb) * 8.0)
		for k in 3:
			v += sin(TAU * ch[k] * t + sin(TAU * 0.3 * t) * 0.4) * 0.05 * pad_env
		var bt := fmod(b, 1.0) * beat
		v += sin(TAU * ch[0] * 0.5 * t) * exp(-3.5 * bt) * 0.24
		v += sin(TAU * (48.0 + 70.0 * exp(-30.0 * bt)) * bt) * exp(-9.0 * bt) * (0.3 if int(b) % 2 == 0 else 0.0)
		lp += (trng.randf_range(-1.0, 1.0) - lp) * 0.7
		if eighth % 2 == 1:
			v += (trng.randf_range(-1.0, 1.0) - lp) * exp(-70.0 * nt) * 0.07
		d.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 22000.0))
	call_deferred("_music_ready", d)

func _music_ready(d: PackedByteArray) -> void:
	music_task = -1
	music_p.stream = _wav(d, true)
	music_p.play()
	set_mode(mode)

# Music sits back during a match.
func set_mode(m: String) -> void:
	mode = m
	music_p.volume_db = -11.0 if m == "match" else 0.0

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
	p.volume_db = linear_to_db(clampf(vol, 0.03, 1.6))
	p.play()

# Bat contact: a crisp tock for flat hits, layered with a brushing hiss as spin rises; harder = louder, brighter.
func hit(speed: float, spin: float) -> void:
	var s := clampf(spin / 500.0, 0.0, 1.0)
	var pw := clampf(speed / 22.0, 0.0, 1.0)
	play("hit", 0.92 + pw * 0.3 - s * 0.12 + randf_range(-0.03, 0.03), (0.35 + pw * 1.1) * (1.0 - s * 0.55))
	if s > 0.2:
		play("brush", 1.1 - s * 0.25 + pw * 0.15, s * (0.4 + pw * 0.8))

func bounce(surface: String, speed: float, spin: float) -> void:
	play(surface if streams.has(surface) else "wood", 0.96 + clampf(speed / 30.0, 0.0, 0.2) + randf_range(-0.02, 0.02), 0.25 + speed / 6.0)
	if spin > 250.0:
		play("brush", 1.5, clampf(spin / 1500.0, 0.05, 0.4))

func crowd(kind: String, amount: float) -> void:
	if amount <= 0.02:
		return
	crowd_p.stream = streams[kind]
	crowd_p.volume_db = linear_to_db(clampf(amount, 0.05, 1.3))
	crowd_p.pitch_scale = randf_range(0.92, 1.08)
	crowd_p.play()

func ambience(amount: float) -> void:
	amb_base = amount
	if amount <= 0.02:
		ambience_p.stop()
		return
	ambience_p.stream = streams.murmur
	ambience_p.volume_db = linear_to_db(amount * 0.3)
	ambience_p.play()

# The crowd's murmur swells as a rally gets longer.
func tension(hits: int) -> void:
	if amb_base > 0.02 and ambience_p.playing:
		ambience_p.volume_db = linear_to_db(amb_base * (0.3 + clampf(hits / 12.0, 0.0, 1.0) * 0.7))
