#!/usr/bin/env python3
"""
iTerm2 Session Info Extractor
Outputs iTerm2 session information as JSON for consumption by the Grind app.
"""

import iterm2
import json
import sys


async def get_session_info(session):
    """Extract information from a session."""
    try:
        job_name = await session.async_get_variable('jobName') or "Unknown"
        tty = await session.async_get_variable('tty') or ""
        pwd = await session.async_get_variable('path') or ""
        user = await session.async_get_variable('user') or ""
        host = await session.async_get_variable('hostname') or ""

        # Get screen contents
        screen_contents = await session.async_get_screen_contents()
        lines = []
        try:
            # Get the last 20 lines from the screen
            num_lines = screen_contents.number_of_lines
            start_line = max(0, num_lines - 20)
            for i in range(start_line, num_lines):
                line = screen_contents.line(i)
                lines.append(line.string)
        except:
            lines = []

        return {
            "session_id": session.session_id,
            "job": job_name,
            "tty": tty,
            "path": pwd,
            "user": user,
            "hostname": host,
            "screen_lines": lines
        }
    except Exception as e:
        return {
            "session_id": session.session_id,
            "error": str(e)
        }


async def main(connection):
    """Extract all iTerm2 session information as JSON."""
    app = await iterm2.async_get_app(connection)

    # Get the current active session
    active_session = None
    if app.current_terminal_window:
        current_tab = app.current_terminal_window.current_tab
        if current_tab:
            active_session = current_tab.current_session

    result = {
        "windows": [],
        "active_session_id": active_session.session_id if active_session else None
    }

    # Iterate through all windows
    for window in app.windows:
        window_data = {
            "window_id": window.window_id,
            "is_current": window == app.current_terminal_window,
            "tabs": []
        }

        for tab in window.tabs:
            tab_data = {
                "tab_id": tab.tab_id,
                "is_current": (app.current_terminal_window and
                              tab == app.current_terminal_window.current_tab),
                "sessions": []
            }

            for session in tab.sessions:
                session_info = await get_session_info(session)
                session_info["is_active"] = (session == active_session)
                tab_data["sessions"].append(session_info)

            window_data["tabs"].append(tab_data)

        result["windows"].append(window_data)

    # Output JSON
    print(json.dumps(result, indent=2))


# Run the script
iterm2.run_until_complete(main)
