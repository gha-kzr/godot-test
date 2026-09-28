class_name TestCase
extends RefCounted
## Base class for test files. Every method named `test_*` is run by tests/run_tests.gd,
## each on a fresh instance. Assertions record failures instead of stopping: a bare
## assert() hangs headless runs.
##
## Any error logged during a test (script error or push_error) fails it, unless the
## test declared it with expect_error() first.

var failures: Array[String] = []
var assertion_count := 0
var current_test := ""
var _expected_errors: Array[String] = []


func assert_eq(actual: Variant, expected: Variant, label := "") -> void:
	_check(actual == expected, "expected %s, got %s" % [expected, actual], label)


func assert_ne(actual: Variant, unexpected: Variant, label := "") -> void:
	_check(actual != unexpected, "expected anything but %s" % [unexpected], label)


func assert_true(condition: bool, label := "") -> void:
	_check(condition, "expected true", label)


func assert_false(condition: bool, label := "") -> void:
	_check(not condition, "expected false", label)


## Declares that the code under test will log an error containing `fragment`.
## The test fails if that error is never logged.
func expect_error(fragment: String) -> void:
	_expected_errors.append(fragment)


## Called by the runner after the test with every error logged during it.
func check_logged_errors(logged: Array[String]) -> void:
	var unmatched := logged.duplicate()
	for fragment in _expected_errors:
		var index := -1
		for i in unmatched.size():
			if fragment in unmatched[i]:
				index = i
				break
		if index == -1:
			failures.append("%s: expected an error containing '%s'" % [current_test, fragment])
		else:
			unmatched.remove_at(index)
	for error in unmatched:
		failures.append("%s: unexpected error: %s" % [current_test, error])


func _check(ok: bool, message: String, label: String) -> void:
	assertion_count += 1
	if not ok:
		var where := current_test if label.is_empty() else "%s (%s)" % [current_test, label]
		failures.append("%s: %s" % [where, message])
