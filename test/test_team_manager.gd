class_name TestTeamManager
extends GdUnitTestSuite
## TeamManager シングルトンのユニットテスト

const TeamMemberClass = preload("res://scripts/team_member.gd")


func before_test() -> void:
	TeamManager.members.clear()


func _create_member(skill: String = "engineer", level: int = 1, role: String = "member") -> Resource:
	var m := TeamMemberClass.new()
	m.member_name = "テスト"
	m.skill_type = skill
	m.skill_level = level
	m.role = role
	m.personality = "diligent"
	m.stamina = 100.0
	m.calculate_salary()
	return m


func test_hire_member() -> void:
	var initial_size := TeamManager.members.size()

	var member := _create_member()
	TeamManager.hire(member)

	assert_int(TeamManager.members.size()).is_equal(initial_size + 1)


func test_hire_multiple_members() -> void:
	var m1 := _create_member("engineer", 1)
	var m2 := _create_member("designer", 2)
	var m3 := _create_member("marketer", 3)

	TeamManager.hire(m1)
	TeamManager.hire(m2)
	TeamManager.hire(m3)

	assert_int(TeamManager.members.size()).is_equal(3)


func test_fire_member() -> void:
	var member := _create_member()
	TeamManager.hire(member)
	assert_int(TeamManager.members.size()).is_equal(1)

	TeamManager.fire(member)
	assert_int(TeamManager.members.size()).is_equal(0)


func test_fire_nonexistent_member() -> void:
	var member := _create_member()
	# fire a member that was never hired - should not crash
	TeamManager.fire(member)
	assert_int(TeamManager.members.size()).is_equal(0)


func test_monthly_salary_no_members() -> void:
	assert_int(TeamManager.get_total_monthly_cost()).is_equal(0)


func test_monthly_salary_single_member() -> void:
	var member := _create_member("engineer", 1)
	# salary = 400 + 100 = 500, monthly = 500/12 = 41
	TeamManager.hire(member)

	assert_int(TeamManager.get_total_monthly_cost()).is_equal(500 / 12)


func test_monthly_salary_multiple_members() -> void:
	var m1 := _create_member("engineer", 2)  # salary = 400+200=600, monthly=50
	var m2 := _create_member("pm", 3)         # salary = 450+300=750, monthly=62

	TeamManager.hire(m1)
	TeamManager.hire(m2)

	var expected := m1.get_monthly_cost() + m2.get_monthly_cost()
	assert_int(TeamManager.get_total_monthly_cost()).is_equal(expected)


func test_get_members_by_skill() -> void:
	var eng := _create_member("engineer", 1)
	var des := _create_member("designer", 2)
	var eng2 := _create_member("engineer", 3)

	TeamManager.hire(eng)
	TeamManager.hire(des)
	TeamManager.hire(eng2)

	var engineers := TeamManager.get_members_by_skill("engineer")
	assert_int(engineers.size()).is_equal(2)

	var designers := TeamManager.get_members_by_skill("designer")
	assert_int(designers.size()).is_equal(1)


func test_get_skill_bonus() -> void:
	var m1 := _create_member("engineer", 2, "member")   # 2 * 1.0 = 2
	var m2 := _create_member("engineer", 3, "leader")   # 3 * 1.5 = 4.5 → int = 4
	TeamManager.hire(m1)
	TeamManager.hire(m2)

	# total = int(2.0 + 4.5) = int(6.5) = 6
	assert_int(TeamManager.get_skill_bonus("engineer")).is_equal(6)


func test_promote_member() -> void:
	var member := _create_member("engineer", 3, "member")
	TeamManager.hire(member)

	TeamManager.promote(member, "leader")
	assert_str(member.role).is_equal("leader")


func test_has_cxo() -> void:
	var member := _create_member("engineer", 5, "cxo")
	TeamManager.hire(member)

	assert_bool(TeamManager.has_cxo("engineer")).is_true()
	assert_bool(TeamManager.has_cxo("designer")).is_false()


func test_generate_candidate() -> void:
	var candidate := TeamManager.generate_candidate(2, 4)

	assert_str(candidate.member_name).is_not_empty()
	assert_int(candidate.skill_level).is_greater_equal(2)
	assert_int(candidate.skill_level).is_less_equal(4)
	assert_str(candidate.role).is_equal("member")
	assert_int(candidate.months_employed).is_equal(0)
	assert_int(candidate.salary).is_greater(0)


func test_all_arrive_and_leave() -> void:
	var m1 := _create_member("engineer", 1)
	var m2 := _create_member("designer", 2)
	m1.stamina = 100.0
	m2.stamina = 100.0

	TeamManager.hire(m1)
	TeamManager.hire(m2)

	TeamManager.all_arrive()
	assert_bool(m1.is_at_office).is_true()
	assert_bool(m2.is_at_office).is_true()

	TeamManager.all_leave()
	assert_bool(m1.is_at_office).is_false()
	assert_bool(m2.is_at_office).is_false()


func test_all_arrive_skips_low_stamina() -> void:
	var m := _create_member("engineer", 1)
	m.stamina = 5.0  # 10以下なので欠勤
	TeamManager.hire(m)

	TeamManager.all_arrive()
	assert_bool(m.is_at_office).is_false()
