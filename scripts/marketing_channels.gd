extends RefCounted
## マーケティングチャネル定義（10チャネル）
## コスト帯: 30 → 100 → 300 → 500 → 800 → 1500 → 2000 → 5000 → 10000 → 30000万円

const CHANNELS := [
	{
		"id": "content",
		"name": "コンテンツマーケ",
		"icon": "📝",
		"description": "ブログやSNS投稿でじわじわ浸透。低コストでブランド向上。",
		"color": Color(0.40, 0.75, 0.45),
		"cost": 30,
		"phase": 0,
	},
	{
		"id": "sns_ads",
		"name": "SNS広告",
		"icon": "📱",
		"description": "ターゲティング広告で即効ユーザー獲得。手軽に始められる。",
		"color": Color(0.30, 0.60, 0.90),
		"cost": 100,
		"phase": 0,
	},
	{
		"id": "influencer",
		"name": "インフルエンサー施策",
		"icon": "⭐",
		"description": "人気インフルエンサーに依頼。バズれば大当たり、外れもある。",
		"color": Color(0.90, 0.35, 0.45),
		"cost": 300,
		"phase": 0,
	},
	{
		"id": "conference",
		"name": "カンファレンス出展",
		"icon": "🎤",
		"description": "業界カンファレンスに出展。BtoBリード獲得と評判UP。",
		"color": Color(0.85, 0.55, 0.20),
		"cost": 500,
		"phase": 1,
	},
	{
		"id": "seo",
		"name": "SEO対策",
		"icon": "🔍",
		"description": "検索上位を狙う本格施策。時間はかかるが、安定した流入が続く。",
		"color": Color(0.35, 0.70, 0.65),
		"cost": 800,
		"phase": 1,
	},
	{
		"id": "truck_ad",
		"name": "トラック広告",
		"icon": "🚚",
		"description": "アドトラックで都心を走る。話題性抜群でブランド急上昇。",
		"color": Color(0.65, 0.50, 0.80),
		"cost": 1500,
		"phase": 2,
	},
	{
		"id": "pr_media",
		"name": "PR/メディア掲載",
		"icon": "📺",
		"description": "大手メディアへの露出。評判・ブランド・ユーザー全方位に効く。",
		"color": Color(0.70, 0.40, 0.75),
		"cost": 2000,
		"phase": 2,
	},
	{
		"id": "tv_cm",
		"name": "テレビCM",
		"icon": "📡",
		"description": "全国放送のテレビCM。莫大なコストだが効果は絶大。一気に知名度爆上げ。",
		"color": Color(0.95, 0.65, 0.15),
		"cost": 5000,
		"phase": 3,
	},
	{
		"id": "stadium_naming",
		"name": "スタジアム命名権",
		"icon": "🏟️",
		"description": "スタジアムに社名を冠する。圧倒的な知名度とブランド力。長期契約で持続効果あり。",
		"color": Color(0.25, 0.50, 0.85),
		"cost": 10000,
		"phase": 3,
	},
	{
		"id": "superbowl_cm",
		"name": "スーパーボウルCM",
		"icon": "🏈",
		"description": "世界最大の広告枠。3億円の究極の賭け。成功すれば歴史に残る。",
		"color": Color(0.95, 0.30, 0.30),
		"cost": 30000,
		"phase": 4,
	},
]


static func get_all_channels() -> Array:
	return CHANNELS


static func get_channel(channel_id: String) -> Dictionary:
	for ch in CHANNELS:
		if ch["id"] == channel_id:
			return ch
	return {}


static func is_available(channel_id: String, gs) -> bool:
	var ch := get_channel(channel_id)
	if ch.is_empty():
		return false
	if gs.current_phase < ch.get("phase", 0):
		return false
	return gs.cash >= ch["cost"]


## フェーズ解放済みかどうかのみ判定（資金チェックなし）
static func is_phase_unlocked(channel_id: String, gs) -> bool:
	var ch := get_channel(channel_id)
	if ch.is_empty():
		return false
	return gs.current_phase >= ch.get("phase", 0)


