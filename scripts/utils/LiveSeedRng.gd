## Детерминированный RandomNumberGenerator из hex-сида сервера (live-сессия).
## Один и тот же seed_hex на всех клиентах даёт одинаковую последовательность rand*.
class_name LiveSeedRng
extends RefCounted


static func make_rng(seed_hex: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	var h: String = seed_hex.strip_edges()
	if h.is_empty():
		rng.randomize()
		return rng
	var a: int = hash(h)
	var b: int = hash("baccarat_trainer|shoe|" + h)
	var seed_val: int = a ^ (b << 1)
	if seed_val == 0:
		seed_val = 1
	rng.seed = seed_val
	return rng
