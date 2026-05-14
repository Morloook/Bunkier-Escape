class_name LevelGenerator
extends RefCounted

const C := Constants.Cell

static func generate(room_number: int, rng: RandomNumberGenerator) -> LevelData:
	var difficulty: Dictionary = _difficulty(room_number, rng)
	for _attempt: int in 500:
		var data: LevelData = _build(difficulty, rng, room_number)
		if data != null:
			print("[LevelGen] Pokój %d wygenerowany pomyślnie za %d. próbą." % [room_number, _attempt + 1])
			return data
	push_error("LevelGenerator: nie udało się wygenerować pokoju %d" % room_number)
	return _build_fallback(room_number)

# ---------------------------------------------------------------------------

static func _random_width(room_number: int, rng: RandomNumberGenerator) -> int:
	var tiers: Array = Settings.ROOM_WIDTH_TIERS
	@warning_ignore("integer_division")
	var tier: int = mini(room_number / 10, tiers.size() - 1)
	return rng.randi_range(tiers[tier][0], tiers[tier][1])

static func _difficulty(room_number: int, rng: RandomNumberGenerator) -> Dictionary:
	@warning_ignore("integer_division")
	var room_growth: int = room_number / Settings.ROOM_GROWTH_STEP
	@warning_ignore("integer_division")
	var crates_growth: int = room_number / Settings.CRATES_GROWTH_STEP
	
	var crates: int
	if room_number >= 30:
		crates = rng.randi_range(7, 10)
	else:
		crates = Settings.CRATES_BASE + mini(crates_growth, Settings.CRATES_MAX_EXTRA)

	var width: int = _random_width(room_number, rng)
	@warning_ignore("integer_division")
	var walls_growth: int = room_number / Settings.WALLS_GROWTH_STEP
	var height: int = Settings.ROOM_BASE_SIZE + mini(room_growth, Settings.ROOM_MAX_HEIGHT - Settings.ROOM_BASE_SIZE)
	width = maxi(width, height + 2)
	var walls: int = Settings.WALLS_BASE \
		+ mini(walls_growth, Settings.WALLS_MAX_EXTRA) \
		+ maxi(0, width - Settings.ROOM_BASE_SIZE) * Settings.WALLS_PER_EXTRA_WIDTH
	var slick: int = 0
	if room_number >= 30:
		slick = rng.randi_range(1, Settings.SLICK_MAX)
	elif room_number >= 8:
		@warning_ignore("integer_division")
		var max_slick: int = mini(2 + (room_number - 8) / Settings.SLICK_GROWTH_STEP, Settings.SLICK_MAX)
		slick = rng.randi_range(0, max_slick)
	elif room_number >= Settings.SLICK_MIN_ROOM:
		slick = 1
	@warning_ignore("integer_division")
	var capped20: int = mini(room_number, 20)
	@warning_ignore("integer_division")
	var shuffle: int = Settings.SHUFFLE_BASE \
			+ capped20 * Settings.SHUFFLE_PER_ROOM \
			+ (room_number / Settings.SHUFFLE_BONUS_INTERVAL) * Settings.SHUFFLE_BONUS_AMOUNT
	return {
		"width":         width,
		"height":        height,
		"crates":        crates,
		"inner_walls":   walls,
		"shuffle_moves": shuffle,
		"slick_tiles":   slick,
	}

