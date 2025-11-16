#!/usr/bin/env python3
"""
iTerm2 Session Lister
Lists all iTerm2 windows, tabs, and sessions, highlighting the active one.
"""

import iterm2


async def main(connection):
    """List all iTerm2 sessions and identify the active one."""
    app = await iterm2.async_get_app(connection)

    print("\n" + "=" * 80)
    print("iTerm2 Windows and Sessions")
    print("=" * 80 + "\n")

    # Get the current active session for comparison
    active_session = None
    if app.current_terminal_window:
        current_tab = app.current_terminal_window.current_tab
        if current_tab:
            active_session = current_tab.current_session

    # Iterate through all windows
    for window_idx, window in enumerate(app.windows):
        is_current_window = window == app.current_terminal_window
        window_marker = " ★ CURRENT WINDOW" if is_current_window else ""

        print(f"┌─ Window {window_idx + 1}{window_marker}")
        print(f"│  Window ID: {window.window_id}")
        print(f"│  Number of tabs: {len(window.tabs)}")
        print("│")

        # Iterate through tabs in this window
        for tab_idx, tab in enumerate(window.tabs):
            is_current_tab = is_current_window and tab == app.current_terminal_window.current_tab
            tab_marker = " ★ CURRENT TAB" if is_current_tab else ""

            print(f"│  ├─ Tab {tab_idx + 1}{tab_marker}")
            print(f"│  │  Tab ID: {tab.tab_id}")
            print(f"│  │  Number of sessions: {len(tab.sessions)}")
            print("│  │")

            # Iterate through sessions in this tab
            for session_idx, session in enumerate(tab.sessions):
                is_active = session == active_session
                session_marker = " ★★★ ACTIVE SESSION ★★★" if is_active else ""

                print(f"│  │  ├─ Session {session_idx + 1}{session_marker}")
                print(f"│  │  │  Session ID: {session.session_id}")

                # Get session details
                try:
                    job_name = await session.async_get_variable('jobName')
                    tty = await session.async_get_variable('tty')
                    pwd = await session.async_get_variable('path')
                    user = await session.async_get_variable('user')
                    host = await session.async_get_variable('hostname')

                    print(f"│  │  │  Job: {job_name}")
                    print(f"│  │  │  TTY: {tty}")
                    print(f"│  │  │  User: {user}@{host}")
                    print(f"│  │  │  Path: {pwd}")
                except Exception as e:
                    print(f"│  │  │  Error getting session details: {e}")

                print("│  │  │")

        print("│")

    print("=" * 80 + "\n")

    # Print summary
    if active_session:
        print("Active Session Summary:")
        print(f"  ID: {active_session.session_id}")
        try:
            job = await active_session.async_get_variable('jobName')
            pwd = await active_session.async_get_variable('path')
            print(f"  Job: {job}")
            print(f"  Working Directory: {pwd}")
        except:
            pass
        print()


# Run the script
iterm2.run_until_complete(main)
