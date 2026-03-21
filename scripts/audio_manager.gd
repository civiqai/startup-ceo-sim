extends Node
## オーディオ管理シングルトン (Autoload)
## BGM再生、効果音再生、BGMクロスフェードを管理

# BGMトラック定義
const BGM_TRACKS := {
	"title": "res://assets/audio/title_bgm.wav",
	"game": "res://assets/audio/game_bgm.wav",
	"win": "res://assets/audio/win_bgm.wav",
	"lose": "res://assets/audio/lose_bgm.wav",
}

# SFX定義
const SFX_SOUNDS := {
	"click": "res://assets/audio/click.wav",
	"notification": "res://assets/audio/notification.wav",
	"turn_advance": "res://assets/audio/turn_advance.wav",
}

# BGM用AudioStreamPlayer（2つでクロスフェード）
var bgm_player_a: AudioStreamPlayer
var bgm_player_b: AudioStreamPlayer
var active_bgm_player: AudioStreamPlayer

# SFX用AudioStreamPlayer（複数同時再生対応）
var sfx_players: Array[AudioStreamPlayer] = []
const MAX_SFX_PLAYERS := 4

# BGM設定
var bgm_volume_db: float = -6.0
var sfx_volume_db: float = 0.0
var crossfade_duration: float = 0.8
var current_bgm_track: String = ""

# クロスフェード用Tween
var crossfade_tween: Tween


func _ready() -> void:
	# BGMプレイヤー作成
	bgm_player_a = AudioStreamPlayer.new()
	bgm_player_a.bus = "Master"
	bgm_player_a.volume_db = bgm_volume_db
	add_child(bgm_player_a)

	bgm_player_b = AudioStreamPlayer.new()
	bgm_player_b.bus = "Master"
	bgm_player_b.volume_db = -80.0  # ミュート状態
	add_child(bgm_player_b)

	active_bgm_player = bgm_player_a

	# SFXプレイヤー作成
	for i in MAX_SFX_PLAYERS:
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		player.volume_db = sfx_volume_db
		add_child(player)
		sfx_players.append(player)


## BGMを再生（クロスフェード付き）
func play_bgm(track_name: String) -> void:
	if track_name == current_bgm_track:
		return

	if track_name not in BGM_TRACKS:
		push_warning("AudioManager: unknown BGM track '%s'" % track_name)
		return

	current_bgm_track = track_name
	var path = BGM_TRACKS[track_name]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: BGM file not found '%s'" % path)
		return
	var stream = load(path)
	if not stream:
		push_warning("AudioManager: failed to load BGM '%s'" % track_name)
		return

	# ループ設定（winとloseはループしない）
	var should_loop = track_name in ["title", "game"]

	# クロスフェード
	var old_player = active_bgm_player
	var new_player = bgm_player_b if active_bgm_player == bgm_player_a else bgm_player_a
	active_bgm_player = new_player

	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()

	# 前のTweenをキャンセル
	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()

	crossfade_tween = create_tween()
	crossfade_tween.set_parallel(true)

	# 新しいプレイヤーをフェードイン
	crossfade_tween.tween_property(new_player, "volume_db", bgm_volume_db, crossfade_duration)
	# 古いプレイヤーをフェードアウト
	crossfade_tween.tween_property(old_player, "volume_db", -80.0, crossfade_duration)

	# フェードアウト完了後に古いプレイヤーを停止
	crossfade_tween.set_parallel(false)
	crossfade_tween.tween_callback(old_player.stop)

	# ループ処理
	if should_loop:
		if not new_player.finished.is_connected(_on_bgm_loop):
			new_player.finished.connect(_on_bgm_loop.bind(new_player), CONNECT_ONE_SHOT)


## BGMのループ処理
func _on_bgm_loop(player: AudioStreamPlayer) -> void:
	if player == active_bgm_player and player.stream:
		player.play()
		# 次のループ用にも接続
		var track = current_bgm_track
		if track in ["title", "game"]:
			player.finished.connect(_on_bgm_loop.bind(player), CONNECT_ONE_SHOT)


## BGMを停止
func stop_bgm() -> void:
	current_bgm_track = ""

	if crossfade_tween and crossfade_tween.is_valid():
		crossfade_tween.kill()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(bgm_player_a, "volume_db", -80.0, 0.5)
	tween.tween_property(bgm_player_b, "volume_db", -80.0, 0.5)
	tween.set_parallel(false)
	tween.tween_callback(bgm_player_a.stop)
	tween.tween_callback(bgm_player_b.stop)


## 効果音を再生
func play_sfx(sfx_name: String) -> void:
	if sfx_name not in SFX_SOUNDS:
		push_warning("AudioManager: unknown SFX '%s'" % sfx_name)
		return

	var path = SFX_SOUNDS[sfx_name]
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: SFX file not found '%s'" % path)
		return
	var stream = load(path)
	if not stream:
		push_warning("AudioManager: failed to load SFX '%s'" % sfx_name)
		return

	# 空いているプレイヤーを探す
	for player in sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = sfx_volume_db
			player.play()
			return

	# 全て使用中なら最初のプレイヤーを再利用
	sfx_players[0].stream = stream
	sfx_players[0].volume_db = sfx_volume_db
	sfx_players[0].play()


## BGM音量を設定 (0.0 ~ 1.0)
func set_bgm_volume(volume: float) -> void:
	bgm_volume_db = linear_to_db(clampf(volume, 0.0, 1.0))
	active_bgm_player.volume_db = bgm_volume_db


## SFX音量を設定 (0.0 ~ 1.0)
func set_sfx_volume(volume: float) -> void:
	sfx_volume_db = linear_to_db(clampf(volume, 0.0, 1.0))
