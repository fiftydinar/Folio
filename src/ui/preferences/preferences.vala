
[GtkTemplate (ui = "/com/toolstack/Folio/preferences.ui")]
public class Folio.PreferencesWindow : Adw.PreferencesDialog {
	~PreferencesWindow () {
		debug ("Destroying PreferencesWindow");
	}

	public signal void three_pane_changed (bool is_three_pane);

	[GtkChild] unowned Gtk.FontDialogButton font_button;
	[GtkChild] unowned Gtk.FontDialogButton font_button_monospace;
	[GtkChild] unowned Gtk.Switch oled_mode;
	[GtkChild] unowned Adw.ComboRow url_detection_level;
	[GtkChild] unowned Gtk.Switch enable_toolbar;
	[GtkChild] unowned Gtk.Switch enable_cheatsheet;
	[GtkChild] unowned Gtk.Switch enable_3_pane;
	[GtkChild] unowned Gtk.Button notes_dir_button;
	[GtkChild] unowned Gtk.Button notes_dir_button_reset;
	[GtkChild] unowned Gtk.Label notes_dir_label;
	[GtkChild] unowned Gtk.Button trash_dir_button;
	[GtkChild] unowned Gtk.Button trash_dir_button_reset;
	[GtkChild] unowned Gtk.Label trash_dir_label;
	[GtkChild] unowned Gtk.Switch limit_note_width;
	[GtkChild] unowned Gtk.Switch long_notebook_names;
	[GtkChild] unowned Adw.ComboRow long_note_names;
	[GtkChild] unowned Adw.SpinRow custom_note_width;
	[GtkChild] unowned Gtk.Switch show_line_numbers;
	[GtkChild] unowned Gtk.Switch show_all_notes;
	[GtkChild] unowned Gtk.Switch enable_autosave;
	[GtkChild] unowned Gtk.Switch disable_hidden_trash;
	[GtkChild] unowned Adw.ComboRow note_sort_order;
	[GtkChild] unowned Adw.ComboRow notebook_sort_order;
	[GtkChild] unowned Adw.ComboRow line_spacing;

	private Settings settings;
	private Application app;
	private Gtk.Window window;
	private string notes_dir;
	private string trash_dir;

