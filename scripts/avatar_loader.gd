extends Node
## アバター画像ローダー（Autoload シングルトン）
## 外部API (i.pravatar.cc) からアバター画像をHTTPで取得し、メモリ＋ディスクキャッシュする

var _cache: Dictionary = {}  # avatar_id -> ImageTexture
var _pending: Dictionary = {}  # avatar_id -> Array[Callable]
var _queue: Array[int] = []  # ダウンロード待ちキュー
var _active_downloads: int = 0

const AVATAR_BASE_URL := "https://i.pravatar.cc/128?img="  # 1-70のIDで固定画像
const MAX_CONCURRENT := 3
const CACHE_DIR := "user://avatars/"
const TIMEOUT := 10.0


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(CACHE_DIR):
		DirAccess.make_dir_recursive_absolute(CACHE_DIR)


## アバター画像を取得（キャッシュヒットなら即座にコールバック）
func get_avatar(avatar_id: int, callback: Callable) -> void:
	if avatar_id <= 0 or avatar_id > 70:
		callback.call(null)
		return

	# メモリキャッシュチェック
	if _cache.has(avatar_id):
		callback.call(_cache[avatar_id])
		return

	# ディスクキャッシュチェック
	var disk_path := CACHE_DIR + "avatar_%d.png" % avatar_id
	if FileAccess.file_exists(disk_path):
		var img := Image.new()
		if img.load(disk_path) == OK:
			var tex := ImageTexture.create_from_image(img)
			_cache[avatar_id] = tex
			callback.call(tex)
			return

	# ペンディングキューに追加
	if _pending.has(avatar_id):
		_pending[avatar_id].append(callback)
		return

	_pending[avatar_id] = [callback]
	_queue.append(avatar_id)
	_process_queue()


## キャッシュからテクスチャを同期取得（なければnull）
func get_cached(avatar_id: int) -> ImageTexture:
	if _cache.has(avatar_id):
		return _cache[avatar_id]
	# ディスクキャッシュもチェック
	var disk_path := CACHE_DIR + "avatar_%d.png" % avatar_id
	if FileAccess.file_exists(disk_path):
		var img := Image.new()
		if img.load(disk_path) == OK:
			var tex := ImageTexture.create_from_image(img)
			_cache[avatar_id] = tex
			return tex
	return null


## ダウンロードキューを処理
func _process_queue() -> void:
	while _active_downloads < MAX_CONCURRENT and not _queue.is_empty():
		var avatar_id: int = _queue.pop_front()
		_start_download(avatar_id)


func _start_download(avatar_id: int) -> void:
	_active_downloads += 1
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var url := AVATAR_BASE_URL + str(avatar_id)
	http.request_completed.connect(_on_download_completed.bind(avatar_id, http))
	var err := http.request(url)
	if err != OK:
		_active_downloads -= 1
		http.queue_free()
		_resolve_pending(avatar_id, null)
		_process_queue()


func _on_download_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, avatar_id: int, http: HTTPRequest) -> void:
	http.queue_free()
	_active_downloads -= 1

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("AvatarLoader: ダウンロード失敗 avatar_id=%d result=%d code=%d" % [avatar_id, result, response_code])
		_resolve_pending(avatar_id, null)
		_process_queue()
		return

	var img := Image.new()
	# pravatar.cc はJPEGを返す
	var err := img.load_jpg_from_buffer(body)
	if err != OK:
		# PNGも試す
		err = img.load_png_from_buffer(body)
	if err != OK:
		push_warning("AvatarLoader: 画像デコード失敗 avatar_id=%d" % avatar_id)
		_resolve_pending(avatar_id, null)
		_process_queue()
		return

	# ディスクキャッシュに保存
	img.save_png(CACHE_DIR + "avatar_%d.png" % avatar_id)

	var tex := ImageTexture.create_from_image(img)
	_cache[avatar_id] = tex
	_resolve_pending(avatar_id, tex)
	_process_queue()


func _resolve_pending(avatar_id: int, tex: Variant) -> void:
	if _pending.has(avatar_id):
		for cb: Callable in _pending[avatar_id]:
			if cb.is_valid():
				cb.call(tex)
		_pending.erase(avatar_id)


## キャッシュをクリア（デバッグ用）
func clear_cache() -> void:
	_cache.clear()
	var dir := DirAccess.open(CACHE_DIR)
	if dir:
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".png"):
				dir.remove(file_name)
			file_name = dir.get_next()
		dir.list_dir_end()
