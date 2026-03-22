# オフィスカスタマイズ機能 ロードマップ

## 概要

オフィスをタイルマップベースの2D空間にリニューアルし、家具の購入・配置・アップグレードによるカスタマイズ要素を追加する。家具にはステータス効果があり、経営に直接影響する。ターン制のゲームループとは独立した「いつでも触れる」要素として実装する。

---

## 技術方針

### TileMap方式（推奨）

Godot 4のTileMapレイヤーを使用。床・壁をタイルで構築し、家具はSprite2Dノードとしてグリッドスナップ配置する。

- **床・壁**: TileMapレイヤー（Room_Builder_32x32のFloors/Wallsを使用）
- **家具**: Sprite2Dノード（グリッドスナップ）。Singles画像やTinyHouseの個別PNGを使用
- **カメラ**: Camera2D（ピンチズーム + スワイプパン）
- **タイルサイズ**: 32x32px

**Godot 4との相性**: TileMapは Godot 4のコア機能。TileMapLayerノードで複数レイヤー（床、壁、装飾）を管理できる。タイルセットエディタでアトラステクスチャからタイルを切り出せる。

### ゾーン方式（フォールバック）

TileMapが複雑すぎる場合の代替案。部屋をゾーン（デスクエリア、ラウンジ、サーバールーム等）に分割し、各ゾーンに固定スロットを設ける。スロットに家具をはめ込む形式。

- 実装が単純（UIベースで完結）
- 自由度は低いが、ゲーム体験としては十分機能する
- 現在のControl + _draw()ベースを拡張して実装可能

---

## 利用可能アセット

### Modern Interiors（メイン）
- `1_Interiors/32x32/Room_Builder_32x32.png` — 床・壁タイル（2432x3616px）
  - サブファイル: Floors, Walls, Shadows, Borders 等に分割済み
- `1_Interiors/32x32/Theme_Sorter_Singles_32x32/` — 家具の個別スプライト
  - Conference_Hall: 会議テーブル、椅子、ホワイトボード等
  - Generic: 汎用家具
  - Classroom_and_Library: 本棚、デスク等
- `3_Animated_objects/32x32/spritesheets/` — アニメーション付きオブジェクト
- `1_Interiors/32x32/Interiors_32x32.png` — 全家具の統合スプライトシート（512x34048px）

### TinyHouse（補完・モダン家具）
- `PC/` — iMac、曲面ディスプレイ、キーボード、ゲーミングPC等
- `Desk/` — デスク
- `Chair/`, `Gaming Chair/` — 椅子類
- `Plants/` — 観葉植物
- `Poster/` — ポスター
- `MacBook_Ani/`, `BendedScreen_Ani/`, `PC_Tower_Ani/` — アニメーション付きPC
- `Foor-Wall Tiles 32px/` — 床・壁タイル（32px版あり）
- タイルサイズ: 32px版あり、互換性◎

### MiniWorld（外観・建物用）
- `Buildings/` — オフィスビル外観（将来的にオフィス選択画面で使用可能）
- `Objects/` — 小物
- 内装向きではないが、外観演出に使える

---

## 家具データ（30種）

### カテゴリ1: デスク・ワークステーション（6種）

| ID | 名前 | コスト(万) | 効果 | 説明 |
|----|------|-----------|------|------|
| desk_basic | 折りたたみデスク | 5 | product_power +1 | 最低限の作業スペース |
| desk_standing | スタンディングデスク | 30 | product_power +2, team_morale +2 | 健康的な働き方 |
| desk_executive | エグゼクティブデスク | 80 | reputation +3, team_morale +1 | 投資家受けが良い |
| monitor_hd | HDモニター | 15 | product_power +2 | デュアルディスプレイで効率UP |
| monitor_4k | 4Kモニター | 50 | product_power +4, design_bonus +5 | デザイン品質が向上 |
| monitor_ultrawide | ウルトラワイドモニター | 100 | product_power +6, design_bonus +8 | 圧倒的作業効率 |

