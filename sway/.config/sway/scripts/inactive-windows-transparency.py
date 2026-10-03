#!/usr/bin/env python3
"""
inactive-windows-transparency.py - Dynamic window opacity controller for Sway
Sets focused (active) window to solid opacity (default 1.0) so wallpaper
does not shine through, while maintaining subtle transparency on inactive windows.
Supports both i3ipc and pure Python standard library socket fallback.
"""

import argparse
import json
import os
import signal
import socket
import struct
import sys


def run_i3ipc(args):
    import i3ipc

    ipc = i3ipc.Connection()
    focused_set = set()

    for window in ipc.get_tree():
        if window.focused:
            focused_set.add(window.id)
            window.command(f"opacity {args.focused}")
        else:
            window.command(f"opacity {args.opacity}")

    def on_window(ipc_conn, event):
        nonlocal focused_set
        tree = ipc_conn.get_tree()
        focused = tree.find_focused()
        if focused is None:
            return

        focused.command(f"opacity {args.focused}")
        focused_set.add(focused.id)

        to_remove = set()
        for wid in focused_set:
            if wid == focused.id:
                continue
            w = tree.find_by_id(wid)
            if w is None:
                to_remove.add(wid)
            else:
                w.command(f"opacity {args.opacity}")
                to_remove.add(wid)
        focused_set -= to_remove

    def on_exit(sig, frame):
        try:
            for w in ipc.get_tree().leaves():
                w.command(f"opacity {args.focused}")
        except Exception:
            pass
        sys.exit(0)

    for sig in [signal.SIGINT, signal.SIGTERM]:
        signal.signal(sig, on_exit)

    ipc.on("window::focus", on_window)
    ipc.main()


def run_socket_fallback(args):
    sock_path = os.environ.get("SWAYSOCK") or os.environ.get("I3SOCK")
    if not sock_path or not os.path.exists(sock_path):
        sys.exit(1)

    MAGIC = b"i3-ipc"

    def send_cmd(s, cmd_str):
        payload = cmd_str.encode("utf-8")
        header = struct.pack("=6sII", MAGIC, len(payload), 0)  # IPC_COMMAND = 0
        s.sendall(header + payload)
        # Read response
        resp_hdr = s.recv(14)
        if len(resp_hdr) == 14:
            _, rlen, _ = struct.unpack("=6sII", resp_hdr)
            s.recv(rlen)

    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock_path)

    # Initial command: set all to unfocused opacity
    send_cmd(s, f'[app_id=".*"] opacity {args.opacity}; [class=".*"] opacity {args.opacity}')

    # Subscribe to window events
    sub_payload = json.dumps(["window"]).encode("utf-8")
    sub_header = struct.pack("=6sII", MAGIC, len(sub_payload), 2)  # IPC_SUBSCRIBE = 2
    s.sendall(sub_header + sub_payload)
    resp_hdr = s.recv(14)
    if len(resp_hdr) == 14:
        _, rlen, _ = struct.unpack("=6sII", resp_hdr)
        s.recv(rlen)

    prev_focused_id = None

    while True:
        try:
            hdr = s.recv(14)
            if len(hdr) < 14:
                break
            _, length, mtype = struct.unpack("=6sII", hdr)
            data = b""
            while len(data) < length:
                chunk = s.recv(length - len(data))
                if not chunk:
                    break
                data += chunk

            if mtype & (1 << 31):  # Event
                try:
                    event = json.loads(data.decode("utf-8"))
                    if event.get("change") == "focus":
                        con = event.get("container", {})
                        cid = con.get("id")
                        if cid:
                            cmd = f"[con_id={cid}] opacity {args.focused}"
                            if prev_focused_id and prev_focused_id != cid:
                                cmd += f"; [con_id={prev_focused_id}] opacity {args.opacity}"
                            prev_focused_id = cid
                            # Send command on separate connection to avoid stream interleaving
                            cs = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                            cs.connect(sock_path)
                            send_cmd(cs, cmd)
                            cs.close()
                except Exception:
                    pass
        except Exception:
            break


def main():
    parser = argparse.ArgumentParser(
        description="Set active window to solid opacity and inactive windows to translucent."
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

    try:
        run_i3ipc(args)
    except ImportError:
        run_socket_fallback(args)


if __name__ == "__main__":
    main()
