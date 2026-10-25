#!/usr/bin/env python3
"""Capture earlgrey.nvim from a real Neovim session running in tmux."""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

import pyte
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "docs" / "assets"
COLS = 120
ROWS = 36
CELL_HEIGHT = 20
FONT_SIZE = 15
FRAME_MS = [3500, 4000, 4500, 3500, 3500, 6000]

SAMPLE_FILES = {
    "README.md": """# Earlgrey demo workspace

A small project for demonstrating the earlgrey.nvim workflow.

- Search files and source with FzfLua.
- Toggle a language server for this Neovim session.
- Receive agent lifecycle events from another process.

The notification in the capture is a demo event. It does not represent a live
agent run or a claim that work completed successfully.
""",
    "src/tea.py": """from dataclasses import dataclass


@dataclass(frozen=True)
class Brew:
    name: str
    steep_minutes: int


def steep(name: str = \"Earl Grey\", minutes: int = 4) -> Brew:
    \"\"\"Describe a freshly steeped cup.\"\"\"
    if minutes < 1:
        raise ValueError(\"steeping time must be positive\")
    return Brew(name=name, steep_minutes=minutes)


if __name__ == \"__main__\":
    print(steep())
""",
    "src/notifications.py": """def completion_message(agent: str) -> str:
    \"\"\"Build a concise completion notification for the editor.\"\"\"
    return f\"{agent} finished a response\"


def needs_input(agent: str) -> str:
    return f\"{agent} is waiting for input\"
""",
    "src/search.py": """from pathlib import Path


def project_files(root: Path) -> list[Path]:
    return sorted(path for path in root.rglob(\"*.py\") if ".git" not in path.parts)
""",
    "tests/test_tea.py": """from src.tea import steep


def test_default_cup() -> None:
    assert steep().name == \"Earl Grey\"
""",
}


def run(args: list[str], *, env=None, cwd=None, check=True, capture=False):
    return subprocess.run(
        args,
        cwd=cwd,
        env=env,
        check=check,
        stdout=subprocess.PIPE if capture else subprocess.DEVNULL,
        stderr=subprocess.PIPE if capture else subprocess.DEVNULL,
        text=True,
    )


