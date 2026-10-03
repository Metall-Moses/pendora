#!/usr/bin/env python3
"""
inactive-windows-transparency.py - Dynamic window opacity controller for Sway.
Keeps the active (focused) window completely solid (default: 1.0) so wallpapers
and background windows do not shine through, and dims inactive windows (default: 0.88).

Uses native swaymsg IPC for 100% reliability and zero third-party dependencies.
"""

import argparse
import fcntl
import json
import os
import signal
import subprocess
import sys
import time


def get_window_tree():
    try:
        out = subprocess.check_output(
            ["swaymsg", "-t", "get_tree"],
            stderr=subprocess.DEVNULL,
            text=True,
        )
        return json.loads(out)
    except Exception:
        return None


def extract_client_windows(node):
    windows = []
    # In Sway's layout tree, client application windows are leaf nodes
    # of type 'con' or 'floating_con' that have no child nodes.
    if node.get("type") in ("con", "floating_con"):
        has_children = bool(node.get("nodes") or node.get("floating_nodes"))
        if not has_children:
            name = node.get("name") or ""
            # Exclude internal sway containers / bars
            if not name.startswith("__i3"):
                windows.append((node.get("id"), bool(node.get("focused"))))

    for child in node.get("nodes", []):
        windows.extend(extract_client_windows(child))
    for child in node.get("floating_nodes", []):
        windows.extend(extract_client_windows(child))

    return windows


def apply_opacities(focused_op, inactive_op):
    tree = get_window_tree()
    if not tree:
        return

    windows = extract_client_windows(tree)
    if not windows:
        return

    commands = []
    for wid, is_focused in windows:
        if wid is None:
            continue
        op = focused_op if is_focused else inactive_op
        commands.append(f"[con_id={wid}] opacity {op}")

    if commands:
        cmd_str = "; ".join(commands)
        try:
            subprocess.run(
                ["swaymsg", cmd_str],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass


def restore_all(focused_op):
    tree = get_window_tree()
    if not tree:
        return
    windows = extract_client_windows(tree)
    commands = [f"[con_id={wid}] opacity {focused_op}" for wid, _ in windows if wid]
    if commands:
        try:
            subprocess.run(
                ["swaymsg", "; ".join(commands)],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
        except Exception:
            pass


def main():
    parser = argparse.ArgumentParser(
        description="Dynamic active/inactive window opacity manager for Sway."
    )
    parser.add_argument(
        "--focused",
        "-f",
        type=str,
        default="1.0",
        help="Opacity for focused active window (default: 1.0)",
    )
    parser.add_argument(
        "--opacity",
        "-o",
        type=str,
        default="0.88",
        help="Opacity for inactive background windows (default: 0.88)",
    )
    args = parser.parse_args()

    # Singleton file lock: prevent duplicate processes on Sway reload
    lock_path = f"/tmp/sway-inactive-transparency-{os.getuid()}.lock"
    try:
        lock_file = open(lock_path, "w")
        fcntl.flock(lock_file, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except (BlockingIOError, OSError):
        # Another instance is already actively running
        sys.exit(0)

    # Clean exit signal handlers
    def handle_signal(sig, frame):
        restore_all(args.focused)
        sys.exit(0)

    signal.signal(signal.SIGINT, handle_signal)
    signal.signal(signal.SIGTERM, handle_signal)

    # Initial pass: configure all currently open windows immediately
    apply_opacities(args.focused, args.opacity)

    # Subscribe to Sway window events (focus, new, close, move, etc.)
    while True:
        try:
            sub_proc = subprocess.Popen(
                ["swaymsg", "-t", "subscribe", "-m", '["window"]'],
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )

            for line in sub_proc.stdout:
                line = line.strip()
                if not line:
                    continue
                try:
                    event = json.loads(line)
                    change = event.get("change")
                    # Window focus, creation, destruction, or layout shift
                    if change in ("focus", "new", "close", "move", "floating"):
                        apply_opacities(args.focused, args.opacity)
                except Exception:
                    pass

            sub_proc.wait()
        except Exception:
            time.sleep(1)


if __name__ == "__main__":
    main()