	public PreferencesWindow (Application app, Gtk.Window window) {
		Object ();
		this.app = app;
		this.window = window;
		this.settings = new Settings (Config.APP_ID);

		var font_dialog = new Gtk.FontDialog ();
		var font_desc = Pango.FontDescription.from_string (settings.get_string ("note-font"));

		font_dialog.set_title (Strings.PICK_NOTE_FONT);
		font_button.set_font_desc (font_desc);
		font_button.notify["font-desc"].connect (on_update_font_btn_desc);

		font_button.set_dialog (font_dialog);

		var font_dialog_monospace = new Gtk.FontDialog ();
		var font_desc_monospace = Pango.FontDescription.from_string (settings.get_string ("note-font-monospace"));
		var monospace_filter = new Folio.MonospaceFilter ();
		font_dialog_monospace.set_filter (monospace_filter);
		font_dialog_monospace.set_title (Strings.PICK_CODE_FONT);
		font_button_monospace.set_font_desc (font_desc_monospace);
		font_button_monospace.notify["font-desc"].connect (on_update_font_monospace_btn_desc);

		font_button_monospace.set_dialog (font_dialog_monospace);

		oled_mode.active = settings.get_boolean ("theme-oled");
		oled_mode.state_set.connect (on_oled_mode_state_changed);

		url_detection_level.model = new Gtk.StringList ({
			Strings.URL_DETECTION_AGGRESSIVE,
			Strings.URL_DETECTION_STRICT,
			Strings.URL_DETECTION_DISABLED
			});
		var selected_url_detection_level = settings.get_int ("url-detection-level");
		url_detection_level.set_selected ((int)selected_url_detection_level);
        url_detection_level.notify["selected-item"].connect (on_update_url_detection_level_seelected_item);

		line_spacing.model = new Gtk.StringList ({
			"1.0",
			"1.5",
			"2.0"
			});
		line_spacing.set_selected (0);
		var line_spacing_setting = settings.get_string ("line-spacing");
		for (var i = 0; i < line_spacing.model.get_n_items (); i++) {
			if( ((Gtk.StringList)line_spacing.model).get_string (i) == line_spacing_setting ) {
					line_spacing.set_selected (i);
			}
		}
        line_spacing.notify["selected-item"].connect (on_update_line_spacing_selected_item);

		enable_toolbar.active = settings.get_boolean ("toolbar-enabled");
		enable_toolbar.state_set.connect (on_enable_toolbar_state_changed);

		enable_cheatsheet.active = settings.get_boolean ("cheatsheet-enabled");
		enable_cheatsheet.state_set.connect (on_enable_cheatsheet_state_changed);

		enable_3_pane.active = settings.get_boolean ("enable-3-pane");
		enable_3_pane.state_set.connect (on_enable_3_pane_state_changed);

		show_line_numbers.active = settings.get_boolean ("show-line-numbers");
		show_line_numbers.state_set.connect (on_show_line_numbers_state_changed);

		show_all_notes.active = settings.get_boolean ("show-all-notes");
		show_all_notes.state_set.connect (on_show_all_notes_state_changed);

		enable_autosave.active = settings.get_boolean ("enable-autosave");
		enable_autosave.state_set.connect (on_enable_autosave_state_changed);

		disable_hidden_trash.active = settings.get_boolean ("disable-hidden-trash");
		disable_hidden_trash.state_set.connect (on_disable_hidden_trash_state_changed);

		limit_note_width.active = settings.get_int ("note-max-width") != -1;
		limit_note_width.state_set.connect (on_limit_note_width_state_changed);

		int note_width = settings.get_int ("note-max-width");
		if (note_width == -1 ) {
			custom_note_width.set_sensitive (false);
			note_width = 720;
		}

		long_notebook_names.active = settings.get_boolean ("long-notebook-names");
		long_notebook_names.state_set.connect (on_long_notebook_names_state_changed);

		long_note_names.model = new Gtk.StringList ({
			Strings.LONG_NAMES_HANDLING_ELLIPSIZE,
			Strings.LONG_NAMES_HANDLING_WRAP,
			Strings.LONG_NAMES_HANDLING_EXPAND
			});
		var selected_long_note_names = settings.get_int ("long-note-names-handling");
		long_note_names.set_selected ((int)selected_long_note_names);
		long_note_names.notify["selected-item"].connect (on_long_note_names_selected_item);

		var width_adjustment = new Gtk.Adjustment (note_width, 100, 2000, 1.0, 100.0, 1.0);
		custom_note_width.set_adjustment (width_adjustment);
        custom_note_width.notify["value"].connect (on_custom_note_width_value);

		notes_dir = settings.get_string ("notes-dir");
		notes_dir_label.label = settings.get_string ("notes-dir");
		notes_dir_label.tooltip_text = notes_dir;
		notes_dir_button.clicked.connect (on_notes_dir_button_clicked);
		notes_dir_button_reset.clicked.connect (on_notes_dir_button_reset_clicked);

		trash_dir = settings.get_string ("trash-dir");
		trash_dir_label.label = settings.get_string ("trash-dir");
		trash_dir_label.tooltip_text = trash_dir;
		trash_dir_button.clicked.connect (on_trash_dir_button_clicked);
		trash_dir_button_reset.clicked.connect (on_trash_dir_button_reset_clicked);

		note_sort_order.model = new Gtk.StringList ({
			Strings.NOTE_SORT_ORDER_TIME_DSC,
			Strings.NOTE_SORT_ORDER_TIME_ASC,
			Strings.NOTE_SORT_ORDER_ALPHA_ASC,
			Strings.NOTE_SORT_ORDER_ALPHA_DSC,
			Strings.NOTE_SORT_ORDER_NATURAL_ASC,
			Strings.NOTE_SORT_ORDER_NATURAL_DSC
			});
		var selected_sort_order = settings.get_int ("note-sort-order");
		note_sort_order.set_selected ((int)selected_sort_order);
        note_sort_order.notify["selected-item"].connect (on_note_sort_order_selected_item);

		notebook_sort_order.model = note_sort_order.model;
		selected_sort_order = settings.get_int ("notebook-sort-order");
		notebook_sort_order.set_selected ((int)selected_sort_order);
        notebook_sort_order.notify["selected-item"].connect (on_notebook_sort_order_selected_item);

 		this.three_pane_changed.connect (((Folio.Window) window).on_3_pane_change);
	}

	private void on_update_font_btn_desc () {
		var font = font_button.get_font_desc ().to_string ();
		settings.set_string ("note-font", font);
	}

	private void on_update_font_monospace_btn_desc () {
		var font = font_button_monospace.get_font_desc ().to_string ();
		settings.set_string ("note-font-monospace", font);
	}

	private bool on_oled_mode_state_changed (bool state) {
		settings.set_boolean ("theme-oled", state);
		app.update_theme ();
		return false;
	}

	private void on_update_url_detection_level_seelected_item () {
		settings.set_int ("url-detection-level", (int)url_detection_level.get_selected ());
	}

