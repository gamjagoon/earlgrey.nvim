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
