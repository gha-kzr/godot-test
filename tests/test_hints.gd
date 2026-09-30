extends TestCase
## First-run hints: dismissals persist in the settings, and the cards report dismissing.


func test_a_known_hint_shows_until_dismissed() -> void:
	var settings := Settings.new()
	var hints := Hints.new(settings)
	assert_true(hints.should_show("hub_intro"))
	hints.dismiss("hub_intro")
	assert_false(hints.should_show("hub_intro"))
	assert_true(hints.should_show("first_battle"), "others are unaffected")
	assert_eq(settings.dismissed_hints, ["hub_intro"] as Array[String], "kept in the settings")
	hints.dismiss("hub_intro")
	assert_eq(settings.dismissed_hints.size(), 1, "no duplicates")


func test_reset_shows_everything_again_and_unknown_ids_never_show() -> void:
	var hints := Hints.new(Settings.new())
	hints.dismiss("hub_intro")
	hints.dismiss("first_battle")
	hints.reset()
	assert_true(hints.should_show("hub_intro") and hints.should_show("first_battle"))
	assert_false(hints.should_show("no_such_hint"))
	assert_eq(hints.text("no_such_hint"), "")
	assert_true(hints.text("hub_intro").length() > 10)


func test_the_card_is_hidden_until_shown_and_reports_dismissal_once() -> void:
	var card := (load("res://scenes/game/hint_card.tscn") as PackedScene).instantiate() as HintCard
	(Engine.get_main_loop() as SceneTree).root.add_child(card)
	assert_false(card.visible)
	var dismissals := {"count": 0}
	card.dismissed.connect(func() -> void: dismissals.count += 1)
	card.show_hint("Do this.")
	assert_true(card.visible)
	assert_eq((card.get_node("%HintText") as Label).text, "Do this.")
	(card.get_node("%DismissButton") as Button).pressed.emit()
	assert_false(card.visible)
	card.dismiss()
	assert_eq(dismissals.count, 1, "a hidden card doesn't dismiss again")
	card.free()


func after_each_clean() -> void:
	SettingsApplier.reset_bindings(Settings.new())


func test_hint_texts_name_the_bound_key() -> void:
	var hints := Hints.new(Settings.new())
	assert_true(hints.text("first_battle").contains("Ready (Space)"), hints.text("first_battle"))
	SettingsApplier.set_binding(Settings.new(), &"end_turn", KEY_G)
	assert_true(hints.text("first_battle").contains("Ready (G)"), hints.text("first_battle"))
	assert_false(hints.text("first_battle").contains("{"), "no placeholder left")
