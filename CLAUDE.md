# IT社長物語 - AI Development Guide

## Project Overview
IT社長経営シミュレーションゲーム。Godot 4 + GDScript で開発。スマホ(縦画面)対応。

## Game Design

### Core Loop
- ターン制（1ターン = 1ヶ月）
- 毎ターン: イベント発生 → 意思決定 → パラメータ更新 → 結果表示
- ゲームオーバー: 資金ゼロ（倒産）
- ゴール: IPO or 買収（時価総額100億円達成）

### Parameters
- `cash`: 資金（万円） - 初期値 1000万
- `product_power`: プロダクト力 (0-100)
- `team_size`: チーム人数 - 初期値 1（自分のみ）
- `team_morale`: チーム士気 (0-100)
- `users`: ユーザー数
- `reputation`: 投資家からの評判 (0-100)
- `month`: 経過月数

### Actions (毎ターン1つ選択)
- 開発に集中: product_power UP
- 採用: team_size UP, cash DOWN
- マーケティング: users UP, cash DOWN
- 資金調達: cash UP, reputation影響
- チームケア: team_morale UP

### Events (ランダム)
- 競合出現、メディア掲載、メンバー離脱、サーバー障害、大型案件、炎上 等

## Tech Stack
- Engine: Godot 4.3
- Language: GDScript
- Target: Mobile (portrait, 720x1280 base)
- Rendering: Mobile renderer

## Project Structure
```
startup-ceo-sim/
├── project.godot
├── CLAUDE.md              # このファイル
├── scenes/
│   ├── main.tscn          # エントリーポイント（シーン切替管理）
│   ├── title.tscn         # タイトル画面
│   ├── game.tscn          # メインゲーム画面
│   ├── event.tscn         # イベント表示ポップアップ
│   ├── debug_panel.tscn   # デバッグ/テストパネル（バランス調整用）
│   └── result.tscn        # ゲーム結果画面
├── scripts/
│   ├── main.gd            # シーン切替ロジック
│   ├── game_state.gd      # ゲーム状態管理（Autoload singleton）
│   ├── game.gd            # メインゲーム画面のロジック
│   ├── turn_manager.gd    # ターン処理
│   ├── day_cycle.gd       # 24時間サイクル管理（月内の日次シミュレーション）
│   ├── event_manager.gd   # イベント管理
│   ├── debug_panel.gd     # デバッグパネル（パラメータ編集・速度制御・ログ）
│   ├── auto_simulator.gd  # 自動シミュレーション（戦略別統計）
│   ├── balance_logger.gd  # バランスログ（パラメータ履歴・テキストグラフ）
│   ├── fundraise_types.gd  # 資金調達4タイプ定義（マス・効果・ダイスマッピング）
│   ├── fundraise_select_popup.gd  # 資金調達タイプ選択ポップアップ
│   ├── sugoroku_popup.gd  # 双六ポップアップUI（3ダイス・タイプ別ボード）
│   ├── marketing_channels.gd  # マーケティング5チャネル定義（コスト・効果・CMOボーナス）
│   ├── marketing_select_popup.gd  # マーケティングチャネル選択ポップアップ
│   ├── milestone_manager.gd  # マイルストーン管理（達成検知・7種のマイルストーン）
│   ├── milestone_popup.gd    # マイルストーン祝福ポップアップ（紙吹雪演出）
│   ├── secretary_data.gd     # 秘書の台詞データ定義（チュートリアル・アドバイス）
│   ├── secretary_popup.gd    # 秘書ダイアログポップアップ（タイピング演出）
│   ├── save_manager.gd       # セーブ/ロード管理シングルトン（Autoload）
│   ├── save_load_popup.gd    # セーブ/ロードスロット選択ポップアップ
│   ├── achievement_manager.gd # 実績管理（12種、永続保存、報酬システム）
│   ├── achievement_popup.gd  # 実績ポップアップUI（通知・一覧）
│   ├── difficulty_manager.gd # 難易度・チャレンジモード管理（Autoload）
│   ├── ending_manager.gd     # エンディング分岐管理（6種、条件判定）
│   ├── phase_manager.gd      # フェーズ制管理（6段階、昇格条件、アクション解放）
│   ├── product_manager.gd    # プロダクト開発管理（タイプ・機能・技術的負債）
│   ├── product_dev_popup.gd  # プロダクト開発ポップアップUI
│   ├── investor_manager.gd   # 投資家・メンター管理（ボード会議・気分・バフ）
│   ├── competitor_manager.gd # 競合AI・市場シェア管理
│   ├── avatar_loader.gd   # アバター画像ローダー（Autoload、i.pravatar.cc、キャッシュ）
│   ├── team_member.gd     # チームメンバーデータモデル（Resource）
│   ├── team_manager.gd    # チーム管理シングルトン（Autoload）
│   ├── hire_popup.gd      # 採用ポップアップ（チャネル選択・候補者3名・アバター画像）
│   ├── team_list_popup.gd # チーム一覧ポップアップ
│   ├── member_detail_popup.gd  # メンバー詳細・昇進・解雇ポップアップ
│   ├── title.gd           # タイトル画面
│   └── result.gd          # 結果画面
├── resources/
│   ├── events.json        # イベント定義データ
│   └── theme.tres         # UIテーマ
└── assets/
    ├── fonts/
    └── images/
```

## Coding Conventions
- GDScript style guide に準拠: https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html
- 変数名・関数名: snake_case
- クラス名: PascalCase
- シグナル名: past_tense (例: `turn_ended`, `cash_changed`)
- コメントは日本語OK
- シーンファイル (.tscn) はテキスト形式を維持（CLI編集可能にするため）

## GDScript Tips for AI
- `@onready var label = $Label` でノード参照
- `@export var speed: float = 10.0` でエディタ公開
- Autoload は project.godot の [autoload] セクションで登録
- シグナルは `signal name_happened(param)` で定義、`name_happened.emit(param)` で発火
- `.tscn` ファイルは `[gd_scene]` ヘッダで始まるテキスト形式
- モバイルUIは `Control` ノード + アンカー/マージンで配置

## Important Notes
- スマホ縦画面前提（720x1280）
- タッチ操作のみ（キーボード不要）
- テキスト量が多いゲームなので、フォントサイズ・余白に注意
- パフォーマンスより読みやすさ・保守性を優先
