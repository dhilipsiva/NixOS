"""Open the real GTK window in Xvfb; opening must never submit a prompt."""
import tempfile
from unittest.mock import patch

import gi

gi.require_version('Gtk', '4.0')
from gi.repository import GLib, Gtk  # noqa: E402
from lucy_desktop.ui import ui  # noqa: E402

opened = []


def verify_window():
    app = Gtk.Application.get_default()
    if app is None or not app.get_windows():
        return True
    opened.extend(app.get_windows())
    assert opened[0].get_title() == 'Ask Lucy'
    app.quit()
    return False


def expire():
    app = Gtk.Application.get_default()
    if app:
        app.quit()
    return False


with tempfile.TemporaryDirectory() as workspace, patch('lucy_desktop.ui.call') as call:
    call.return_value = dict(source='local', session='fixture', control='fixture', model='fixture-model')
    GLib.timeout_add(100, verify_window)
    GLib.timeout_add_seconds(10, expire)
    ui(workspace)
    assert opened
    assert call.call_args_list[0].args == ({'op': 'open'},)
    assert all(item.args[0]['op'] in ('open', 'close') for item in call.call_args_list)
print('Native GTK window opened without memory loading or inference')
