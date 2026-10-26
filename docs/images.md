# 이미지 미리보기 · Image preview · 画像プレビュー

이 설정은 [snacks.nvim 이미지 모듈](https://github.com/folke/snacks.nvim/blob/main/docs/image.md)만 켭니다.
터미널 UI에서 `nvim path/to/image.png`처럼 이미지를 열거나 Treesitter 파서가 있는
Markdown 문서의 이미지 참조를 볼 수 있습니다. Kitty Graphics Protocol을 지원하는
터미널에서만 이미지 데이터를 렌더링하며, Snacks의 기본 `force = false` 동작으로
지원 여부를 감지합니다. 지원하지 않는 터미널에서는 이미지 파일 대신 안내 버퍼를
표시합니다.

Kitty와 Ghostty는 이미지 미리보기와 인라인 표시를 지원합니다. WezTerm은 Kitty
Graphics Protocol 지원이 제한되어 Markdown 인라인 이미지를 표시하지 않습니다.
Zellij는 지원하지 않습니다. tmux에서는 그래픽을
전달할 수 있도록 Snacks가 감지 시 현재 pane의 `allow-passthrough` 옵션을 켭니다.
tmux 설정 파일은 수정하지 않습니다. `:checkhealth snacks`로 감지 상태를 확인하세요.

headless Neovim에서는 이미지 모듈을 끄므로 터미널 질의나 이미지 렌더링을 하지
않습니다. PNG는 ImageMagick 없이 표시할 수 있습니다. 다른 형식의 변환에는
ImageMagick의 `magick` 명령이 필요할 수 있으며 자동 설치하지 않습니다.

## English

This config enables only the [snacks.nvim image module](https://github.com/folke/snacks.nvim/blob/main/docs/image.md). In a terminal UI, open an image
with `nvim path/to/image.png`; Markdown image references can also render when the
needed Treesitter parser is available. Image data is rendered only when Snacks
detects Kitty Graphics Protocol support (`force = false`). On an unsupported
terminal, opening an image shows an informational buffer instead.

Kitty and Ghostty support image previews and inline rendering. WezTerm has limited
Kitty Graphics Protocol support and does not support inline image rendering.
Zellij is unsupported. When tmux is detected,
Snacks enables `allow-passthrough` for the current pane so graphics can pass through;
it does not edit tmux configuration files. Run `:checkhealth snacks` to inspect
terminal detection.

The image module is disabled in headless Neovim, so it sends no terminal query or
image rendering data there. PNG works without ImageMagick. Converting other formats
may require ImageMagick's `magick` command; the config does not install it.

## 画像プレビュー

この設定では [snacks.nvim の画像モジュール](https://github.com/folke/snacks.nvim/blob/main/docs/image.md)だけを有効にします。
ターミナル UI で `nvim path/to/image.png` のように画像を開けます。必要な Treesitter パーサーがあれば、Markdown 内の画像参照も表示できます。
画像データを描画するのは Kitty Graphics Protocol 対応を検出した場合だけです（`force = false`）。
非対応ターミナルで画像ファイルを開くと、案内用バッファーを表示します。

Kitty と Ghostty は画像プレビューとインライン表示に対応します。WezTerm は Kitty Graphics Protocol の対応が限定的で、インライン画像の表示には対応していません。
Zellij は非対応です。
tmux を検出すると、画像を転送できるよう現在の pane の `allow-passthrough` オプションを有効にします。tmux 設定ファイルは変更しません。
`:checkhealth snacks` でターミナルの検出結果を確認できます。

headless Neovim では画像モジュールを無効にするため、ターミナルへの問い合わせや画像描画データの送信はありません。
PNG は ImageMagick なしで表示できます。他の形式の変換には ImageMagick の `magick` コマンドが必要な場合があります。自動インストールはしません。
