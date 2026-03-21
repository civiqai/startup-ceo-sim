class_name TestTeamMember
extends GdUnitTestSuite
## TeamMember リソースのユニットテスト

const TeamMemberClass = preload("res://scripts/team_member.gd")


func _create_member(skill: String = "engineer", level: int = 1, role: String = "member") -> Resource:
	var m := TeamMemberClass.new()
	m.member_name = "テスト"
	m.skill_type = skill
	m.skill_level = level
	m.role = role
	m.personality = "diligent"
	m.stamina = 100.0
	m.work_state = "idle"
	m.calculate_salary()
	return m


func test_work_one_hour() -> void:
	var m := _create_member("engineer", 2)
	m.stamina = 100.0
	m.arrive_at_office()

	var productivity := m.work_one_hour()

	# drain = 5.0 + 2*0.5 = 6.0 → stamina = 94.0
	assert_float(m.stamina).is_equal_approx(94.0, 0.01)
	# productivity = skill_level * ROLE_MULTIPLIER["member"] = 2 * 1.0 = 2.0
	assert_float(productivity).is_equal_approx(2.0, 0.01)


func test_stamina_depletion() -> void:
	var m := _create_member("engineer", 1)
	# drain per hour = 5.0 + 1*0.5 = 5.5
	# 100 / 5.5 ≈ 18.18 → 19回で 0 になるはず
	m.arrive_at_office()

	var hours := 0
	while m.stamina > 0:
		m.work_one_hour()
		hours += 1

	assert_str(m.work_state).is_equal("left")
	assert_bool(m.is_at_office).is_false()
	assert_float(m.stamina).is_equal(0.0)


func test_work_at_zero_stamina_returns_zero() -> void:
	var m := _create_member("engineer", 1)
	m.stamina = 0.0

	var productivity := m.work_one_hour()

	assert_float(productivity).is_equal(0.0)
	assert_str(m.work_state).is_equal("left")
	assert_bool(m.is_at_office).is_false()


func test_rest_overnight() -> void:
	var m := _create_member()
	m.stamina = 30.0
	m.work_state = "left"

	m.rest_overnight()

	# stamina = min(30 + 40, 100) = 70
	assert_float(m.stamina).is_equal_approx(70.0, 0.01)
	assert_str(m.work_state).is_equal("idle")


func test_rest_overnight_capped_at_100() -> void:
	var m := _create_member()
	m.stamina = 80.0

	m.rest_overnight()

	# stamina = min(80 + 40, 100) = 100
	assert_float(m.stamina).is_equal(100.0)


func test_rest_full() -> void:
	var m := _create_member()
	m.stamina = 10.0
	m.work_state = "left"

	m.rest_full()

	assert_float(m.stamina).is_equal(100.0)
	assert_str(m.work_state).is_equal("idle")


func test_role_multiplier_member() -> void:
	var m := _create_member("engineer", 3, "member")
	m.arrive_at_office()

	var productivity := m.work_one_hour()

	# skill_level(3) * ROLE_MULTIPLIER["member"](1.0) = 3.0
	assert_float(productivity).is_equal_approx(3.0, 0.01)


func test_role_multiplier_leader() -> void:
	var m := _create_member("engineer", 3, "leader")
	m.arrive_at_office()

	var productivity := m.work_one_hour()

	# skill_level(3) * ROLE_MULTIPLIER["leader"](1.5) = 4.5
	assert_float(productivity).is_equal_approx(4.5, 0.01)


func test_role_multiplier_manager() -> void:
	var m := _create_member("engineer", 3, "manager")
	m.arrive_at_office()

	var productivity := m.work_one_hour()

	# skill_level(3) * ROLE_MULTIPLIER["manager"](2.0) = 6.0
	assert_float(productivity).is_equal_approx(6.0, 0.01)


func test_role_multiplier_cxo() -> void:
	var m := _create_member("engineer", 3, "cxo")
	m.arrive_at_office()

	var productivity := m.work_one_hour()

	# skill_level(3) * ROLE_MULTIPLIER["cxo"](3.0) = 9.0
	assert_float(productivity).is_equal_approx(9.0, 0.01)


func test_calculate_salary_engineer() -> void:
	var m := _create_member("engineer", 3)
	# salary = BASE_SALARY["engineer"](400) + skill_level(3) * 100 = 700
	assert_int(m.salary).is_equal(700)


func test_calculate_salary_pm() -> void:
	var m := _create_member("pm", 2)
	# salary = BASE_SALARY["pm"](450) + skill_level(2) * 100 = 650
	assert_int(m.salary).is_equal(650)


func test_get_monthly_cost() -> void:
	var m := _create_member("engineer", 1)
	# salary = 400 + 100 = 500 → monthly = 500 / 12 = 41 (int division)
	assert_int(m.get_monthly_cost()).is_equal(500 / 12)


func test_arrive_and_leave_office() -> void:
	var m := _create_member()

	m.arrive_at_office()
	assert_bool(m.is_at_office).is_true()
	assert_str(m.work_state).is_equal("working")

	m.leave_office()
	assert_bool(m.is_at_office).is_false()
	assert_str(m.work_state).is_equal("left")


func test_personality_effect_diligent() -> void:
	var effect := TeamMemberClass.get_personality_effect("diligent")
	assert_str(effect["type"]).is_equal("productivity")
	assert_float(float(effect["value"])).is_equal_approx(0.10, 0.001)


func test_personality_effect_creative() -> void:
	var effect := TeamMemberClass.get_personality_effect("creative")
	assert_str(effect["type"]).is_equal("product_power")
	assert_float(float(effect["value"])).is_equal_approx(0.15, 0.001)


func test_personality_effect_mood_maker() -> void:
	var effect := TeamMemberClass.get_personality_effect("mood_maker")
	assert_str(effect["type"]).is_equal("morale")
	assert_int(int(effect["value"])).is_equal(5)
