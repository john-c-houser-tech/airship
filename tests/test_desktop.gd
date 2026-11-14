extends TestCase
## The Omarchy layer: the theme's accent, from Grove's theme.rs tests, and
## what notify-send is given.


func test_finds_the_accent_in_a_theme() -> void:
	same(DesktopTheme.accent_in("background = \"#000000\"\naccent = \"#7aa2f7\"\n"), "#7aa2f7", "double quotes")
	same(DesktopTheme.accent_in("  accent='#E0AF68'"), "#E0AF68", "single quotes, indented")
	same(DesktopTheme.accent_in("accent = \"#123456\"\naccent = \"#654321\""), "#123456", "the first one")


func test_ignores_lines_that_are_not_an_accent() -> void:
	for text: String in ["accent_dim = \"#111111\"", "accent = #123456", "accent = \"#12345\"",
			"accent = \"#12345g\"", "accent = \"123456\"", "accent = \"#123456'", "# accent = \"#123456\"", ""]:
		same(DesktopTheme.accent_in(text), "", "ignored: " + text)


func test_reads_the_theme_folder_and_follows_a_change() -> void:
	var folder := OS.get_user_data_dir().path_join("theme-tests")
	OS.execute("rm", ["-rf", folder])
	DirAccess.make_dir_recursive_absolute(folder.path_join("theme"))
	var colors := folder.path_join("theme/colors.toml")
	var file := FileAccess.open(colors, FileAccess.WRITE)
	file.store_string("accent = \"#7aa2f7\"\n")
	file.close()
	var theme := DesktopTheme.new(folder)
	same(theme.accent, Color("#7aa2f7"), "read at once")
	check(not theme.reload(), "unchanged")
	# Omarchy removes the old theme before moving the new one in.
	OS.execute("rm", ["-rf", folder.path_join("theme")])
	check(not theme.reload(), "a theme switching over")
	same(theme.accent, Color("#7aa2f7"), "keeps the accent meanwhile, never a flash of yellow")
	DirAccess.make_dir_recursive_absolute(folder.path_join("theme"))
	file = FileAccess.open(colors, FileAccess.WRITE)
	file.store_string("accent = \"#e0af68\"\n")
	file.close()
	OS.execute("touch", ["-d", "1 minute", colors])
	check(theme.reload(), "a new theme is noticed")
	same(theme.accent, Color("#e0af68"), "the new accent")


func test_without_a_theme_the_accent_is_omarchys_yellow() -> void:
	same(DesktopTheme.new("").accent, DesktopTheme.DEFAULT_ACCENT, "no folder")
	same(DesktopTheme.new("/nowhere/at/all").accent, DesktopTheme.DEFAULT_ACCENT, "a missing folder")
	same(DesktopTheme.DEFAULT_ACCENT, App.DEFAULT_ACCENT, "the core starts with the same one")


func test_a_theme_file_that_is_not_text_is_read_quietly() -> void:
	var folder := OS.get_user_data_dir().path_join("theme-binary")
	OS.execute("rm", ["-rf", folder])
	DirAccess.make_dir_recursive_absolute(folder.path_join("theme"))
	var file := FileAccess.open(folder.path_join("theme/colors.toml"), FileAccess.WRITE)
	file.store_buffer(PackedByteArray([0xff, 0xfe, 0x00, 0xc3]) + "\naccent = \"#7aa2f7\"\n".to_ascii_buffer())
	file.close()
	same(DesktopTheme.new(folder).accent, Color("#7aa2f7"), "found past the junk, and no complaint")


func test_notify_send_is_looked_for_on_the_path() -> void:
	var folder := OS.get_user_data_dir().path_join("path-test")
	OS.execute("rm", ["-rf", folder])
	DirAccess.make_dir_recursive_absolute(folder)
	check(not Notifier.new(folder).working, "missing")
	same(Notifier.find_on_path("notify-send", folder + ":/nowhere"), "", "not found")
	var file := FileAccess.open(folder.path_join("notify-send"), FileAccess.WRITE)
	file.close()
	same(Notifier.find_on_path("notify-send", "/nowhere:" + folder), folder.path_join("notify-send"), "found")


func test_a_notice_can_not_be_mistaken_for_an_option() -> void:
	same(Notifier.arguments("-built", "x"), PackedStringArray(["--app-name=Airship", "--", "-built", "x"]), "arguments")
