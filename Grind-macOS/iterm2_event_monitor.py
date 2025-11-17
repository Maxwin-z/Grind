#!/usr/bin/env python3
"""
iTerm2 Event-Driven Monitor
Monitors iTerm2 for session changes and terminal updates, outputting JSON only when changes occur.
"""

import iterm2
import json
import sys
import asyncio
import hashlib


class ITerm2EventMonitor:
    def __init__(self):
        self.last_active_session_id = None
        self.session_content_hashes = {}
        self.last_output = None
        self.keystroke_buffer = []  # Buffer for capturing keystrokes

    async def get_session_info(self, session):
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
            cursor_position = None
            try:
                # Capture the last 100 lines from the screen for client display
                num_lines = screen_contents.number_of_lines
                start_line = max(0, num_lines - 100)
                for i in range(start_line, num_lines):
                    line = screen_contents.line(i)
                    lines.append(line.string)

                # Get cursor position for input tracking
                cursor_position = {
                    "x": screen_contents.cursor_coord.x,
                    "y": screen_contents.cursor_coord.y
                }
            except:
                lines = []

            # Get recent keystrokes if this is the active session
            keystrokes = []
            if session.session_id == self.last_active_session_id and self.keystroke_buffer:
                keystrokes = self.keystroke_buffer.copy()
                self.keystroke_buffer.clear()

            return {
                "session_id": session.session_id,
                "job": job_name,
                "tty": tty,
                "path": pwd,
                "user": user,
                "hostname": host,
                "screen_lines": lines,
                "cursor_position": cursor_position,
                "recent_keystrokes": keystrokes
            }
        except Exception as e:
            return {
                "session_id": session.session_id,
                "error": str(e)
            }

    async def get_full_state(self, app):
        """Get the complete state of all iTerm2 windows and sessions."""
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
                    session_info = await self.get_session_info(session)
                    session_info["is_active"] = (session == active_session)
                    tab_data["sessions"].append(session_info)

                window_data["tabs"].append(tab_data)

            result["windows"].append(window_data)

        return result

    def output_state(self, state):
        """Output state as JSON and flush to ensure it's immediately available."""
        # Calculate hash to avoid duplicate outputs
        state_json = json.dumps(state, sort_keys=True)
        state_hash = hashlib.md5(state_json.encode()).hexdigest()

        if state_hash != self.last_output:
            self.last_output = state_hash
            print(json.dumps(state), flush=True)
            print("---END---", flush=True)  # Delimiter for Swift to detect complete JSON
            sys.stderr.write(f"[Event Monitor] State updated\n")
            sys.stderr.flush()

    async def monitor_active_session(self, app):
        """Monitor the active session for changes."""
        current_active_session = None

        while True:
            try:
                # Get current active session
                active_session = None
                if app.current_terminal_window:
                    current_tab = app.current_terminal_window.current_tab
                    if current_tab:
                        active_session = current_tab.current_session

                # Check if active session changed
                active_session_id = active_session.session_id if active_session else None

                if active_session_id != self.last_active_session_id:
                    self.last_active_session_id = active_session_id
                    state = await self.get_full_state(app)
                    self.output_state(state)
                    sys.stderr.write(f"[Event Monitor] Active session changed to {active_session_id}\n")
                    sys.stderr.flush()

                    # Update current active session for content monitoring
                    current_active_session = active_session

                # Monitor active session's screen content
                if current_active_session:
                    try:
                        screen_contents = await current_active_session.async_get_screen_contents()

                        # Get the last 100 lines to detect changes and share with clients
                        lines = []
                        num_lines = screen_contents.number_of_lines
                        start_line = max(0, num_lines - 100)
                        for i in range(start_line, num_lines):
                            line = screen_contents.line(i)
                            lines.append(line.string)

                        # Hash the content to detect changes
                        content_hash = hashlib.md5("\n".join(lines).encode()).hexdigest()

                        # Check if content changed
                        if self.session_content_hashes.get(current_active_session.session_id) != content_hash:
                            self.session_content_hashes[current_active_session.session_id] = content_hash
                            # Content changed, output new state
                            state = await self.get_full_state(app)
                            self.output_state(state)
                            sys.stderr.write(f"[Event Monitor] Screen content changed\n")
                            sys.stderr.flush()
                    except Exception as e:
                        sys.stderr.write(f"[Event Monitor] Error reading screen: {e}\n")
                        sys.stderr.flush()

                # Sleep briefly before checking again (reduced to 200ms for faster updates)
                await asyncio.sleep(0.2)

            except Exception as e:
                sys.stderr.write(f"[Event Monitor] Error monitoring session: {e}\n")
                sys.stderr.flush()
                await asyncio.sleep(1.0)

    async def monitor_keystrokes(self, connection):
        """Monitor keystrokes in real-time."""
        try:
            app = await iterm2.async_get_app(connection)
            async with iterm2.KeystrokeFilter(connection) as filter:
                filter.set_pattern(iterm2.KeystrokePattern())  # Match all keystrokes
                sys.stderr.write("[Event Monitor] Keystroke monitoring started\n")
                sys.stderr.flush()

                while True:
                    keystroke = await filter.async_get()
                    try:
                        # Only capture keystrokes from active session
                        if keystroke.session.session_id == self.last_active_session_id:
                            # Add keystroke to buffer
                            self.keystroke_buffer.append({
                                "key": keystroke.characters or "",
                                "modifiers": keystroke.modifiers.value if keystroke.modifiers else 0,
                                "timestamp": asyncio.get_event_loop().time()
                            })

                            # If buffer is getting large, output state update
                            if len(self.keystroke_buffer) >= 10:
                                state = await self.get_full_state(app)
                                self.output_state(state)
                    except Exception as e:
                        sys.stderr.write(f"[Event Monitor] Keystroke capture error: {e}\n")
                        sys.stderr.flush()
        except Exception as e:
            sys.stderr.write(f"[Event Monitor] Keystroke filter error: {e}\n")
            sys.stderr.flush()

    async def start_monitoring(self, connection):
        """Start monitoring iTerm2 events."""
        app = await iterm2.async_get_app(connection)

        # Output initial state
        initial_state = await self.get_full_state(app)
        self.output_state(initial_state)

        # Create tasks for different monitors
        tasks = []

        # Monitor active session changes and content
        tasks.append(asyncio.create_task(self.monitor_active_session(app)))

        # Monitor keystrokes for real-time input capture
        tasks.append(asyncio.create_task(self.monitor_keystrokes(connection)))

        # Monitor window focus changes using notifications
        async def on_new_session(connection, session):
            sys.stderr.write(f"[Event Monitor] New session created: {session.session_id}\n")
            sys.stderr.flush()
            state = await self.get_full_state(app)
            self.output_state(state)

        async def on_terminate_session(connection, session):
            sys.stderr.write(f"[Event Monitor] Session terminated: {session.session_id}\n")
            sys.stderr.flush()
            state = await self.get_full_state(app)
            self.output_state(state)

        # Register for session creation/termination notifications
        await iterm2.notifications.async_subscribe_to_new_session_notification(
            connection,
            on_new_session
        )
        await iterm2.notifications.async_subscribe_to_terminate_session_notification(
            connection,
            on_terminate_session
        )

        sys.stderr.write("[Event Monitor] Monitoring started\n")
        sys.stderr.flush()

        # Wait for all tasks
        await asyncio.gather(*tasks)


async def main(connection):
    """Main entry point."""
    monitor = ITerm2EventMonitor()
    await monitor.start_monitoring(connection)


# Run the monitor
sys.stderr.write("[Event Monitor] Starting iTerm2 event monitor...\n")
sys.stderr.flush()
iterm2.run_until_complete(main)