static func _build(diff: Dictionary, rng: RandomNumberGenerator, room_number: int) -> LevelData:
	var W: int = diff["width"]
	var H: int = diff["height"]
	var n_crates: int = diff["crates"]

	var data := LevelData.new()
	data.width  = W
	data.height = H
	data.room_number = room_number
	data.cells.resize(W * H)
	data.cells.fill(C.FLOOR)

	# Warianty wizualne — jeden zestaw na cały pokój
	const WALL_TILES:  Array = [Vector2i(2,1), Vector2i(0,3), Vector2i(1,3), Vector2i(2,3), Vector2i(3,3)]
	const FLOOR_TILES: Array = [Vector2i(0,10), Vector2i(0,4), Vector2i(1,10), Vector2i(2,10)]
	const DOOR_VARIANTS: Array = [
		[Vector2i(9,2), Vector2i(9,3)],   # wariant A: open, locked
		[Vector2i(9,0), Vector2i(9,1)],   # wariant B: open, locked
	]
	# Pary ściana+podłoga które zlewają się wizualnie — losuj ponownie aż trafi dozwolona kombinacja.
	# Format każdego wpisu: [wall_tile, floor_tile]
	const FORBIDDEN_PAIRS: Array = [
		[Vector2i(2, 1), Vector2i(0, 10)],
		[Vector2i(2, 1), Vector2i(2, 10)],
		[Vector2i(2, 1), Vector2i(1, 10)],
	]
	var tw: Vector2i
	var tf: Vector2i
	while true:
		tw = WALL_TILES[rng.randi_range(0, WALL_TILES.size() - 1)]
		tf = FLOOR_TILES[rng.randi_range(0, FLOOR_TILES.size() - 1)]
		var forbidden := false
		for pair: Array in FORBIDDEN_PAIRS:
			if tw == pair[0] and tf == pair[1]:
				forbidden = true
				break
		if not forbidden:
			break
	data.tile_wall  = tw
	data.tile_floor = tf
	print("[LevelGen] pokój=%d  ściana=%s  podłoga=%s" % [room_number, tw, tf])
	var door_variant: Array = DOOR_VARIANTS[rng.randi_range(0, DOOR_VARIANTS.size() - 1)]
	data.tile_door_open   = door_variant[0]
	data.tile_door_locked = door_variant[1]

	# Ramka ścian
	for x: int in W:
		data.set_cell(Vector2i(x, 0),     C.WALL)
		data.set_cell(Vector2i(x, H - 1), C.WALL)
	for y: int in H:
		data.set_cell(Vector2i(0,     y), C.WALL)
		data.set_cell(Vector2i(W - 1, y), C.WALL)

	# Ściany wewnętrzne — algorytm odcinków (segment runs)
	# Stawiamy ściany w prostych odcinkach 2–4 kafli w jednym kierunku,
	# co tworzy korytarze, L-kształty i T-kształty zamiast blobów.
	var n_walls: int = int(diff["inner_walls"])
	@warning_ignore("integer_division")
	var min_floor: int = (W - 2) * (H - 2) * 2 / 5
	var walls_placed: int = 0
	var segment_ends: Array[Vector2i] = []
	var h_dirs := [Vector2i(1, 0), Vector2i(-1, 0)]
	var v_dirs := [Vector2i(0, 1), Vector2i(0, -1)]
	var safety: int = n_walls * 12
	while walls_placed < n_walls and safety > 0:
		safety -= 1
		if _count_floor(data) <= min_floor:
			break
		# Punkt startowy: 60% losowy, 40% z końca jednego z ostatnich 3 segmentów
		var start := Vector2i.ZERO
		if segment_ends.is_empty() or rng.randf() < 0.60:
			start = Vector2i(rng.randi_range(1, W - 2), rng.randi_range(1, H - 2))
		else:
			var tail_start: int = maxi(0, segment_ends.size() - 3)
			start = segment_ends[rng.randi_range(tail_start, segment_ends.size() - 1)]
		# Kierunek: losuj oś (poziom/pion) z lekką preferencją dłuższej osi pokoju
		var axis_dirs: Array
		var perp_dirs: Array
		if rng.randf() < float(W) / float(W + H):
			axis_dirs = h_dirs
			perp_dirs = v_dirs
		else:
			axis_dirs = v_dirs
			perp_dirs = h_dirs
		var dir: Vector2i = axis_dirs[rng.randi() % 2]
		# Główne ramię: 3–6 kafli
		var run_len: int = rng.randi_range(3, 6)
		var _before_placed: int = walls_placed
		var arm_cells: Array[Vector2i] = []
		for step: int in range(0, run_len):
			if walls_placed >= n_walls:
				break
			var wp: Vector2i = start + dir * step
			if wp.x < 1 or wp.x > W - 2 or wp.y < 1 or wp.y > H - 2:
				break
			if data.get_cell(wp) != C.FLOOR:
				break
			if _count_floor(data) <= min_floor:
				break
			data.set_cell(wp, C.WALL)
			walls_placed += 1
			arm_cells.append(wp)
		# 50% szans na gałąź prostopadłą (L lub T kształt)
		if arm_cells.size() >= 2 and rng.randf() < 0.50 and walls_placed < n_walls:
			var branch_origin: Vector2i = arm_cells[rng.randi_range(0, arm_cells.size() - 1)]
			var perp_dir: Vector2i = perp_dirs[rng.randi() % 2]
			var branch_len: int = rng.randi_range(2, 4)
			var last_branch := branch_origin
			for step: int in range(1, branch_len + 1):
				if walls_placed >= n_walls:
					break
				var wp: Vector2i = branch_origin + perp_dir * step
				if wp.x < 1 or wp.x > W - 2 or wp.y < 1 or wp.y > H - 2:
					break
				if data.get_cell(wp) != C.FLOOR:
					break
				if _count_floor(data) <= min_floor:
					break
				data.set_cell(wp, C.WALL)
				walls_placed += 1
				last_branch = wp
			if last_branch != branch_origin:
				segment_ends.append(last_branch)
		# Zapisuj koniec głównego ramienia tylko jeśli coś postawiono
		if not arm_cells.is_empty():
			segment_ends.append(arm_cells[-1])

	# Drzwi na losowej komórce ściany zewnętrznej (nie narożnik)
	var door_candidates: Array[Vector2i] = []
	for x: int in range(1, W - 1):
		door_candidates.append(Vector2i(x, 0))
		door_candidates.append(Vector2i(x, H - 1))
	for y: int in range(1, H - 1):
		door_candidates.append(Vector2i(0, y))
		door_candidates.append(Vector2i(W - 1, y))
	_shuffle_array(door_candidates, rng)

	data.door_pos = door_candidates[0]
	data.set_cell(data.door_pos, C.DOOR_LOCKED)

	# Pole wewnątrz przed drzwiami musi być podłogą
	var door_inside: Vector2i = _door_inside(data.door_pos, H)
	if data.get_cell(door_inside) == C.WALL:
		data.set_cell(door_inside, C.FLOOR)

	# Walidacja i naprawa zamkniętych obszarów — otwiera odcięte pokoje zamiast odrzucać poziom
	_fix_enclosed_areas(data, rng, room_number, door_inside)

	# Wolne pola — bez door_inside (slot tam blokuje wyjście po otwarciu drzwi)
	var free: Array[Vector2i] = _free_cells(data)
	free.erase(door_inside)
	if free.size() < n_crates * 2 + 1:
		return null

	# Sloty i skrzynki (stan rozwiązany) — każda beczka losowo para A lub B
	_shuffle_array(free, rng)
	for i: int in n_crates:
		var slot_pos: Vector2i = free[i]
		var use_b: bool = rng.randi_range(0, 1) == 1
		var s_type: int = C.SLOT_B          if use_b else C.SLOT
		var cs_type: int = C.CRATE_B_SLOTTED if use_b else C.CRATE_SLOTTED
		data.set_cell(slot_pos, s_type)
		data.slot_positions.append(slot_pos)
		data.crate_positions.append(slot_pos)
		data.set_cell(slot_pos, cs_type)

	# Gracz na wolnym polu
	var remaining: Array[Vector2i] = _free_cells(data)
	if remaining.is_empty():
		return null
	_shuffle_array(remaining, rng)
	data.player_start = remaining[0]

	# Sprawdź czy gracz w stanie rozwiązanym (skrzynki na slotach) ma ścieżkę do drzwi.
	# CRATE_SLOTTED blokuje przejście — jeśli drzwi są odgrodzone, odrzuć planszę.
	if not _can_reach(data, data.player_start, door_inside):
		return null

	# -----------------
	# PLAMY OLEJU I DEKORACJE TWORZONE PRZED MIESZANIEM
	# -----------------
	var n_slick: int = int(diff["slick_tiles"])
	if n_slick > 0:
		var slick_candidates: Array[Vector2i] = []
		for sy: int in range(1, H - 1):
			for sx: int in range(1, W - 1):
				var sp := Vector2i(sx, sy)
				if data.get_cell(sp) == C.FLOOR and sp != door_inside and sp != data.player_start:
					slick_candidates.append(sp)
		_shuffle_array(slick_candidates, rng)
		for si: int in mini(n_slick, slick_candidates.size()):
			data.slick_positions.append(slick_candidates[si])

	var DECO_TILES: Array = [Vector2i(8, 8), Vector2i(8, 9), Vector2i(8, 10)]
	if room_number >= 20:
		DECO_TILES.append(Vector2i(7, 10))
	var floor_cells: Array[Vector2i] = []
	for fy: int in H:
		for fx: int in W:
			var fp := Vector2i(fx, fy)
			if data.get_cell(fp) == C.FLOOR and not data.slick_positions.has(fp):
				floor_cells.append(fp)
	_shuffle_array(floor_cells, rng)
	var deco_count: int = max(1, int(floor_cells.size() * Settings.deco_density))
	for di: int in mini(deco_count, floor_cells.size()):
		data.floor_decorations.append({
			"pos":          floor_cells[di],
			"tile":         DECO_TILES[rng.randi_range(0, DECO_TILES.size() - 1)],
			"scale_factor": rng.randf_range(0.2, 0.7),
			"rotation_deg": rng.randi_range(0, 7) * 45,
		})

	print("[LevelGen] pokój=%d Gotowy do cofania. Ściany=%d, Beczki=%d, Olej=%d, Deco=%d" % [room_number, int(diff["inner_walls"]), n_crates, data.slick_positions.size(), data.floor_decorations.size()])

	var all_on_slots := true
	for cp: Vector2i in data.crate_positions:
		var c: int = data.get_cell(cp)
		if c != C.CRATE_SLOTTED and c != C.CRATE_B_SLOTTED:
			all_on_slots = false
			break

	if all_on_slots:
		print("[LevelGen] pokój=%d Wszystkie beczki na miejscach. Rozpoczynam cofanie (unshuffle)..." % room_number)
		_unshuffle(data, int(diff["shuffle_moves"]), rng, door_inside)
	else:
		print("[LevelGen] pokój=%d BŁĄD: Beczki nie są na miejscach przed cofaniem!" % room_number)
		return null

	# Upewniamy się, że po wymieszaniu żadna beczka nie stoi na plamie oleju (bo całkowicie ją zasłoni).
	for cp: Vector2i in data.crate_positions:
		if data.slick_positions.has(cp):
			print("[LevelGen] pokój=%d  ODRZUCONO — beczka ukrywa plamę oleju" % room_number)
			return null

	# Walidacja: jeśli wszystkie beczki nadal na swoich slotach → poziom pre-rozwiązany → odrzuć
	var slotted_a := 0; var free_a := 0
	var slotted_b := 0; var free_b := 0
	for slot_pos: Vector2i in data.slot_positions:
		var cell: int = data.get_cell(slot_pos)
		if cell == C.CRATE_SLOTTED:
			slotted_a += 1
		elif cell == C.CRATE_B_SLOTTED:
			slotted_b += 1
	for crate_pos: Vector2i in data.crate_positions:
		var cell: int = data.get_cell(crate_pos)
		if cell == C.CRATE or cell == C.CRATE_ON_SLOT_B:
			free_a += 1
		elif cell == C.CRATE_B or cell == C.CRATE_B_ON_SLOT:
			free_b += 1
	var free_total: int   = free_a + free_b
	var total_crates: int = free_total + slotted_a + slotted_b
	
	var min_free: int
	if total_crates <= 2:
		min_free = total_crates
	elif total_crates <= 5:
		min_free = total_crates - 1
	else:
		min_free = total_crates - 2
	if free_total == 0:
		print("[LevelGen] pokój=%d  ODRZUCONO — pre-rozwiązany  A: %d na slocie / %d poza  B: %d na slocie / %d poza" \
			% [room_number, slotted_a, free_a, slotted_b, free_b])
		return null
	if free_total < min_free:
		print("[LevelGen] pokój=%d  ODRZUCONO — za mało poza slotami (%d/%d, wymagane min %d)  A: %d na slocie / %d poza  B: %d na slocie / %d poza" \
			% [room_number, free_total, total_crates, min_free, slotted_a, free_a, slotted_b, free_b])
		return null
	print("[LevelGen] pokój=%d  OK  A: %d na slocie / %d poza  B: %d na slocie / %d poza" \
		% [room_number, slotted_a, free_a, slotted_b, free_b])

	# Walidacja ścieżki rozwiązania — symulacja na kopii stanu
	var sol_path: Array = data.get_meta("solution_path", [])
	if not sol_path.is_empty():
		var sim := GameState.from_level(data)
		for step_dir: Vector2i in sol_path:
			sim.try_move(step_dir)
		var path_ok := true
		for sp: Vector2i in data.slot_positions:
			var c: int = sim.get_cell(sp)
			if c != C.CRATE_SLOTTED and c != C.CRATE_B_SLOTTED:
				path_ok = false
				break
		if not path_ok:
			print("[LevelGen] pokój=%d  ODRZUCONO — ścieżka rozwiązania nieprawidłowa" % room_number)
			return null

	return data

