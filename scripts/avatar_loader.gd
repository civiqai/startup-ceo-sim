extends Node
## アバター画像ローダー（Autoload シングルトン）
## ローカルのプリメイドキャラクター画像を使用

var _cache: Dictionary = {}  # avatar_id -> Texture2D

const PREMADE_COUNT := 20
const PREMADE_PATH := "res://assets/images/characters/premade/Premade_Character_48x48_%02d.png"


## アバター画像を取得（コールバック形式、互換性維持）
func get_avatar(avatar_id: int, callback: Callable) -> void:
	var tex = get_cached(avatar_id)
	callback.call(tex)


## キャッシュからテクスチャを同期取得（なければロードして返す）
func get_cached(avatar_id: int) -> Texture2D:
	if avatar_id <= 0:
		return null

	if _cache.has(avatar_id):
		return _cache[avatar_id]

	# avatar_idをプリメイド画像にマッピング (1-20にラップ)
	var premade_id: int = ((avatar_id - 1) % PREMADE_COUNT) + 1
	var path := PREMADE_PATH % premade_id
	var tex = load(path)
	if tex:
		_cache[avatar_id] = tex
	return tex


## キャッシュをクリア（デバッグ用）
func clear_cache() -> void:
	_cache.clear()
