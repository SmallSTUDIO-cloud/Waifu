extends RefCounted
# Values are intentionally limited to known quality tiers; corrupted saves
# never become unchecked indices or turn gameplay effects fully invisible.
const DEFAULT_PATH = "user://quality.cfg"
var path: String = DEFAULT_PATH
var physics: int = 2
var effects: int = 1

func load_settings() -> void:
    var cfg = ConfigFile.new()
    if cfg.load(path) != OK: return
    var p = cfg.get_value("quality", "physics", 2)
    var e = cfg.get_value("quality", "effects", 1)
    physics = clampi(int(p) if p is int or p is float else 2, 0, 2)
    effects = clampi(int(e) if e is int or e is float else 1, 0, 1)

func save_settings() -> Error:
    var cfg = ConfigFile.new()
    cfg.set_value("quality", "physics", physics)
    cfg.set_value("quality", "effects", effects)
    return cfg.save(path)