### カテゴリ2: 会議・コミュニケーション（5種）

| ID | 名前 | コスト(万) | 効果 | 説明 |
|----|------|-----------|------|------|
| whiteboard | ホワイトボード | 10 | product_power +1, team_morale +1 | アイデア出しに必須 |
| meeting_table | ミーティングテーブル | 40 | team_morale +3, reputation +2 | チーム連携が向上 |
| projector | プロジェクター | 60 | reputation +4, marketing_bonus +3 | プレゼン力UP |
| video_conf | ビデオ会議システム | 80 | reputation +3, team_morale +2 | リモートワーク対応 |
| phone_booth | 集中ブース | 50 | product_power +3 | 集中できる個室スペース |

### カテゴリ3: インフラ・サーバー（5種）

| ID | 名前 | コスト(万) | 効果 | 説明 |
|----|------|-----------|------|------|
| router_basic | Wi-Fiルーター | 5 | incident_reduction -5% | 通信障害を軽減 |
| server_rack | サーバーラック | 100 | incident_reduction -15%, product_power +3 | インフラ安定化 |
| ups_battery | 無停電電源装置(UPS) | 40 | incident_reduction -10% | 停電対策 |
| firewall | ファイアウォール装置 | 70 | incident_reduction -20%, reputation +2 | セキュリティ強化 |
| nas_storage | NASストレージ | 50 | incident_reduction -8%, product_power +2 | データバックアップ |

### カテゴリ4: 快適性・福利厚生（6種）

| ID | 名前 | コスト(万) | 効果 | 説明 |
|----|------|-----------|------|------|
| plant_small | 小さな観葉植物 | 3 | team_morale +1 | 癒しの緑 |
| plant_large | 大きな観葉植物 | 15 | team_morale +3 | オフィスの雰囲気UP |
| coffee_machine | コーヒーマシン | 20 | team_morale +3, product_power +1 | カフェイン駆動開発 |
| snack_bar | スナックバー | 30 | team_morale +4 | 小腹を満たす |
| nap_space | 仮眠スペース | 60 | team_morale +5, incident_reduction -5% | 疲労回復で事故も減る |
| game_corner | ゲームコーナー | 45 | team_morale +6, product_power -1 | 楽しいが少し生産性低下 |

### カテゴリ5: インテリア・装飾（5種）

| ID | 名前 | コスト(万) | 効果 | 説明 |
|----|------|-----------|------|------|
| poster_motivational | モチベーションポスター | 5 | team_morale +1 | "Stay Hungry, Stay Foolish" |
| portrait_jobs | ジョブズの肖像画 | 50 | product_power +3, reputation +2 | Think Different の精神 |
| portrait_bezos | ベゾスの肖像画 | 50 | marketing_bonus +5, reputation +2 | 顧客第一主義 |
| bookshelf | 技術書棚 | 25 | product_power +2, team_morale +1 | チームのスキルアップ |
| award_trophy | 受賞トロフィー | 100 | reputation +8 | スタートアップアワード受賞 |

### カテゴリ6: 特殊・レア（3種）

| ID | 名前 | コスト(万) | 効果 | 説明 |
|----|------|-----------|------|------|
| ping_pong | 卓球台 | 35 | team_morale +5, reputation +1 | シリコンバレー定番 |
| aquarium | アクアリウム | 80 | team_morale +4, reputation +3 | 高級感と癒し |
| massage_chair | マッサージチェア | 120 | team_morale +7, incident_reduction -3% | 究極のリラクゼーション |

---

## ステータス効果の仕組み

家具の効果はオフィスに配置されている間、**常時バフ**として適用される。

