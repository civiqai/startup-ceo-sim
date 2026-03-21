# 効果音・BGM フリー素材リファレンス

## おすすめ戦略

### 効果音 (SE)
1. **Kenney.nl** (CC0, 帰属不要) — UI音が高品質
2. **効果音ラボ** (soundeffect-lab.info, 帰属不要) — 日本語サイト、網羅的
3. **freesound.org** (CC0フィルター) — サイコロ音など特殊音

### BGM
1. **DOVA-SYNDROME** (dova-s.jp, 帰属不要) — 大量・高品質
2. **Pixabay Music** (pixabay.com/music/, 帰属不要) — ムード別に探しやすい
3. **甘茶の音楽工房** (amachamusic.chagasi.com, 帰属不要) — 安定品質

---

## 必要な音の一覧

### SE
| 用途 | 検索キーワード | おすすめソース |
|------|--------------|---------------|
| ボタンクリック | `ui click`, `button tap` | Kenney.nl UI Audio |
| ターン進行（コイン音） | `coin chime`, `cha-ching` | 効果音ラボ, Kenney Casino Audio |
| イベント通知 | `notification`, `bell ding` | 効果音ラボ, 魔王魂 |
| マイルストーン達成 | `fanfare`, `crowd cheer` | 魔王魂ジングル, freesound |
| 資金減少 | `negative`, `descending tone` | 効果音ラボ |
| サイコロ | `dice roll`, `rolling dice` | freesound.org |
| 採用成功 | `success chime`, `level up` | 魔王魂, Kenney |
| 昇進 | `power up`, `upgrade` | 効果音ラボ |

### BGM
| フェーズ | 検索キーワード (日本語サイト) | 検索キーワード (英語サイト) |
|---------|---------------------------|--------------------------|
| 序盤 (lo-fi) | `ほのぼの`, `日常`, `カフェ` | `lofi`, `chill beats` |
| 中盤 (テンポアップ) | `軽快`, `ポップ`, `前向き` | `upbeat corporate`, `motivational` |
| 終盤 (IPO近い) | `壮大`, `盛り上がる`, `クライマックス` | `epic build up`, `climax` |
| ピンチ時 | `緊張`, `不穏`, `ピンチ` | `tension`, `suspense` |
| タイトル | `オープニング`, `さわやか` | `light corporate`, `startup` |
| 勝利 | `勝利`, `達成`, `ファンファーレ` | `victory`, `triumphant` |
| 敗北 | `悲しい`, `切ない` | `somber`, `melancholy piano` |

---

## ソース別詳細

### Kenney.nl (CC0)
- URL: https://kenney.nl/assets?q=audio
- 帰属: 不要
- 形式: .ogg, .wav
- UI Audio パックが特に優秀

### 効果音ラボ (soundeffect-lab.info)
- URL: https://soundeffect-lab.info
- 帰属: 不要
- 形式: .mp3 → .ogg変換必要
- 日本のゲーム向けSE多数

### DOVA-SYNDROME
- URL: https://dova-s.jp
- 帰属: 不要
- 形式: .mp3 → .ogg変換必要
- 日本最大級のフリーBGMサイト

### Pixabay Audio
- URL: https://pixabay.com/sound-effects/ (SE), https://pixabay.com/music/ (BGM)
- 帰属: 不要 (Pixabay License)
- 形式: .mp3 → 変換必要

### 魔王魂 (Maou Damashii)
- URL: https://maou.audio
- 帰属: **必要** — クレジットに「魔王魂 https://maou.audio」を記載
- 形式: .mp3, .ogg
- SE・BGM・ジングル全て充実

### 甘茶の音楽工房
- URL: https://amachamusic.chagasi.com
- 帰属: 不要
- 形式: .mp3 → .ogg変換必要

### freesound.org
- URL: https://freesound.org
- 帰属: 音ごとに異なる (CC0フィルター推奨)
- 形式: .wav, .ogg

---

## Godot 4 向け変換コマンド

```bash
# MP3 → OGG (BGM用)
ffmpeg -i input.mp3 -codec:a libvorbis -qscale:a 5 output.ogg

# MP3 → WAV (SE用)
ffmpeg -i input.mp3 output.wav
```

## ライセンス管理

`assets/audio/CREDITS.txt` に以下の形式で記録:
```
[音名] - [ソース] - [ライセンス] - [作者名]
```
