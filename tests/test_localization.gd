extends TestCase
## The language: automatic or chosen, applied to the TranslationServer, kept in the settings.

const PATH := "user://test_localization/settings.cfg"


func after_each_clean() -> void:
	SettingsStore.new(PATH).delete()
	DirAccess.remove_absolute(PATH.get_base_dir())


func test_automatic_follows_the_system_language_when_it_is_supported() -> void:
	for system in ["fr", "fr_FR", "fr-CA", "FR_be"]:
		Localization.set_system_locale(system)
		assert_eq(Localization.resolve(""), "fr", system)
	for system in ["en_US", "de_DE", "", "ja"]:
		Localization.set_system_locale(system)
		assert_eq(Localization.resolve(""), "en", "unsupported %s falls back to English" % system)


func test_a_chosen_language_wins_over_the_system_and_an_unknown_one_is_ignored() -> void:
	Localization.set_system_locale("fr_FR")
	assert_eq(Localization.resolve("en"), "en")
	Localization.set_system_locale("en_US")
	assert_eq(Localization.resolve("fr"), "fr")
	assert_eq(Localization.resolve("klingon"), "en", "unknown: as automatic")


func test_applying_a_language_switches_translations_live() -> void:
	assert_eq(tr("Language"), "Language", "English is the source text")
	Localization.apply("fr")
	assert_eq(TranslationServer.get_locale(), "fr")
	assert_eq(tr("Language"), "Langue")
	assert_eq(tr("No such text in any file"), "No such text in any file", "a missing translation shows the English text")
	Localization.apply("en")
	assert_eq(tr("Language"), "Language")


func test_the_settings_applier_applies_the_language() -> void:
	var settings := Settings.new()
	settings.language = "fr"
	SettingsApplier.apply(settings, null)
	assert_eq(TranslationServer.get_locale(), "fr")
	settings.language = ""
	Localization.set_system_locale("en_GB")
	SettingsApplier.apply(settings, null)
	assert_eq(TranslationServer.get_locale(), "en", "back to automatic")


func test_the_language_is_saved_and_a_bad_value_is_ignored() -> void:
	DirAccess.make_dir_recursive_absolute(PATH.get_base_dir())
	var store := SettingsStore.new(PATH)
	var settings := Settings.new()
	settings.language = "fr"
	assert_true(store.save(settings))
	assert_eq(store.load_or_default().language, "fr")
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[display]\nlanguage=\"xx\"\n")
	file.close()
	assert_eq(store.load_or_default().language, "", "an unknown code means automatic")
	file = FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string("[display]\nlanguage=3\n")
	file.close()
	assert_eq(store.load_or_default().language, "", "a non-text value too")


func test_every_language_has_a_po_file_but_the_source_one() -> void:
	for code in Localization.LANGUAGES:
		if code != Localization.SOURCE_LANGUAGE:
			assert_true(FileAccess.file_exists("res://locale/%s.po" % code), "locale/%s.po" % code)