def require_command(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise RuntimeError(f"required command not found: {name}")
    return path


def tmux(socket: str, *args: str, env=None, capture=False, check=True):
    return run(["tmux", "-L", socket, *args], env=env, capture=capture, check=check)


def pane_text(socket: str) -> str:
    return tmux(socket, "capture-pane", "-p", "-e", "-t", "demo:0.0", capture=True).stdout


def feed_screen(screen: pyte.Screen, raw: str):
    # tmux separates pane rows with LF; terminal linefeeds keep the current
    # column, so add CR to reconstruct the captured grid row by row.
    pyte.Stream(screen).feed(raw.replace("\r\n", "\n").replace("\n", "\r\n"))


def wait_for(socket: str, text: str, timeout: float = 30.0) -> str:
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        current = pane_text(socket)
        screen = pyte.Screen(COLS, ROWS)
        feed_screen(screen, current)
        contents = "\n".join(screen.display)
        if text in contents:
            return current
        time.sleep(0.25)
    screen = pyte.Screen(COLS, ROWS)
    feed_screen(screen, current)
    raise RuntimeError(f"Neovim did not show expected content {text!r}; current pane:\n" + "\n".join(screen.display))


def send(socket: str, *keys: str):
    tmux(socket, "send-keys", "-t", "demo:0.0", *keys)


def capture(socket: str, label: str) -> tuple[str, Image.Image]:
    raw = pane_text(socket)
    screen = pyte.Screen(COLS, ROWS)
    feed_screen(screen, raw)
    contents = "\n".join(screen.display)
    image = draw_screen(screen)
    return contents, image


def color(value: str, default: str) -> str:
    if value in ("default", "none", ""):
        return default
    names = {
        "black": "#000000", "red": "#cd0000", "green": "#00cd00",
        "brown": "#cdcd00", "blue": "#0000ee", "magenta": "#cd00cd",
        "cyan": "#00cdcd", "white": "#e5e5e5", "brightblack": "#7f7f7f",
        "brightred": "#ff0000", "brightgreen": "#00ff00", "brightbrown": "#ffff00",
        "brightblue": "#5c5cff", "brightmagenta": "#ff00ff", "brightcyan": "#00ffff",
        "brightwhite": "#ffffff",
    }
    if value in names:
        return names[value]
    if len(value) == 6:
        try:
            int(value, 16)
            return "#" + value
        except ValueError:
            pass
    return default


def draw_screen(screen: pyte.Screen) -> Image.Image:
    fontconfig = shutil.which("fc-match")
    if not fontconfig:
        raise RuntimeError("fontconfig is required to locate a terminal font (fc-match)")
    match = run([fontconfig, "-f", "%{file}", "monospace"], capture=True).stdout.strip()
    bold_match = run([fontconfig, "-f", "%{file}", "monospace:style=Bold"], capture=True).stdout.strip()
    font = ImageFont.truetype(match, FONT_SIZE)
    bold_font = ImageFont.truetype(bold_match or match, FONT_SIZE)
    cell_width = round(font.getlength("M"))
    cell_height = CELL_HEIGHT
    image = Image.new("RGB", (COLS * cell_width, ROWS * cell_height), "#18201f")
    draw = ImageDraw.Draw(image)

    for row, cells in screen.buffer.items():
        for column, cell in cells.items():
            foreground = color(cell.fg, "#d5ded4")
            background = color(cell.bg, "#18201f")
            if cell.reverse:
                foreground, background = background, foreground
            x = column * cell_width
            y = row * cell_height
            if background != "#18201f":
                draw.rectangle((x, y, x + cell_width - 1, y + cell_height - 1), fill=background)
            if not cell.data or cell.data == " ":
                continue
            face = bold_font if cell.bold else font
            draw.text((x, y - 1), cell.data, font=face, fill=foreground)
            if cell.underscore:
                draw.line((x, y + cell_height - 3, x + cell_width - 1, y + cell_height - 3), fill=foreground)
    return image


def main() -> int:
    for command in ("nvim", "tmux", "fd", "fzf", "rg"):
        require_command(command)
    ASSETS.mkdir(parents=True, exist_ok=True)

    temporary = tempfile.TemporaryDirectory(prefix="earlgrey-demo-")
    work = Path(temporary.name)
    project = work / "earlgrey-demo"
    state = work / "state"
    config = work / "config"
    project.mkdir()
    state.mkdir()
    config.mkdir()
    (config / "nvim").symlink_to(ROOT / "nvim", target_is_directory=True)
    for relative, content in SAMPLE_FILES.items():
        path = project / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    env = os.environ.copy()
    env.update({
        "TERM": "tmux-256color",
        "COLORTERM": "truecolor",
        "XDG_CONFIG_HOME": str(config),
        "XDG_STATE_HOME": str(state),
        "NVIM_APPNAME": "nvim",
    })
    socket = "egdemo" + uuid.uuid4().hex[:10]
    frames: list[Image.Image] = []
    created = False
    try:
        # Keep the server alive while its terminal options are configured.
        tmux(socket, "new-session", "-d", "-s", "setup", "-x", str(COLS), "-y", str(ROWS),
             "sleep 60", env=env)
        created = True
        tmux(socket, "set-option", "-g", "default-terminal", "tmux-256color", env=env)
        tmux(socket, "set-option", "-ga", "terminal-overrides", ",*:Tc", env=env)
        tmux(socket, "new-session", "-d", "-s", "demo", "-x", str(COLS), "-y", str(ROWS),
             "-c", str(project), "nvim src/tea.py", env=env)
        tmux(socket, "kill-session", "-t", "setup", env=env)
        wait_for(socket, "def steep", timeout=45)

        contents, frame = capture(socket, "editor")
        if "steep_minutes" not in contents:
            raise RuntimeError("editor frame did not contain the sample Python buffer")
        frames.append(frame)

        send(socket, "Space", "f", "f")
        time.sleep(1.5)
        contents, frame = capture(socket, "fzf-files")
        if "README.md" not in contents or "tea.py" not in contents:
            raise RuntimeError("FzfLua file picker did not show the sample project files")
        frames.append(frame)

        send(socket, "Escape")
        time.sleep(0.4)
        send(socket, "Space", "f", "g")
        time.sleep(0.7)
        send(socket, "-l", "notification")
        time.sleep(1.8)
        contents, frame = capture(socket, "fzf-grep")
        if "notifications.py" not in contents or "completion" not in contents:
            raise RuntimeError("FzfLua live grep did not show the notification source match")
        frames.append(frame)

        send(socket, "Escape")
        time.sleep(0.5)
        send(socket, "-l", ":LspToggle python")
        time.sleep(0.15)
        send(socket, "C-m")
        time.sleep(1.1)
        send(socket, "Escape")
        contents, frame = capture(socket, "lsp-toggle")
        if "python: disabled" not in contents:
            raise RuntimeError("LSP toggle notification was not visible; current pane:\n" + contents)
        frames.append(frame)

        send(socket, "-l", ":LspStatus python")
        time.sleep(0.15)
        send(socket, "C-m")
        time.sleep(1.1)
        send(socket, "Escape")
        contents, frame = capture(socket, "lsp-status")
        if "python: disabled" not in contents:
            raise RuntimeError("LSP status notification was not visible; current pane:\n" + contents)
        frames.append(frame)

        # Let the LSP toast expire so the supported notifier event is unambiguous.
        time.sleep(5.2)
        notifier = [
            sys.executable, str(ROOT / "script" / "agent-notify.py"),
            "--agent", "Demo agent", "--event", "complete",
            "--message", "DEMO ONLY - no live agent run",
            "--no-desktop", "--no-sound",
        ]
        result = run(notifier, env=env, cwd=project, capture=True)
        if "inboxes=1" not in result.stdout:
            raise RuntimeError(f"demo notification did not reach the running Neovim inbox: {result.stdout.strip()}")
        until = time.monotonic() + 8
        contents = ""
        while time.monotonic() < until:
            contents, frame = capture(socket, "agent-demo")
            if "DEMO ONLY" in contents:
                break
            time.sleep(0.25)
        if "DEMO ONLY" not in contents:
            raise RuntimeError("demo notification did not appear in the Neovim UI")
        frames.append(frame)

        screenshot_path = ASSETS / "earlgrey-screenshot.png"
        gif_path = ASSETS / "earlgrey-demo.gif"
        frames[-1].save(screenshot_path, format="PNG", optimize=True)
        frames[0].save(
            gif_path,
            format="GIF",
            save_all=True,
            append_images=frames[1:],
            duration=FRAME_MS,
            loop=0,
            optimize=True,
            disposal=2,
        )
        print(f"Captured {len(frames)} Neovim states from tmux PTY.")
        print(f"Screenshot: {screenshot_path} ({frames[-1].width}x{frames[-1].height})")
        print(f"Demo: {gif_path} ({sum(FRAME_MS) / 1000:.1f}s)")
        print("The agent notification was sent by script/agent-notify.py as a demo event.")
    finally:
        if created:
            tmux(socket, "kill-server", env=env, check=False)
        temporary.cleanup()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, subprocess.CalledProcessError, RuntimeError, ImportError) as error:
        print(f"capture failed: {error}", file=sys.stderr)
        raise SystemExit(1)
