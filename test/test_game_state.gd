class_name TestGameState
extends GdUnitTestSuite
## GameState シングルトンのユニットテスト


func before_test() -> void:
	GameState.reset()


func test_initial_values() -> void:
	assert_int(GameState.cash).is_equal(1000)
	assert_int(GameState.month).is_equal(0)
	assert_int(GameState.product_power).is_equal(10)
	assert_int(GameState.team_morale).is_equal(70)
	assert_int(GameState.users).is_equal(0)
	assert_int(GameState.reputation).is_equal(30)
	assert_int(GameState.brand_value).is_equal(0)
	assert_int(GameState.fundraise_cooldown).is_equal(0)
	assert_int(GameState.total_raised).is_equal(0)
	assert_int(GameState.fundraise_count).is_equal(0)
	assert_int(GameState.code_quality).is_equal(30)
	assert_int(GameState.ux_quality).is_equal(20)
	assert_int(GameState.infra_stability).is_equal(30)
	assert_int(GameState.security_score).is_equal(20)
	assert_bool(GameState.overtime_enabled).is_false()
	assert_int(GameState.current_phase).is_equal(0)


func test_advance_month() -> void:
	# 初期状態: cash=1000, month=0, team_size=1(社長のみ), monthly_cost=50
	var initial_cash := GameState.cash
	var initial_month := GameState.month
	var cost := GameState.monthly_cost

	GameState.advance_month()

	assert_int(GameState.month).is_equal(initial_month + 1)
	# revenue=0 (users=0), cost=50 (社長分のみ)
	assert_int(GameState.cash).is_equal(initial_cash - cost)


func test_revenue_calculation_zero_users() -> void:
	# users=0 の場合、revenue=0
	GameState.users = 0
	GameState.add_product_power(50 - GameState.product_power)
	assert_int(GameState.revenue).is_equal(0)


func test_revenue_calculation_zero_product() -> void:
	# product_power=0 の場合、revenue=0
	GameState.users = 1000
	GameState.add_product_power(0 - GameState.product_power)
	assert_int(GameState.revenue).is_equal(0)


func test_revenue_calculation_with_values() -> void:
	# revenue = int(users * product_power / 500 * (1.0 + brand_value / 200.0))
	GameState.users = 1000
	GameState.add_product_power(50 - GameState.product_power)
	GameState.brand_value = 0
	# base = 1000 * 50 / 500 = 100
	# brand_multiplier = 1.0 + 0/200 = 1.0
	# revenue = int(100 * 1.0) = 100
	assert_int(GameState.revenue).is_equal(100)


func test_revenue_calculation_with_brand() -> void:
	GameState.users = 1000
	GameState.add_product_power(50 - GameState.product_power)
	GameState.brand_value = 100
	# base = 1000 * 50 / 500 = 100
	# brand_multiplier = 1.0 + 100/200.0 = 1.5
	# revenue = int(100 * 1.5) = 150
	assert_int(GameState.revenue).is_equal(150)


func test_valuation_calculation() -> void:
	GameState.users = 1000
	GameState.add_product_power(50 - GameState.product_power)
	GameState.brand_value = 10
	GameState.reputation = 30
	# user_component = 1000 * 50 = 50000
	# brand_component = 10 * 10 * 2 = 200
	# revenue = int(1000*50/500 * (1.0 + 10/200.0)) = int(100 * 1.05) = 105
	# revenue_component = 105 * 120 = 12600
	# reputation_component = 30 * 100 = 3000
	# valuation = 50000 + 200 + 12600 + 3000 = 65800
	assert_int(GameState.valuation).is_equal(65800)


func test_bankruptcy() -> void:
	GameState.cash = 50  # 丁度 monthly_cost (50) と同じ
	# monthly_cost = 50 (社長分のみ), revenue = 0
	# cash = 50 + 0 - 50 = 0 → game_over
	GameState.advance_month()
	assert_int(GameState.cash).is_equal(0)


func test_monthly_cost_ceo_only() -> void:
	# チームメンバーなしの場合、社長50万のみ
	assert_int(GameState.monthly_cost).is_equal(50)


func test_monthly_cost_with_member() -> void:
	# メンバーを追加して月間コストを確認
	var member = preload("res://scripts/team_member.gd").new()
	member.skill_type = "engineer"
	member.skill_level = 1
	member.calculate_salary()  # salary = 400 + 1*100 = 500
	TeamManager.hire(member)

	# monthly_cost = 50 (社長) + 500/12 = 50 + 41 = 91
	assert_int(GameState.monthly_cost).is_equal(50 + member.get_monthly_cost())


func test_team_size_property() -> void:
	# 社長のみ = 1
	assert_int(GameState.team_size).is_equal(1)

	var member = preload("res://scripts/team_member.gd").new()
	member.member_name = "テスト太郎"
	TeamManager.hire(member)
	assert_int(GameState.team_size).is_equal(2)


func test_advance_month_with_revenue() -> void:
	GameState.users = 5000
	GameState.add_product_power(50 - GameState.product_power)
	GameState.brand_value = 0
	# revenue = int(5000 * 50 / 500 * 1.0) = 500
	var rev := GameState.revenue
	var initial_cash := GameState.cash
	var cost := GameState.monthly_cost

	GameState.advance_month()

	assert_int(GameState.cash).is_equal(initial_cash + rev - cost)


func test_advance_month_brand_decay() -> void:
	GameState.brand_value = 50

	GameState.advance_month()

	# brand_value >= 20 なので -1 される
	assert_int(GameState.brand_value).is_equal(49)


func test_advance_month_brand_no_decay_below_20() -> void:
	GameState.brand_value = 19

	GameState.advance_month()

	# brand_value < 20 なので減衰しない
	assert_int(GameState.brand_value).is_equal(19)


func test_fundraise_cooldown_decrement() -> void:
	GameState.fundraise_cooldown = 3

	GameState.advance_month()

	assert_int(GameState.fundraise_cooldown).is_equal(2)