# ---------------------------------------------------------------------------

static func _unshuffle(data: LevelData, moves: int, rng: RandomNumberGenerator, forbidden: Vector2i = Vector2i(-1, -1)) -> void:
	var player: Vector2i = data.player_start
	var n_crates: int = data.crate_positions.size()
	var path: Array[Vector2i] = []
	@warning_ignore("integer_division")
	var pulls_per_crate: int = maxi(1, moves / n_crates)

	var crate_pulls: Dictionary = {}
	for pos: Vector2i in data.crate_positions:
		crate_pulls[pos] = 0

	var max_iterations: int = moves * n_crates * 4
	var iterations: int = 0
	while true:
		iterations += 1
		if iterations > max_iterations:
			break

		# Sprawdzamy czy absolutnie KAŻDA beczka została odpowiednio wymieszana
		var all_done := true
		for pos: Vector2i in data.crate_positions:
			if crate_pulls.get(pos, 0) < pulls_per_crate:
				all_done = false
				break
		if all_done:
			break

		# BFS - szukamy najkrótszej drogi do każdego dostępnego pola
		var visited: Dictionary = {}
		var came_from: Dictionary = {}
		var queue: Array[Vector2i] = [player]
		
		visited[player] = true
		came_from[player] = {"dist": 0}
		var reachable_cells: Array[Vector2i] = [player]

		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			var dirs: Array[Vector2i] = Constants.DIR_VECTORS.duplicate()
			_shuffle_array(dirs, rng)
			
			for dir: Vector2i in dirs:
				var nb: Vector2i = cur + dir
				if visited.has(nb):
					continue
					
				var cell: int = data.get_cell(nb)
				if cell == C.FLOOR or cell == C.SLOT or cell == C.SLOT_B:
					visited[nb] = true
					came_from[nb] = {"prev": cur, "dir": dir, "dist": came_from[cur]["dist"] + 1}
					queue.append(nb)
					reachable_cells.append(nb)

		var valid_pulls: Array[Dictionary] = []
		_shuffle_array(reachable_cells, rng)

		# Sprawdzamy możliwe ciągnięcia z każdego dostępnego pola
		for cell_pos: Vector2i in reachable_cells:
			var dirs: Array[Vector2i] = Constants.DIR_VECTORS.duplicate()
			_shuffle_array(dirs, rng)
			
			for dir: Vector2i in dirs:
				var step_behind: Vector2i = cell_pos - dir
				var behind_cell: int = data.get_cell(step_behind)
				var behind_free: bool = (behind_cell == C.FLOOR or behind_cell == C.SLOT or behind_cell == C.SLOT_B)
				
				if not behind_free or cell_pos == forbidden:
					continue
					
				var check_pos := cell_pos + dir
				var found_crate := false
				var valid_slide := true
				var pull_crate_pos := Vector2i.ZERO
				var pull_is_crate_a := false
				
				# Wirtualny raycast sprawdzający ślizganie wstecz!
				while true:
					var c_cell := data.get_cell(check_pos)
					var is_a: bool = (c_cell == C.CRATE or c_cell == C.CRATE_SLOTTED or c_cell == C.CRATE_ON_SLOT_B)
					var is_b: bool = (c_cell == C.CRATE_B or c_cell == C.CRATE_B_SLOTTED or c_cell == C.CRATE_B_ON_SLOT)
					
					if is_a or is_b:
						found_crate = true
						pull_crate_pos = check_pos
						pull_is_crate_a = is_a
						break
						
					if c_cell != C.FLOOR and c_cell != C.SLOT and c_cell != C.SLOT_B:
						valid_slide = false
						break
						
					if not data.slick_positions.has(check_pos):
						valid_slide = false
						break
						
					check_pos += dir
					
				if found_crate and valid_slide:
					var would_stop := true
					if data.slick_positions.has(pull_crate_pos):
						var after_cell := data.get_cell(pull_crate_pos + dir)
						var after_free := (after_cell == C.FLOOR or after_cell == C.SLOT or after_cell == C.SLOT_B)
						if after_free:
							would_stop = false # Beczka nie mogła tu stanąć, zjechałaby dalej!
					
					if would_stop:
						valid_pulls.append({
							"cell_pos": cell_pos,
							"dir": dir,
							"crate_pos": pull_crate_pos,
							"is_crate_a": pull_is_crate_a,
							"dist": came_from[cell_pos]["dist"]
						})

		if valid_pulls.is_empty():
			break # Brak możliwości dalszego mieszania - kończymy

		# Szukamy beczki, która była ruszana najmniej razy.
		# Ponieważ reachable_cells i dirs zostały wcześniej przetasowane,
		# wybór kierunku dla tej beczki będzie losowy (wymusza rozrzucanie), a nie "najkrótszy".
		var min_pulls := 999999
		for vp: Dictionary in valid_pulls:
			var p: int = crate_pulls.get(vp["crate_pos"], 0)
			if p < min_pulls:
				min_pulls = p
				
		var best: Dictionary = valid_pulls[0]
		for vp: Dictionary in valid_pulls:
			if crate_pulls.get(vp["crate_pos"], 0) == min_pulls:
				best = vp
				break

		var target_cell: Vector2i = best["cell_pos"]
		var best_dir: Vector2i = best["dir"]
		var crate_pos: Vector2i = best["crate_pos"]
		var is_crate_a: bool = best["is_crate_a"]

		# 1. Przemarsz ducha z obecnej pozycji na target_cell
		var walk_path: Array[Vector2i] = []
		var curr := target_cell
		while curr != player:
			var step: Dictionary = came_from[curr]
			walk_path.append(step["dir"])
			curr = step["prev"]
		walk_path.reverse()

		for step_dir: Vector2i in walk_path:
			path.append(-step_dir)
		player = target_cell

		# 2. Wykonanie pociągnięcia beczki
		var behind: Vector2i = player - best_dir
		var crate_cell: int = data.get_cell(crate_pos)
		var player_terrain: int = data.get_cell(player)

		if is_crate_a:
			if crate_cell == C.CRATE_SLOTTED:
				data.set_cell(crate_pos, C.SLOT)
			elif crate_cell == C.CRATE_ON_SLOT_B:
				data.set_cell(crate_pos, C.SLOT_B)
			else:
				data.set_cell(crate_pos, C.FLOOR)
			
			if player_terrain == C.SLOT:
				data.set_cell(player, C.CRATE_SLOTTED)
			elif player_terrain == C.SLOT_B:
				data.set_cell(player, C.CRATE_ON_SLOT_B)
			else:
				data.set_cell(player, C.CRATE)
		else:
			if crate_cell == C.CRATE_B_SLOTTED:
				data.set_cell(crate_pos, C.SLOT_B)
			elif crate_cell == C.CRATE_B_ON_SLOT:
				data.set_cell(crate_pos, C.SLOT)
			else:
				data.set_cell(crate_pos, C.FLOOR)
			
			if player_terrain == C.SLOT_B:
				data.set_cell(player, C.CRATE_B_SLOTTED)
			elif player_terrain == C.SLOT:
				data.set_cell(player, C.CRATE_B_ON_SLOT)
			else:
				data.set_cell(player, C.CRATE_B)
		
		data.crate_positions.erase(crate_pos)
		data.crate_positions.append(player)

		var count: int = crate_pulls.get(crate_pos, 0)
		crate_pulls.erase(crate_pos)
		crate_pulls[player] = count + 1

		path.append(best_dir)
		player = behind

	path.reverse()
	data.set_meta("solution_path", path)
	data.player_start = player

