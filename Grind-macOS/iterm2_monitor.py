#!/usr/bin/env python3
"""
iTerm2 Session Monitor
Connects to iTerm2, lists all sessions, and monitors the active session output.
"""

import iterm2
import asyncio


async def list_all_sessions(app):
    """List all iTerm2 windows and sessions."""
    print("\n=== iTerm2 Windows and Sessions ===\n")

    for window_idx, window in enumerate(app.windows):
        print(f"Window {window_idx + 1}: {window.window_id}")

        for tab_idx, tab in enumerate(window.tabs):
            print(f"  Tab {tab_idx + 1}:")

            for session_idx, session in enumerate(tab.sessions):
                # Check if this is the current session
                current_session = app.current_terminal_window.current_tab.current_session if app.current_terminal_window else None
                is_active = session == current_session
                active_marker = " [ACTIVE]" if is_active else ""

                print(f"    Session {session_idx + 1}: {session.session_id}{active_marker}")
                print(f"      Name: {await session.async_get_variable('jobName')}")
                print(f"      TTY: {await session.async_get_variable('tty')}")

    print()


async def get_active_session(app):
    """Get the currently active session."""
    if app.current_terminal_window is None:
        return None

    current_tab = app.current_terminal_window.current_tab
    if current_tab is None:
        return None

    return current_tab.current_session


async def print_session_screen(session):
    """Print the current screen contents of a session."""
    screen_contents = await session.async_get_screen_contents()

    print("\n=== Current Screen Contents ===\n")

    # Print each line
    for line in screen_contents.line:
        print(line.string)

    print("\n=== End of Screen ===\n")


async def monitor_session_output(session):
    """Monitor real-time output from a session."""
    print(f"\n=== Monitoring Session: {session.session_id} ===")
    print("Press Ctrl+C to stop monitoring\n")

    # Create a screen streamer to get updates
    async with session.get_screen_streamer() as streamer:
        while True:
            # Wait for screen updates
            screen_contents = await streamer.async_get()

            # Print the updated screen
            print("\n--- Screen Update ---")
            for line in screen_contents.line:
                print(line.string)
            print("--- End Update ---\n")


async def main(connection):
    """Main entry point."""
    app = await iterm2.async_get_app(connection)

    # List all sessions
    await list_all_sessions(app)

    # Get the active session
    active_session = await get_active_session(app)

    if active_session is None:
        print("No active session found!")
        return

    print(f"Active session ID: {active_session.session_id}")
    print(f"Active session name: {await active_session.async_get_variable('jobName')}")

    # Show current screen contents
    await print_session_screen(active_session)

    # Ask user if they want to monitor
    print("\nOptions:")
    print("1. Monitor real-time output (Ctrl+C to stop)")
    print("2. Exit")

    # For now, just monitor (you can add input handling if needed)
    try:
        await monitor_session_output(active_session)
    except KeyboardInterrupt:
        print("\nMonitoring stopped.")


# Run the script
iterm2.run_until_complete(main)
