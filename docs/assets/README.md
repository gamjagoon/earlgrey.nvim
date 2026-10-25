# earlgrey.nvim media

`earlgrey-tea.png` is the README banner illustration. The project title and
introduction remain in `README.md` as searchable, accessible text.

`earlgrey-promo-screenshot.png` and `earlgrey-promo-demo.gif` show the checked-out
configuration running in Neovim. The screenshot shows the Lua editor buffer with
FzfLua searching repository files. The 23.9-second demo opens a file-search view,
shows `:LspStatus python`, toggles the Shell LSP setting off and back on, then
receives a scripted notification through the external Python sender.

## Capture provenance

- Neovim 0.12.6 ran the repository's `nvim/init.lua` and plugins in a 120×36
  `xterm-256color` PTY. The PTY output was rendered with pyte and Pillow using
  DejaVu Sans Mono at 16 px per glyph cell, producing 1200×756 PNG/GIF frames.
  These are terminal-output renderings, not desktop or GUI screenshots.
- FzfLua searched the actual checkout for `nvim/lua/lsp`. Its working-directory
  prompt and file icons were disabled for the capture; Lualine, Bufferline,
  Incline, and the current-line blame overlay were also simplified for the
  installed font. Some remaining private-use glyphs may appear as fallback boxes.
- The Shell toggle notification reports the setting as disabled/enabled and
  `bash-language-server` as missing. This shows the configured enablement state;
  it does not demonstrate an LSP server connection or attachment. The Python
  status notification reports its actual state in this capture.
- The notification was sent by a separate invocation of
  `script/agent-notify.py` with the message “Scripted demo event; no agent job
  ran.” Neovim and the sender shared an isolated temporary state directory.
  Desktop notifications and sound were disabled. This is a sample bridge event,
  not an agent run or a claim that agent work completed.
- The GIF is 1200×756 at 23.9 seconds. Its source was sampled every 100 ms; GIF
  optimization merged identical consecutive frames. The local capture helper
  and pyte/Pillow environment are in `/tmp/earlgrey-promo-capture.py` and
  `/tmp/earlgrey-assets-venv` and are not repository files.

## Banner prompt

Use case: illustration-story. Asset type: wide GitHub README banner for a
personal Neovim configuration called earlgrey.nvim. Primary request: an elegant
editorial illustration of a warm cup of Earl Grey black tea, visibly translucent
amber tea in a cream porcelain teacup and saucer, delicate curling steam, a small
bergamot fruit and a few tea leaves beside it. Style: refined hand-painted
gouache illustration with subtle paper grain, restrained, quiet, tasteful
developer-tool identity. Composition: wide landscape banner approximately 3:1,
tea arrangement centered with generous negative space at both sides; seamless
deep forest-green background, warm ivory ceramic, amber highlights and muted
sage leaves. Mood: cozy, focused, contemplative. Constraints: NO TEXT, NO
LETTERS, no logos, no watermark, no computer, no extra decoration, polished
finished illustration.

## Reproducible sample-project capture

`earlgrey-screenshot.png` and `earlgrey-demo.gif` are a separate sample-project
capture pair. The README uses this screenshot and the continuous
`earlgrey-promo-demo.gif` described above. A real Neovim 0.12.6 TUI ran the checked-out `nvim/` config in a
120 × 36 tmux PTY with true color. The images were rendered from
`tmux capture-pane -e` output with pyte 0.8.2 and Pillow 13.0.0 using DejaVu
Sans Mono; they are terminal captures, not desktop screenshots. The PNG is
1080 × 720 (about 51 KiB); the six-frame GIF is 25 seconds (about 158 KiB).
That sample-project GIF is an edited sequence of six captured states, not a
continuous recording.

The demo shows FzfLua file search and live grep, a Python LSP toggle and status,
and a completion event sent through the repository's `script/agent-notify.py`
to the Neovim inbox. That event was manually created by the capture script and
is marked `DEMO ONLY - no live agent run`; it does not represent a real agent
execution or successful work. Desktop notification and sound backends were
disabled. The LSP notification is the live session status, not evidence of
diagnostic or analysis quality.

Recreate it on Linux with tmux, Neovim 0.12+, this project's installed plugins,
`fd`, `fzf`, `ripgrep`, fontconfig, DejaVu Sans Mono, Python, Pillow, and pyte.
The script uses a temporary config link to this checkout and temporary Neovim
state/sample-project directories; it reuses the installed plugin data and
writes only these two images in `docs/assets/`:

```sh
python3 -m venv /tmp/earlgrey-capture-env
/tmp/earlgrey-capture-env/bin/python -m pip install Pillow==13.0.0 pyte==0.8.2
/tmp/earlgrey-capture-env/bin/python script/capture-demo.py
```

The recorded tool versions were Neovim 0.12.6, tmux 3.4, Fzf 0.44.1, fd 9.0.0,
and ripgrep 15.2.0. Search results and LSP server state depend on the local
installed tools when the script is rerun.
