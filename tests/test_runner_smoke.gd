extends TestCase
## Sanity checks for the test harness itself.


func test_assert_eq_records_failure() -> void:
	var probe := TestCase.new()
	probe.assert_eq(1, 2)
	assert_eq(probe.failures.size(), 1)


func test_assert_eq_passes() -> void:
	var probe := TestCase.new()
	probe.assert_eq("a", "a")
	assert_true(probe.failures.is_empty())