## マーケティング効果を適用し、結果辞書を返す
## 返り値: { title, description, effect_text, rating }
## gs: GameState, TeamManager はAutoloadとしてアクセス
static func apply_effect(channel_id: String, gs) -> Dictionary:
	var ch := get_channel(channel_id)
	if ch.is_empty():
		return {"title": "エラー", "description": "不明なチャネル", "effect_text": "", "rating": ""}

	# コスト支払い
	var cost: int = ch["cost"]
	gs.cash -= cost

	# チャネル使用回数を記録 & 疲労係数を計算
	var use_count: int = gs.marketing_channel_counts.get(channel_id, 0)
	gs.marketing_channel_counts[channel_id] = use_count + 1
	# 同チャネル連続使用で効率低下: 1回目=100%, 3回目=69%, 5回目=57%, 10回目=40%
	var channel_fatigue: float = 1.0 / (1.0 + use_count * 0.15)

	# マーケタースキルボーナス（0〜数十程度）
	var skill_bonus: int = TeamManager.get_skill_bonus("marketer")
	# CMOがいれば効率2倍
	var cmo_multiplier: float = 2.0 if TeamManager.has_cxo("marketer") else 1.0
	# プロダクト力によるユーザー獲得倍率（0.5〜1.5）
	var product_factor: float = 0.5 + (gs.product_power / 100.0)
	# 総合倍率（チャネル疲労を適用）
	var effectiveness: float = (1.0 + skill_bonus * 0.1) * cmo_multiplier * channel_fatigue

	var users_gained: int = 0
	var brand_gained: int = 0
	var reputation_gained: int = 0
	var morale_gained: int = 0
	var narrative: String = ""
	var rating: String = ""  # 大成功/成功/普通/いまいち

	match channel_id:
		"content":
			# 30万: ブランド多め、ユーザー少なめ、じわじわ系
			var base_brand := randi_range(3, 8)
			brand_gained = int(base_brand * effectiveness)
			users_gained = int(randi_range(15, 40) * product_factor * effectiveness)
			narrative = "技術ブログとSNS投稿を公開。じわじわと認知が広がっていく。"
			rating = "成功" if brand_gained >= 5 else "普通"

		"sns_ads":
			# 100万: ユーザー獲得の基本手段
			var base_users := randi_range(60, 220)
			users_gained = int(base_users * product_factor * effectiveness)
			brand_gained = int(randi_range(1, 4) * effectiveness)
			if base_users >= 180:
				narrative = "SNS広告が想定以上にヒット！クリック率が高く、効率よくユーザーを獲得できた。"
				rating = "大成功"
			elif base_users >= 120:
				narrative = "SNS広告を出稿。ターゲティングが効いて、堅実にユーザーを獲得。"
				rating = "成功"
			else:
				narrative = "SNS広告を出稿したが、反応は薄め。競合の広告に埋もれてしまった感も…"
				rating = "いまいち"

		"influencer":
			# 300万: ハイリスク・ハイリターン（25%で大バズ、25%で空振り）
			var roll := randi_range(1, 100)
			if roll <= 25:
				users_gained = int(randi_range(600, 1200) * product_factor * effectiveness)
				brand_gained = int(randi_range(12, 25) * effectiveness)
				narrative = "インフルエンサーの投稿が大バズり！リポストの嵐でトレンド入りした！"
				rating = "大成功"
			elif roll <= 75:
				users_gained = int(randi_range(100, 300) * product_factor * effectiveness)
				brand_gained = int(randi_range(3, 8) * effectiveness)
				narrative = "インフルエンサーが紹介してくれた。フォロワーからの反応はそこそこ。"
				rating = "成功"
			else:
				users_gained = int(randi_range(20, 60) * product_factor * effectiveness)
				brand_gained = int(randi_range(1, 3) * effectiveness)
				narrative = "インフルエンサーの投稿が埋もれてしまった…タイミングが悪かったか。"
				rating = "いまいち"

		"conference":
			# 500万: BtoBリード + 評判 + 士気
			var base_users := randi_range(80, 300)
			users_gained = int(base_users * product_factor * effectiveness)
			reputation_gained = int(randi_range(6, 18) * effectiveness)
			morale_gained = int(randi_range(3, 8) * effectiveness)
			if base_users >= 230:
				narrative = "カンファレンスで登壇が大好評！名刺交換の列が途切れない盛況ぶり。"
				rating = "大成功"
			elif base_users >= 150:
				narrative = "カンファレンスに出展。業界関係者との交流で手応えを得た。"
				rating = "成功"
			else:
				narrative = "カンファレンスに出展したが、ブースへの来場者は少なめだった。"
				rating = "普通"

		"seo":
			# 800万: 安定ユーザー流入 + ブランド。即効性は低いが堅実
			var base_users := randi_range(100, 350)
			users_gained = int(base_users * product_factor * effectiveness)
			brand_gained = int(randi_range(4, 12) * effectiveness)
			if base_users >= 280:
				narrative = "SEO施策が的中！検索1位を獲得し、オーガニック流入が急増した！"
				rating = "大成功"
			elif base_users >= 180:
				narrative = "SEO対策の効果が出始めた。検索順位が着実に上昇中。"
				rating = "成功"
			else:
				narrative = "SEO対策を実施したが、競合が強く検索順位はまだ伸び悩んでいる。"
				rating = "普通"

		"truck_ad":
			# 1500万: 話題性でブランド急上昇 + ユーザーもそこそこ
			var brand_roll := randi_range(8, 28)
			brand_gained = int(brand_roll * effectiveness)
			users_gained = int(randi_range(250, 800) * product_factor * effectiveness)
			morale_gained = int(randi_range(2, 6) * effectiveness)
			if brand_roll >= 22:
				narrative = "アドトラックがSNSで大拡散！「あのトラック見た！」の投稿が溢れている！"
				rating = "大成功"
			elif brand_roll >= 15:
				narrative = "アドトラックが都心を走行。街行く人の視線を集め、話題に。"
				rating = "成功"
			else:
				narrative = "アドトラックを走らせたが、渋滞で目立たなかった…"
				rating = "いまいち"

		"pr_media":
			# 2000万: 全方位に効く大型施策
			var rep_roll := randi_range(8, 28)
			reputation_gained = int(rep_roll * effectiveness)
			brand_gained = int(randi_range(8, 22) * effectiveness)
			users_gained = int(randi_range(300, 1000) * product_factor * effectiveness)
			if rep_roll >= 22:
				narrative = "大手メディアの一面特集に！「次のユニコーン候補」と紹介された！"
				rating = "大成功"
			elif rep_roll >= 15:
				narrative = "大手メディアに取り上げられた。記事の反響は上々。"
				rating = "成功"
			else:
				narrative = "メディアに掲載されたが、小さな記事で反響は限定的だった。"
				rating = "普通"

		"tv_cm":
			# 5000万: 効果絶大。大きな振れ幅あり
			var cm_roll := randi_range(1, 100)
			if cm_roll <= 30:
				users_gained = int(randi_range(4000, 8000) * product_factor * effectiveness)
				brand_gained = int(randi_range(20, 35) * effectiveness)
				reputation_gained = int(randi_range(10, 20) * effectiveness)
				morale_gained = int(randi_range(8, 15) * effectiveness)
				narrative = "テレビCMが大反響！放送直後からアクセスが殺到し、サーバーが悲鳴を上げるほど！"
				rating = "大成功"
			elif cm_roll <= 75:
				users_gained = int(randi_range(2000, 4000) * product_factor * effectiveness)
				brand_gained = int(randi_range(12, 20) * effectiveness)
				reputation_gained = int(randi_range(5, 12) * effectiveness)
				morale_gained = int(randi_range(4, 8) * effectiveness)
				narrative = "テレビCMが全国放送。知名度が着実にアップした。"
				rating = "成功"
			else:
				users_gained = int(randi_range(800, 1500) * product_factor * effectiveness)
				brand_gained = int(randi_range(5, 10) * effectiveness)
				reputation_gained = int(randi_range(2, 6) * effectiveness)
				morale_gained = int(randi_range(1, 3) * effectiveness)
				narrative = "テレビCMを放送したが、裏番組が強すぎて視聴率が伸びなかった…"
				rating = "いまいち"

		"stadium_naming":
			# 1億: ブランド＋評判の長期大型施策
			var naming_roll := randi_range(1, 100)
			if naming_roll <= 30:
				brand_gained = int(randi_range(25, 40) * effectiveness)
				reputation_gained = int(randi_range(15, 25) * effectiveness)
				users_gained = int(randi_range(2000, 5000) * product_factor * effectiveness)
				morale_gained = int(randi_range(8, 15) * effectiveness)
				narrative = "スタジアム命名権が大きな話題に！試合中継のたびに社名が全国に届く！"
				rating = "大成功"
			elif naming_roll <= 70:
				brand_gained = int(randi_range(15, 25) * effectiveness)
				reputation_gained = int(randi_range(8, 15) * effectiveness)
				users_gained = int(randi_range(800, 2000) * product_factor * effectiveness)
				morale_gained = int(randi_range(4, 8) * effectiveness)
				narrative = "スタジアムに社名が輝く。来場者の目に触れ、着実にブランドが浸透。"
				rating = "成功"
			else:
				brand_gained = int(randi_range(6, 12) * effectiveness)
				reputation_gained = int(randi_range(3, 8) * effectiveness)
				users_gained = int(randi_range(300, 800) * product_factor * effectiveness)
				narrative = "スタジアム命名権を取得したが、チームが不振でメディア露出が少なかった…"
				rating = "いまいち"

		"superbowl_cm":
			# 3億: 究極の賭け。3段階の結果
			var sb_roll := randi_range(1, 100)
			if sb_roll <= 30:
				users_gained = int(randi_range(30000, 60000) * product_factor * effectiveness)
				brand_gained = int(randi_range(40, 55) * effectiveness)
				reputation_gained = int(randi_range(25, 40) * effectiveness)
				morale_gained = int(randi_range(12, 20) * effectiveness)
				narrative = "スーパーボウルCMが世界中でバイラル化！歴代ベストCMランキング入りし、歴史に名を刻んだ！"
				rating = "大成功"
			elif sb_roll <= 65:
				users_gained = int(randi_range(10000, 25000) * product_factor * effectiveness)
				brand_gained = int(randi_range(20, 35) * effectiveness)
				reputation_gained = int(randi_range(12, 22) * effectiveness)
				morale_gained = int(randi_range(6, 12) * effectiveness)
				narrative = "スーパーボウルCM、好評を博す。世界的な知名度を獲得した。"
				rating = "成功"
			else:
				users_gained = int(randi_range(3000, 8000) * product_factor * effectiveness)
				brand_gained = int(randi_range(8, 15) * effectiveness)
				reputation_gained = int(randi_range(3, 8) * effectiveness)
				narrative = "スーパーボウルCMは不発…「よくわからなかった」との声が。3億円が重くのしかかる。"
				rating = "いまいち"

	# 効果を適用（上限チェック付き）
	gs.users += users_gained
	gs.brand_value = mini(gs.brand_value + brand_gained, 100)
	gs.reputation = mini(gs.reputation + reputation_gained, 100)
	gs.team_morale = mini(gs.team_morale + morale_gained, 100)

	# 効果テキストを構築（変化量を明示）
	var effects := []
	if users_gained > 0:
		effects.append("👥 ユーザー +%s人" % _format_number(users_gained))
	if brand_gained > 0:
		effects.append("🏷️ ブランド +%d" % brand_gained)
	if reputation_gained > 0:
		effects.append("📊 評判 +%d" % reputation_gained)
	if morale_gained > 0:
		effects.append("💪 士気 +%d" % morale_gained)
	var effect_text := "\n".join(effects)

	# 評価に応じたアイコン
	var rating_icons := {"大成功": "🎉", "成功": "✅", "普通": "➡️", "いまいち": "😥"}
	var rating_icon: String = rating_icons.get(rating, "")

	return {
		"channel_name": ch["name"],
		"channel_icon": ch["icon"],
		"cost": cost,
		"title": "%s %s（%s%s）" % [ch["icon"], ch["name"], rating_icon, rating],
		"description": narrative,
		"effect_text": effect_text,
		"rating": rating,
		"users_gained": users_gained,
		"brand_gained": brand_gained,
		"reputation_gained": reputation_gained,
		"morale_gained": morale_gained,
	}


static func _format_number(n: int) -> String:
	if n >= 10000:
		return "%s万%s" % [str(n / 10000), "" if n % 10000 == 0 else str(n % 10000)]
	return str(n)
