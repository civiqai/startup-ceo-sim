extends Node2D

# オフィスNPCキャラクター - 固定席で作業するスプライト

const TILE_SIZE := 32
const SPRITE_SCALE := Vector2(0.67, 0.67)
const FRAME_W := 48
const FRAME_H := 96  # 48px × 2行 = 1キャラクター
const ANIM_FPS := 8.0

# スプライトシートレイアウト（LimeZu Modern Interiors premade）
const IDLE_ROW := 0
const DIR_IDLE_COL := {
	"down": 0,
	"up": 1,
	"left": 2,
	"right": 3,
}

var member_index: int = 0
var member_data: Dictionary = {}
var character_sprite_index: int = 1

var _sprite: AnimatedSprite2D = null
var _name_label: Label = null


func setup(data: Dictionary, index: int, char_sprite_idx: int) -> void:
	member_data = data
	member_index = index
	character_sprite_index = char_sprite_idx

	_build_nodes()


func set_pathfinding(_pf: Node) -> void:
	# 互換性のため残す（移動不要なので使わない）
	pass


func set_home_position(pixel_pos: Vector2, _grid_pos: Vector2i) -> void:
	position = pixel_pos
	z_index = roundi(position.y)


func start_wandering() -> void:
	# 互換性のため残す（席固定なので何もしない）
	pass


func _build_nodes() -> void:
	y_sort_enabled = false

	# AnimatedSprite2D
	_sprite = AnimatedSprite2D.new()
	var sheet_path: String = "res://assets/images/characters/premade/Premade_Character_48x48_%02d.png" % character_sprite_index
	var frames: SpriteFrames = _create_sprite_frames(sheet_path)
	_sprite.sprite_frames = frames
	_sprite.scale = SPRITE_SCALE
	# 足元をノード位置に合わせるため、スプライトを上方向にオフセット
	_sprite.offset = Vector2(0, -FRAME_H / 2.0)
	_sprite.play("idle_down")
	add_child(_sprite)

	# NameLabel
	_name_label = Label.new()
	var display_name: String = member_data.get("name", "")
	_name_label.text = display_name
	_name_label.add_theme_font_size_override("font_size", 14)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.position = Vector2(-30, 4)
	_name_label.size = Vector2(60, 16)

	var is_ceo: bool = member_data.get("is_ceo", false)
	if is_ceo:
		_name_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.30))
	else:
		_name_label.add_theme_color_override("font_color", Color(0.90, 0.92, 0.96))

	add_child(_name_label)

	# 初期z_index
	z_index = roundi(position.y)


func _create_sprite_frames(sheet_path: String) -> SpriteFrames:
	var texture: Texture2D = load(sheet_path)
	var frames := SpriteFrames.new()

	# デフォルトアニメーションを削除
	if frames.has_animation("default"):
		frames.remove_animation("default")

	# アイドルアニメーション（4方向 × 1フレーム、96px行0に横並び）
	for dir_name: String in DIR_IDLE_COL.keys():
		var anim_name: String = "idle_" + dir_name
		var col: int = DIR_IDLE_COL[dir_name]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, ANIM_FPS)
		frames.set_animation_loop(anim_name, true)
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(
			col * FRAME_W,
			IDLE_ROW * FRAME_H,
			FRAME_W,
			FRAME_H
		)
		frames.add_frame(anim_name, atlas)

	return frames