	private void on_update_line_spacing_selected_item () {
		for (var i = 0; i < line_spacing.model.get_n_items (); i++) {
			if( (int)line_spacing.get_selected () == i ) {
					settings.set_string ("line-spacing", ((Gtk.StringList)line_spacing.model).get_string (i));
			}
		}
	}

	private bool on_enable_toolbar_state_changed (bool state) {
		settings.set_boolean ("toolbar-enabled", state);
		return false;
	}

	private bool on_enable_cheatsheet_state_changed (bool state) {
		settings.set_boolean ("cheatsheet-enabled", state);
		return false;
	}

	private bool on_enable_3_pane_state_changed (bool state) {
		settings.set_boolean ("enable-3-pane", state);
		three_pane_changed (state);
		return false;
	}

	private bool on_show_line_numbers_state_changed (bool state) {
		settings.set_boolean ("show-line-numbers", state);
		return false;
	}

	private bool on_show_all_notes_state_changed (bool state) {
		settings.set_boolean ("show-all-notes", state);
		return false;
	}

	private bool on_enable_autosave_state_changed (bool state) {
		settings.set_boolean ("enable-autosave", state);
		return false;
	}

	private bool on_disable_hidden_trash_state_changed (bool state) {
		settings.set_boolean ("disable-hidden-trash", state);
		return false;
	}

	private bool on_limit_note_width_state_changed (bool state) {
		settings.set_int ("note-max-width", state ? 720 : -1);
		custom_note_width.set_sensitive (state);
		return false;
	}

	private bool on_long_notebook_names_state_changed (bool state) {
		settings.set_boolean ("long-notebook-names", state);
		return false;
	}

	private bool on_long_note_names_state_changed (bool state) {
		settings.set_boolean ("long-note-names", state);
		return false;
	}

	private void on_custom_note_width_value () {
		if (limit_note_width.active) {
			settings.set_int ("note-max-width", (int) custom_note_width.value);
		}
	}

	private void on_notes_dir_button_clicked () {
		var chooser = new Gtk.FileDialog ();
		chooser.set_modal (true);
		chooser.set_title (Strings.PICK_NOTES_DIR);
		chooser.set_initial_folder (File.new_for_path (notes_dir));
		chooser.select_folder.begin (window, null, (obj, res) => {
			try {
				var folder = chooser.select_folder.end(res);
				if (folder.query_exists ()) {
					notes_dir = folder.get_path ();
					settings.set_string ("notes-dir", notes_dir);
					notes_dir_label.label = notes_dir;
					notes_dir_label.tooltip_text = notes_dir;
				}
			} catch (Error error) {}
		});
	}

	private void on_notes_dir_button_reset_clicked () {
		settings.reset ("notes-dir");
		notes_dir = FileUtils.expand_home_directory (settings.get_string ("notes-dir"));
		notes_dir_label.label = notes_dir;
		notes_dir_label.tooltip_text = notes_dir;
	}

	private void on_trash_dir_button_clicked () {
		var chooser = new Gtk.FileDialog ();
		chooser.set_modal (true);
		chooser.set_title (Strings.PICK_TRASH_DIR);
		chooser.set_initial_folder (File.new_for_path (trash_dir));
		chooser.select_folder.begin (window, null, (obj, res) => {
			try {
				var folder = chooser.select_folder.end(res);
				if (folder.query_exists ()) {
					trash_dir = folder.get_path ();
					settings.set_string ("trash-dir", trash_dir);
					trash_dir_label.label = trash_dir;
					trash_dir_label.tooltip_text = trash_dir;
				}
			} catch (Error error) {}
		});
	}

	private void on_trash_dir_button_reset_clicked () {
		settings.reset ("trash-dir");
		trash_dir = FileUtils.expand_home_directory (settings.get_string ("trash-dir"));
		trash_dir_label.label = trash_dir;
		trash_dir_label.tooltip_text = trash_dir;
	}

	private void on_long_note_names_selected_item () {
		settings.set_int ("long-note-names-handling", (int)long_note_names.get_selected ());
	}

	private void on_note_sort_order_selected_item () {
		settings.set_int ("note-sort-order", (int)note_sort_order.get_selected ());
	}

	private void on_notebook_sort_order_selected_item () {
		settings.set_int ("notebook-sort-order", (int)notebook_sort_order.get_selected ());
	}
}

public class Folio.MonospaceFilter : Gtk.Filter {
	public override bool match (GLib.Object? item) {
		var font = item as Pango.FontFace;
		var family = font.get_family ();
		return family.is_monospace ();
	}
 }