# ---------------------------------------------------------------------------

static func _fix_enclosed_areas(data: LevelData, rng: RandomNumberGenerator, room_number: int, anchor: Vector2i) -> void:
	var W: int = data.width
	var H: int = data.height
	for _round: int in 10:
		# BFS od drzwi — znajdź wszystkie osiągalne pola podłogi
		var reachable: Dictionary = {}
		var queue: Array[Vector2i] = [anchor]
		reachable[anchor] = true
		while not queue.is_empty():
			var cur: Vector2i = queue.pop_front()
			for dir: Vector2i in Constants.DIR_VECTORS:
				var nb: Vector2i = cur + dir
				if reachable.has(nb):
					continue
				if data.get_cell(nb) == C.FLOOR:
					reachable[nb] = true
					queue.append(nb)
		# Znajdź odcięte pola podłogi
		var enclosed: Array[Vector2i] = []
		for y: int in range(1, H - 1):
			for x: int in range(1, W - 1):
				var p := Vector2i(x, y)
				if data.get_cell(p) == C.FLOOR and not reachable.has(p):
					enclosed.append(p)
		if enclosed.is_empty():
			return
		# Znajdź ściany wewnętrzne sąsiadujące z odciętym polem I z osiągalnym polem
		var bridges: Array[Vector2i] = []
		for ep: Vector2i in enclosed:
			for dir: Vector2i in Constants.DIR_VECTORS:
				var nb: Vector2i = ep + dir
				if nb.x <= 0 or nb.x >= W - 1 or nb.y <= 0 or nb.y >= H - 1:
					continue
				if data.get_cell(nb) != C.WALL:
					continue
				for dir2: Vector2i in Constants.DIR_VECTORS:
					if reachable.has(nb + dir2):
						bridges.append(nb)
						break
		if bridges.is_empty():
			break
		_shuffle_array(bridges, rng)
		var removed: Vector2i = bridges[0]
		data.set_cell(removed, C.FLOOR)
		# Przenieś usuniętą ścianę w losowe osiągalne miejsce (nie anchor, nie sąsiad anchora)
		var candidates: Array[Vector2i] = []
		for rp: Vector2i in reachable:
			if rp == anchor:
				continue
			var adj := false
			for dir: Vector2i in Constants.DIR_VECTORS:
				if rp + dir == anchor:
					adj = true
					break
			if not adj:
				candidates.append(rp)
		if not candidates.is_empty():
			_shuffle_array(candidates, rng)
			var new_pos: Vector2i = candidates[0]
			data.set_cell(new_pos, C.WALL)
			print("[LevelGen] pokój=%d  NAPRAWA zamkniętego obszaru: ściana %s → %s (odblokowuje %d pól)" \
				% [room_number, removed, new_pos, enclosed.size()])
		else:
			print("[LevelGen] pokój=%d  NAPRAWA zamkniętego obszaru: usunięto ścianę %s (brak miejsca na przeniesienie)" \
				% [room_number, removed])

