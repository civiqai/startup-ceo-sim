extends Node
## Kenney UI Pack テーマヘルパー（Autoload シングルトン）
## StyleBoxTexture を生成するファクトリメソッドを提供

# ボタンテクスチャのパス
const BTN_PATH := "res://assets/images/ui/kenney/buttons/"
const PANEL_PATH := "res://assets/images/ui/kenney/panels/"
const SLIDER_PATH := "res://assets/images/ui/kenney/sliders/"

# ボタンの9patch マージン（Double=2x サイズ用）
# 角丸 ~24px, 下部の depth ~16px
const BTN_MARGIN_LEFT := 24
const BTN_MARGIN_TOP := 24
const BTN_MARGIN_RIGHT := 24
const BTN_MARGIN_BOTTOM := 32  # depth部分を含む

# depth なしボタンのマージン
const BTN_FLAT_MARGIN_BOTTOM := 24

# パネルの9patch マージン
const PANEL_MARGIN := 24

# スライダーの9patch マージン
const SLIDER_MARGIN_H := 16
const SLIDER_MARGIN_V := 8

# テクスチャキャッシュ
var _texture_cache: Dictionary = {}


func _ready() -> void:
	pass


## テクスチャをロード（キャッシュ付き）
func _load_tex(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex = load(path)
	if tex:
		_texture_cache[path] = tex
	return tex


## ボタン用 StyleBox を生成
## color: "blue", "green", "red", "yellow", "grey"
## style: "depth_flat" (デフォルト), "depth_border", "flat", "depth_line"
func make_button_style(color: String = "blue", style: String = "depth_flat", modulate: Color = Color(1, 1, 1, 1)) -> StyleBox:
	var path := BTN_PATH + color + "_button_rectangle_" + style + ".png"
	var tex := _load_tex(path)
	if not tex:
		push_warning("KenneyTheme: テクスチャが見つかりません: " + path)
		return _fallback_button_style()

	var sb := StyleBoxTexture.new()
	sb.texture = tex

	# 9patch マージン設定
	var has_depth := style.begins_with("depth")
	sb.texture_margin_left = BTN_MARGIN_LEFT
	sb.texture_margin_top = BTN_MARGIN_TOP
	sb.texture_margin_right = BTN_MARGIN_RIGHT
	sb.texture_margin_bottom = BTN_MARGIN_BOTTOM if has_depth else BTN_FLAT_MARGIN_BOTTOM

	# コンテンツマージン（テキストのパディング）
	sb.content_margin_left = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_right = 20.0
	sb.content_margin_bottom = 16.0 if has_depth else 12.0

	# モジュレートカラー（hover時の明るさ調整など）
	if modulate != Color(1, 1, 1, 1):
		sb.modulate_color = modulate

	return sb


## パネル用 StyleBoxTexture を生成
## style: "input_rectangle" (白背景), "input_outline_rectangle" (枠のみ)
func make_panel_style(style: String = "input_outline_rectangle") -> StyleBox:
	var path := PANEL_PATH + style + ".png"
	var tex := _load_tex(path)
	if not tex:
		push_warning("KenneyTheme: テクスチャが見つかりません: " + path)
		return _fallback_panel_style()

	var sb := StyleBoxTexture.new()
	sb.texture = tex

	sb.texture_margin_left = PANEL_MARGIN
	sb.texture_margin_top = PANEL_MARGIN
	sb.texture_margin_right = PANEL_MARGIN
	sb.texture_margin_bottom = PANEL_MARGIN

	sb.content_margin_left = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 12.0

	# パネル用にモジュレート（暗い背景に合わせる）
	sb.modulate_color = Color(0.15, 0.17, 0.22, 0.95)

	return sb


## ポップアップ用ダークパネル StyleBoxTexture
func make_popup_panel_style() -> StyleBox:
	var path := PANEL_PATH + "input_outline_rectangle.png"
	var tex := _load_tex(path)
	if not tex:
		return _fallback_panel_style()

	var sb := StyleBoxTexture.new()
	sb.texture = tex

	sb.texture_margin_left = PANEL_MARGIN
	sb.texture_margin_top = PANEL_MARGIN
	sb.texture_margin_right = PANEL_MARGIN
	sb.texture_margin_bottom = PANEL_MARGIN

	sb.content_margin_left = 20.0
	sb.content_margin_top = 16.0
	sb.content_margin_right = 20.0
	sb.content_margin_bottom = 16.0

	# ダークモード用に暗く
	sb.modulate_color = Color(0.12, 0.14, 0.20, 0.97)

	return sb


## ヘッダー用パネルスタイル
func make_header_panel_style() -> StyleBox:
	var path := PANEL_PATH + "input_rectangle.png"
	var tex := _load_tex(path)
	if not tex:
		return _fallback_panel_style()

	var sb := StyleBoxTexture.new()
	sb.texture = tex

	sb.texture_margin_left = PANEL_MARGIN
	sb.texture_margin_top = PANEL_MARGIN
	sb.texture_margin_right = PANEL_MARGIN
	sb.texture_margin_bottom = PANEL_MARGIN

	sb.content_margin_left = 20.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 20.0
	sb.content_margin_bottom = 10.0

	sb.modulate_color = Color(0.10, 0.11, 0.16, 0.98)

	return sb


## ログエリア用パネルスタイル
func make_log_panel_style() -> StyleBox:
	var path := PANEL_PATH + "input_rectangle.png"
	var tex := _load_tex(path)
	if not tex:
		return _fallback_panel_style()

	var sb := StyleBoxTexture.new()
	sb.texture = tex

	sb.texture_margin_left = PANEL_MARGIN
	sb.texture_margin_top = PANEL_MARGIN
	sb.texture_margin_right = PANEL_MARGIN
	sb.texture_margin_bottom = PANEL_MARGIN

	sb.content_margin_left = 12.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 12.0
	sb.content_margin_bottom = 10.0

	sb.modulate_color = Color(0.08, 0.09, 0.13, 0.95)

	return sb


## アクションボタン用のカラー付きスタイルセット
## returns: { "normal": StyleBox, "hover": StyleBox, "pressed": StyleBox, "disabled": StyleBox }
func make_action_button_styles(color: String = "blue") -> Dictionary:
	return {
		"normal": make_button_style(color, "depth_flat"),
		"hover": make_button_style(color, "depth_flat", Color(1.2, 1.2, 1.3, 1.0)),
		"pressed": make_button_style(color, "flat"),
		"disabled": make_button_style("grey", "depth_flat"),
	}


## ボタンにKenneyスタイルを適用するヘルパー
func apply_button_style(btn: Button, color: String = "blue") -> void:
	var styles := make_action_button_styles(color)
	btn.add_theme_stylebox_override("normal", styles["normal"])
	btn.add_theme_stylebox_override("hover", styles["hover"])
	btn.add_theme_stylebox_override("pressed", styles["pressed"])
	btn.add_theme_stylebox_override("disabled", styles["disabled"])
	# フォーカス枠は透明に
	var focus := StyleBoxEmpty.new()
	btn.add_theme_stylebox_override("focus", focus)
	# disabled時の文字色を全色で視認性の高い暗めグレーに統一
	btn.add_theme_color_override("font_disabled_color", Color(0.40, 0.42, 0.48))
	# 色別の通常文字色
	if color == "grey":
		btn.add_theme_color_override("font_color", Color(0.88, 0.88, 0.92))
	elif color == "yellow":
		btn.add_theme_color_override("font_color", Color(0.15, 0.12, 0.05))


## PanelContainer にKenneyスタイルを適用するヘルパー
func apply_panel_style(panel: PanelContainer, style_type: String = "popup") -> void:
	var sb: StyleBoxTexture
	match style_type:
		"popup":
			sb = make_popup_panel_style()
		"header":
			sb = make_header_panel_style()
		"log":
			sb = make_log_panel_style()
		_:
			sb = make_popup_panel_style()
	panel.add_theme_stylebox_override("panel", sb)


## フォールバック用 StyleBoxFlat（テクスチャが見つからない場合）
func _fallback_button_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.22, 0.24, 0.30, 1.0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.35, 0.38, 0.45, 1.0)
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_right = 10
	sb.corner_radius_bottom_left = 10
	sb.content_margin_left = 20.0
	sb.content_margin_top = 14.0
	sb.content_margin_right = 20.0
	sb.content_margin_bottom = 14.0
	return sb


func _fallback_panel_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.13, 0.16, 1.0)
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = Color(0.25, 0.27, 0.32, 1.0)
	sb.corner_radius_top_left = 12
	sb.corner_radius_top_right = 12
	sb.corner_radius_bottom_right = 12
	sb.corner_radius_bottom_left = 12
	sb.content_margin_left = 16.0
	sb.content_margin_top = 12.0
	sb.content_margin_right = 16.0
	sb.content_margin_bottom = 12.0
	return sb
