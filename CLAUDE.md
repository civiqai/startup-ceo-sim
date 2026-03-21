# Startup CEO Simulator - AI Development Guide

## Project Overview
スタートアップの社長経営シミュレーションゲーム。Godot 4 + GDScript で開発。スマホ(縦画面)対応。

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
│   ├── event_manager.gd   # イベント管理
│   ├── debug_panel.gd     # デバッグパネル（パラメータ編集・速度制御・ログ）
│   ├── auto_simulator.gd  # 自動シミュレーション（戦略別統計）
│   ├── balance_logger.gd  # バランスログ（パラメータ履歴・テキストグラフ）
│   ├── fundraise_types.gd  # 資金調達4タイプ定義（マス・効果・ダイスマッピング）
│   ├── fundraise_select_popup.gd  # 資金調達タイプ選択ポップアップ
│   ├── sugoroku_popup.gd  # 双六ポップアップUI（3ダイス・タイプ別ボード）
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
