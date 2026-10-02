extends SceneTree
## Headless test runner. Runs every tests/test_*.gd file (a TestCase) and exits
## with code 1 if anything failed, so scripts and CI can gate on it.
##   godot --headless --script res://tests/run_tests.gd            # all tests
##   godot --headless --script res://tests/run_tests.gd -- movement # files matching "movement"
##
## A test fails on a failed assertion, on any unexpected logged error (a script error
## that aborted it midway included), or if it ran no assertions.
## Tests may `await` (e.g. a tween finishing). A test still running after TEST_TIMEOUT_MSEC
## aborts the run with exit code 1, after printing the results so far.
## After each test the runner resets Engine.time_scale and the language, frees nodes the test left
## under `root`, calls the file's `after_each_clean()` if it has one, so a test that failed midway can't leak into the next one.

const TESTS_DIR := "res://tests"
const TEST_TIMEOUT_MSEC := 10_000
## A test slower than this is named in the output, so a test that quietly became slow shows.
const SLOW_TEST_MSEC := 3000


## Collects every error logged while a test runs.
class ErrorCatcher extends Logger:
	var errors: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		var where := "%s:%d in %s" % [file, line, function]
		# Prefer the GDScript location over the engine's C++ one (e.g. for push_error).
		for backtrace in script_backtraces:
			if backtrace.get_frame_count() > 0:
				where = "%s:%d in %s" % [backtrace.get_frame_file(0), backtrace.get_frame_line(0), backtrace.get_frame_function(0)]
				break
		_mutex.lock()
		errors.append("%s (%s)" % [rationale if not rationale.is_empty() else code, where])
		_mutex.unlock()

	func take() -> Array[String]:
		_mutex.lock()
		var taken := errors.duplicate()
		errors.clear()
		_mutex.unlock()
		return taken


var _ran := false
var _current_test := ""
var _test_deadline := 0
var _passed := 0
var _failed: Array[String] = []


## Tests run on the first frame, not in _initialize(), so the scene tree is live:
## nodes a test adds to `root` get _ready() as they would in the game.
func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run_all()
	elif _test_deadline > 0 and Time.get_ticks_msec() > _test_deadline:
		_failed.append("%s: timed out after %d ms (stuck await?)" % [_current_test, TEST_TIMEOUT_MSEC])
		_finish()
	return false


func _run_all() -> void:
	# Headless windows start at 64x64, where the HUD covers everything; use the game's size.
	root.size = Vector2i(ProjectSettings.get_setting("display/window/size/viewport_width"),
			ProjectSettings.get_setting("display/window/size/viewport_height"))
	var filter := ""
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		filter = user_args[0]

	var catcher := ErrorCatcher.new()
	OS.add_logger(catcher)
	_reset_language()

	for file in _test_files(filter):
		var script := load(TESTS_DIR.path_join(file)) as GDScript
		catcher.take()  # Load/parse errors are reported below instead.
		if script == null or not script.can_instantiate():
			_failed.append("%s: failed to load (parse error?)" % file)
			continue
		for test_name in _test_methods(script):
			var test_case: TestCase = script.new()
			test_case.current_test = "%s::%s" % [file.get_basename(), test_name]
			_current_test = test_case.current_test
			var nodes_before := root.get_children()
			_test_deadline = Time.get_ticks_msec() + TEST_TIMEOUT_MSEC
			var started := Time.get_ticks_msec()
			await test_case.call(test_name)
			_test_deadline = 0
			if Time.get_ticks_msec() - started > SLOW_TEST_MSEC:
				print("  slow: %s took %.1f s" % [test_case.current_test, (Time.get_ticks_msec() - started) / 1000.0])
			_clean_up_after_test(nodes_before)
			if test_case.has_method("after_each_clean"):
				test_case.call("after_each_clean")  # A test file's own cleanup (files, bindings).
			test_case.check_logged_errors(catcher.take())
			if test_case.assertion_count == 0 and test_case.failures.is_empty():
				test_case.failures.append("%s: no assertions ran" % test_case.current_test)
			if test_case.failures.is_empty():
				_passed += 1
			_failed.append_array(test_case.failures)

	OS.remove_logger(catcher)
	_finish()


## Tests read English texts whatever the machine's language is.
func _reset_language() -> void:
	Localization.set_system_locale("en")
	TranslationServer.set_locale("en")


func _clean_up_after_test(nodes_before: Array[Node]) -> void:
	Engine.time_scale = 1.0
	_reset_language()
	for node in root.get_children():
		if node not in nodes_before:
			node.free()


func _finish() -> void:
	for failure in _failed:
		printerr("FAIL ", failure)
	print("Results: %d passed, %d failed" % [_passed, _failed.size()])
	quit(1 if not _failed.is_empty() else 0)


func _test_files(filter: String) -> PackedStringArray:
	var files := PackedStringArray()
	for file in DirAccess.get_files_at(TESTS_DIR):
		if file.begins_with("test_") and file.ends_with(".gd") and file != "test_case.gd" \
				and (filter.is_empty() or filter in file):
			files.append(file)
	files.sort()
	return files


func _test_methods(script: GDScript) -> PackedStringArray:
	var names := PackedStringArray()
	for method in script.get_script_method_list():
		if method.name.begins_with("test_") and method.name not in names:
			names.append(method.name)
	return names
