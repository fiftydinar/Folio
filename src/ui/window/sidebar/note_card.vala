
[GtkTemplate (ui = "/com/toolstack/Folio/sidebar/note_card.ui")]
public class Folio.NoteCard : Gtk.Box {

	public Window window { set { this._window = value; } }

	public Note note {
		set {
			this._note = value;
			if (value != null) {
				label.label = value.name;
				var time_string = value.time_modified.format ("%-d %b, %-H:%M").strip ();
				subtitle.label = _window.window_model.state == WindowModel.State.NOTEBOOK
					? time_string
					: @"$(time_string) - $(value.notebook.name)";
				extension.label = value.extension;
				extension.visible = !value.is_markdown;
				tooltip_text = value.name;
				var v = Value (typeof (Note));
				v.set_object (value);
				drag_controller.content = new Gdk.ContentProvider.for_value (v);
				extension.update_property (Gtk.AccessibleProperty.LABEL, @"$(Strings.EXTENSION) $(value.extension)", -1);
 				var accessible_time_string = @"$(Strings.LAST_MODIFIED) " + value.time_modified.format ("%-d %B, %-H:%-M").strip ();
				var accessible_description = _window.window_model.state == WindowModel.State.NOTEBOOK
					? accessible_time_string
					: @"$(accessible_time_string), $(Strings.NOTEBOOK) $(value.notebook.name)";
 				subtitle.update_property (Gtk.AccessibleProperty.LABEL, accessible_description, -1);

				var settings = new Settings (Config.APP_ID);
				var long_note_names_handling = settings.get_int ("long-note-names-handling");
				if (long_note_names_handling == 0) {
					label.set_ellipsize (Pango.EllipsizeMode.END);
					label.set_wrap (false);
				} else if (long_note_names_handling == 1) {
					label.set_ellipsize (Pango.EllipsizeMode.NONE);
					label.set_wrap (true);
				} else {
					label.set_ellipsize (Pango.EllipsizeMode.NONE);
					label.set_wrap (false);
				}
			}
		}
	}

	[GtkChild] unowned Gtk.Label label;
	[GtkChild] unowned Gtk.Entry entry;
	[GtkChild] unowned Gtk.Button button_edit;
	[GtkChild] unowned Gtk.Button button_apply;
	[GtkChild] unowned Gtk.Label subtitle;
	[GtkChild] unowned Gtk.Label extension;

	private Gtk.DragSource drag_controller;

	private Window _window;
	private Note _note;
	private Gtk.Popover? current_popover = null;
	private bool clickthrough = false;

	private void show_popup_right ( int n, double x, double y) {
		show_popup (x, y);
	}

	construct {
		var long_press = new Gtk.GestureLongPress ();
		long_press.pressed.connect (show_popup);
		add_controller (long_press);
		var right_click = new Gtk.GestureClick ();
		right_click.button = Gdk.BUTTON_SECONDARY;
		right_click.pressed.connect (show_popup_right);
		add_controller (right_click);
		drag_controller = new Gtk.DragSource ();
		drag_controller.actions = Gdk.DragAction.MOVE;
		drag_controller.drag_begin.connect (on_drag_being);
		drag_controller.drag_end.connect (on_drag_end);
		add_controller (drag_controller);

		var double_click = new Gtk.GestureClick ();
		double_click.button = Gdk.BUTTON_PRIMARY;
		double_click.pressed.connect (check_double_click);
		double_click.released.connect (note_navigate);
		add_controller (double_click);

		button_edit.clicked.connect (request_rename);
		var controller = new Gtk.EventControllerKey ();
		controller.key_pressed.connect (on_controller_key_pressed);
		add_controller (controller);
	}

	private bool on_controller_key_pressed (uint keyval) {
		if (keyval == Gdk.Key.Escape) {
			maybe_exit_rename ();
			return true;
		}
		return false;
	}

	private void on_drag_being () {
		add_css_class ("dragged");
		queue_draw ();
		var paintable = new Gtk.WidgetPaintable (this);
		drag_controller.set_icon (paintable, 0, 0);
	}

	private void on_drag_end () {
		remove_css_class ("dragged");
	}

	public void check_double_click (int n_press, double x, double y) {
		clickthrough = true;
		if (n_press == 2) {
				// We can't just call the rename request here as after this code runs the default
				// handler will run and steal the focus away again.  So instead, just add a slight
				// delay to get the default handler to run before calling the rename request.
			GLib.Timeout.add_once (100, on_check_double_click_change);
		}
	}

	private void on_check_double_click_change () {
		clickthrough = false;
		request_rename ();
	}

	public void note_navigate (int n_press, double x, double y) {
		print (n_press.to_string ());
		if (n_press == 1 && clickthrough) {
			GLib.Timeout.add_once (175, on_note_navigate_delay);
		}
	}

	private void on_note_navigate_delay () {
		if (clickthrough) {
			_window.navigate_to_edit_view ();
		}
	}

	public void request_rename () {
		entry.buffer.set_text (_note.file_name.data);
		entry.visible = true;
		entry.grab_focus_without_selecting ();
		_window.notify["focus-widget"].connect (maybe_exit_rename);
		button_apply.clicked.connect (rename);
		entry.activate.connect (rename);
	}

	private void maybe_exit_rename () {
		var focused = _window.focus_widget;
		if (focused == null
		||  focused == label
		||  focused == entry
		||  focused == button_edit
		||  focused == button_apply
		||  focused == this
		||  focused == parent
		) return;
		exit_rename ();
	}

	private void exit_rename () {
		entry.visible = false;
		_window.notify["focus-widget"].disconnect (maybe_exit_rename);
	}

	private void rename () {
		exit_rename ();
		if (_window.try_rename_note (_note, entry.buffer.text))
			note = _note;
	}

	private void show_popup (double x, double y) {
		clickthrough = false;
		if (current_popover != null) {
			current_popover.popdown();
		}
		var popover = new NoteMenuPopover (
			_window,
			_note,
			_window.window_model.state == WindowModel.State.TRASH,
			request_rename
		);
		popover.closed.connect (on_popover_closed);
		popover.autohide = true;
		popover.has_arrow = true;
		popover.position = Gtk.PositionType.BOTTOM;
		popover.set_parent (label);
		popover.popup ();
		current_popover = popover;
	}

	private void on_popover_closed () {
		current_popover.unparent ();
		current_popover = null;
	}
}
