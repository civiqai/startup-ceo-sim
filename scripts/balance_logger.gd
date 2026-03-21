extends Node
## バランスログ: ターンごとのパラメータ履歴を記録

signal history_updated

# 各パラメータの履歴配列
var cash_history: Array[int] = []
var users_history: Array[int] = []
var product_power_history: Array[int] = []
var team_size_history: Array[int] = []
var team_morale_history: Array[int] = []
var reputation_history: Array[int] = []
var valuation_history: Array[int] = []


func reset() -> void:
	cash_history.clear()
	users_history.clear()
	product_power_history.clear()
	team_size_history.clear()
	team_morale_history.clear()
	reputation_history.clear()
	valuation_history.clear()


func record_snapshot(gs: Node) -> void:
	cash_history.append(gs.cash)
	users_history.append(gs.users)
	product_power_history.append(gs.product_power)
	team_size_history.append(gs.team_size)
	team_morale_history.append(gs.team_morale)
	reputation_history.append(gs.reputation)
	valuation_history.append(gs.valuation)
	history_updated.emit()


## テキストベースのグラフ生成（RichTextLabel用）
func generate_text_chart(data: Array, label: String, chart_width: int = 40, chart_height: int = 10) -> String:
	if data.is_empty():
		return "%s: データなし\n" % label

	var max_val: float = 1.0
	var min_val: float = 0.0
	for v in data:
		if v > max_val:
			max_val = v
		if v < min_val:
			min_val = v

	var range_val := max_val - min_val
	if range_val == 0:
		range_val = 1.0

	var text := "[b]%s[/b] (min:%d max:%d latest:%d)\n" % [label, min_val, max_val, data[-1]]

	# グラフ本体
	for row in range(chart_height - 1, -1, -1):
		var threshold := min_val + range_val * row / (chart_height - 1)
		var line := ""
		# データをチャート幅にリサンプル
		var step := maxf(float(data.size()) / chart_width, 1.0)
		var col := 0
		var i := 0.0
		while col < chart_width and int(i) < data.size():
			var idx := int(i)
			var val_ratio := (float(data[idx]) - min_val) / range_val
			var row_ratio := float(row) / (chart_height - 1)
			if val_ratio >= row_ratio:
				line += "#"
			else:
				line += " "
			i += step
			col += 1
		# 軸ラベル
		if row == chart_height - 1:
			text += "%8d |%s\n" % [int(max_val), line]
		elif row == 0:
			text += "%8d |%s\n" % [int(min_val), line]
		else:
			text += "         |%s\n" % line

	text += "          " + "-".repeat(chart_width) + "\n"
	text += "          ターン 0 → %d\n" % (data.size() - 1)
	return text


func generate_full_report() -> String:
	var report := "[b]=== バランスログ ===[/b]\n\n"
	report += generate_text_chart(cash_history, "資金（万円）")
	report += "\n"
	report += generate_text_chart(users_history, "ユーザー数")
	report += "\n"
	report += generate_text_chart(valuation_history, "時価総額（万円）")
	report += "\n"
	report += generate_text_chart(product_power_history, "プロダクト力")
	report += "\n"
	report += generate_text_chart(reputation_history, "評判")
	return report
