extends Node

const POOL_SIZE: int = 8
const PITCH_VARIANCE: float = 0.08
const COOLDOWN_MSEC: int = 50

var _bgm_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}
var _play_times: Dictionary = {}

var _bgm_playlist: Array[AudioStream] = []
var _current_bgm_index: int = 0
var _is_intro_playing: bool = false

func _ready() -> void:
	# Bezpieczeństwo: Upewnia się, że dedykowane szyny istnieją (tworzy je, jeśli brak)
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.get_bus_count() - 1, "SFX")

	process_mode = Node.PROCESS_MODE_ALWAYS # Dźwięki grają nawet po wstrzymaniu gry

	# Menedżer muzyki w tle
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.bus = "Music"
	_bgm_player.finished.connect(_on_bgm_finished)
	add_child(_bgm_player)

	# Utworzenie puli odtwarzaczy SFX
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

	_load_bgm_playlist()
	_load_sfx_cache()

	# Aplikuje zapisane/domyślne opcje z Settings
	var S := get_node("/root/Settings")
	set_music_volume(S.music_volume)
	set_music_enabled(S.music_enabled)
	set_sfx_volume(S.sfx_volume)
	set_sfx_enabled(S.sfx_enabled)

	if ResourceLoader.exists(S.START_BGM_PATH):
		var res = load(S.START_BGM_PATH)
		if res is AudioStream:
			if "loop" in res:
				res.loop = false # Zapewnia, że intro zagra tylko raz
			_is_intro_playing = true
			_bgm_player.stream = res
			_bgm_player.play()
		else:
			push_warning("AudioManager: Uszkodzony plik startowy muzyki: " + S.START_BGM_PATH)
			play_bgm()
	else:
		play_bgm()

func _load_sfx_cache() -> void:
	var S := get_node("/root/Settings")
	for key: String in S.SFX_PATHS:
		var val = S.SFX_PATHS[key]
		if typeof(val) == TYPE_ARRAY:
			var streams: Array[AudioStream] = []
			for path in val:
				if ResourceLoader.exists(path):
					var res = load(path)
					if res is AudioStream:
						streams.append(res)
					else:
						push_warning("AudioManager: Uszkodzony plik dźwiękowy (Array): " + path)
				else:
					push_warning("AudioManager: Brak pliku dźwiękowego (Array): " + path)
			if not streams.is_empty():
				_sfx_cache[key] = streams
		elif typeof(val) == TYPE_STRING:
			var path: String = val
			if ResourceLoader.exists(path):
				var res = load(path)
				if res is AudioStream:
					_sfx_cache[key] = res
				else:
					push_warning("AudioManager: Uszkodzony lub niepoprawny plik dźwiękowy: " + path)
			else:
				push_warning("AudioManager: Brak pliku dźwiękowego '" + key + "' pod ścieżką: " + path)

func _load_bgm_playlist() -> void:
	var S := get_node("/root/Settings")
	for path in S.BGM_PATHS:
		if ResourceLoader.exists(path):
			var res = load(path)
			if res is AudioStream:
				if "loop" in res:
					res.loop = false # Wyłączamy zapętlenie pojedynczego pliku, żeby sygnał 'finished' odpalił się poprawnie
				_bgm_playlist.append(res)
			else:
				push_warning("AudioManager: Uszkodzony plik muzyki tła: " + path)
		else:
			push_warning("AudioManager: Brak pliku muzyki tła pod ścieżką: " + path)

	if not _bgm_playlist.is_empty():
		_bgm_playlist.shuffle() # Odtwarzanie zacznie się od losowego utworu z listy

func play_bgm() -> void:
	if _bgm_playlist.is_empty():
		return
	_bgm_player.stream = _bgm_playlist[_current_bgm_index]
	_bgm_player.play()

func _on_bgm_finished() -> void:
	if _is_intro_playing:
		_is_intro_playing = false
		play_bgm()
		return

	if _bgm_playlist.is_empty():
		return
	_current_bgm_index = (_current_bgm_index + 1) % _bgm_playlist.size()
	_bgm_player.stream = _bgm_playlist[_current_bgm_index]
	_bgm_player.play()

func set_music_enabled(enabled: bool) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_mute(bus_idx, not enabled) # Mutowanie utrzymuje postęp muzyki (pauza wstrzymałaby utwór)

func set_music_volume(volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index("Music")
	var db := linear_to_db(volume) if volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(bus_idx, db)

func set_sfx_enabled(enabled: bool) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	AudioServer.set_bus_mute(bus_idx, not enabled)

func set_sfx_volume(volume: float) -> void:
	var bus_idx := AudioServer.get_bus_index("SFX")
	var db := linear_to_db(volume) if volume > 0.001 else -80.0
	AudioServer.set_bus_volume_db(bus_idx, db)

func play_sfx(sfx_name: String) -> void:
	if not _sfx_cache.has(sfx_name):
		return

	var now := Time.get_ticks_msec()
	if _play_times.has(sfx_name) and now - _play_times[sfx_name] < COOLDOWN_MSEC:
		return # Zapobiega zwielokrotnieniu głośności w tej samej klatce
	_play_times[sfx_name] = now

	for p in _sfx_pool:
		if not p.playing:
			var cached_data = _sfx_cache[sfx_name]
			if typeof(cached_data) == TYPE_ARRAY:
				p.stream = cached_data.pick_random() # Losuje z załadowanej tablicy dźwięków
			else:
				p.stream = cached_data
				
			p.pitch_scale = 1.0 + randf_range(-PITCH_VARIANCE, PITCH_VARIANCE)
			p.play()
			return

	push_warning("AudioManager: Brak wolnych odtwarzaczy w puli do zagrania: " + sfx_name)