static func _free_cells(data: LevelData) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y: int in data.height:
		for x: int in data.width:
			var p := Vector2i(x, y)
			var c: int = data.get_cell(p)
			if c == C.FLOOR or c == C.SLOT or c == C.SLOT_B:
				result.append(p)
	return result

static func _count_floor(data: LevelData) -> int:
	var n: int = 0
	for y: int in data.height:
		for x: int in data.width:
			if data.get_cell(Vector2i(x, y)) == C.FLOOR:
				n += 1
	return n

static func _door_inside(door: Vector2i, H: int) -> Vector2i:
	if door.y == 0:     return door + Vector2i(0,  1)
	if door.y == H - 1: return door + Vector2i(0, -1)
	if door.x == 0:     return door + Vector2i(1,  0)
	return door + Vector2i(-1, 0)

static func _can_reach(data: LevelData, from: Vector2i, to: Vector2i) -> bool:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		if cur == to:
			return true
		for dir: Vector2i in Constants.DIR_VECTORS:
			var nb: Vector2i = cur + dir
			if visited.has(nb):
				continue
			var cell: int = data.get_cell(nb)
			if cell == C.FLOOR or cell == C.SLOT or cell == C.SLOT_B:
				visited[nb] = true
				queue.append(nb)
	return false

static func _shuffle_array(arr: Array, rng: RandomNumberGenerator) -> void:
	for i: int in range(arr.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp

static func _build_fallback(room_number: int) -> LevelData:
	var data := LevelData.new()
	data.width  = 7
	data.height = 5
	data.room_number = room_number
	data.set_meta("is_fallback", true)
	# Fallback nigdy nie używa zakazanej pary (2,1)+(0,10)
	data.tile_wall  = Vector2i(0, 3)
	data.tile_floor = Vector2i(0, 4)
	data.cells.resize(7 * 5)
	data.cells.fill(C.FLOOR)
	for x: int in 7:
		data.set_cell(Vector2i(x, 0), C.WALL)
		data.set_cell(Vector2i(x, 4), C.WALL)
	for y: int in 5:
		data.set_cell(Vector2i(0, y), C.WALL)
		data.set_cell(Vector2i(6, y), C.WALL)
	data.door_pos = Vector2i(3, 0)
	data.set_cell(data.door_pos, C.DOOR_LOCKED)
	data.slot_positions  = [Vector2i(4, 2)]
	data.crate_positions = [Vector2i(2, 2)]
	data.set_cell(Vector2i(4, 2), C.SLOT)
	data.set_cell(Vector2i(2, 2), C.CRATE)
	data.player_start = Vector2i(3, 3)
	return data