```
# 効果タイプ
- product_power: プロダクト力への加算ボーナス（毎ターン）
- team_morale: チーム士気への加算ボーナス（上限キャップ）
- reputation: 投資家評判への加算ボーナス
- incident_reduction: インシデント発生確率の減少（%）
- marketing_bonus: マーケティング効果の倍率加算
- design_bonus: デザイン系プロダクト値への加算
```

---

## フェーズ分け実装計画

### Phase 1: 基盤（TileMap + Camera2D） ✅ 2026-03-22 実装完了
- [x] TileMapシーンのセットアップ（床・壁タイルセット作成） → `scripts/office_tilemap.gd`
- [x] Camera2Dの実装（スワイプパン + ピンチズーム） → `scripts/office_camera.gd`
- [x] 初期オフィスレイアウトの作成（フェーズ別6段階の部屋サイズ）
- [x] 既存のoffice_view.gdからの移行（ステータス表示はUI Overlayに分離） → `scripts/office_ui_overlay.gd`
- [x] メンバーのスプライト表示（TileMap上にNode2Dとして配置、タップ検知付き）
- [x] game.gd / game.tscn への統合（SubViewportContainer経由、旧OfficeViewとの切替対応）
- [x] アセット配置: `assets/images/tiles/` (床・壁タイル), `assets/images/furniture/` (家具スプライト)

### Phase 2: 家具ショップ & 配置
- [ ] 家具データ定義（furniture_data.gd）
- [ ] ショップUI（カテゴリ別表示、購入確認）
- [ ] 家具配置モード（グリッドスナップ、配置可能判定）
- [ ] 配置済み家具のタップ→詳細表示
- [ ] セーブ/ロード対応（配置データの永続化）

### Phase 3: ステータス効果
- [ ] 家具効果の集計システム（office_buff_manager.gd）
- [ ] 既存のゲームループへの効果反映
- [ ] 効果一覧の表示UI
- [ ] 家具アップグレードシステム（HDモニター→4K→ウルトラワイド）

### Phase 4: 演出・ポリッシュ
- [ ] 家具のアニメーション（Animated_objectsの活用）
- [ ] メンバーが家具の近くで作業するアニメーション
- [ ] 購入時・配置時のエフェクト
- [ ] BGM/SE対応

### Phase 5: エリア拡張
- [ ] 部屋サイズの拡張購入（初期3x3 → 5x5 → 8x8 等）
- [ ] 新エリアの解放（サーバールーム、休憩室、会議室等）
- [ ] エリアごとの特殊効果
- [ ] フェーズ連動（チーム規模に応じて拡張可能に）

---

## シーン構成案（TileMap方式）

```
OfficeScene (Node2D)
├── Camera2D                    # スワイプ・ズーム対応
├── TileMapLayer (Floor)        # 床タイル
├── TileMapLayer (Walls)        # 壁タイル
├── FurnitureContainer (Node2D) # 配置済み家具の親ノード
│   ├── Furniture_001 (Sprite2D + Area2D)
│   ├── Furniture_002 (Sprite2D + Area2D)
│   └── ...
├── MemberContainer (Node2D)    # メンバースプライト
│   ├── Member_CEO (Sprite2D)
│   ├── Member_001 (Sprite2D)
│   └── ...
└── UIOverlay (CanvasLayer)     # ステータス表示（カメラに追従しない）
    ├── StatusBar
    ├── ShopButton
    └── EditModeButton
```

---

## 技術的な注意点

1. **パフォーマンス**: モバイル端末ではTileMapの描画範囲を制限する。Camera2Dのlimitを活用
2. **入力の競合**: オフィス画面のスワイプと、下部のゲームUI操作の競合を避ける設計が必要
3. **既存システムとの統合**: 現在のoffice_view.gdの`_draw()`ベース描画からNode2Dベースへの移行が必要。段階的に移行する
4. **タイルサイズ統一**: Modern Interiors (32px) と TinyHouse (32px版あり) は互換性あり。MiniWorldは別スケールなので内装には使わない
