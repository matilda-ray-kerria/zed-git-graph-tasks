# shellcheck shell=bash
# install.sh / uninstall.sh / build.sh の共通処理

ZGT_NAME="zed-git-graph-tasks"
ZGT_BEGIN="// >>> ${ZGT_NAME}"
ZGT_END="// <<< ${ZGT_NAME}"
ZGT_PLACEHOLDER="__ZGT_RUN__"

zgt_die() {
  printf 'error: %s\n' "$*" >&2
  exit 1
}

zgt_require() {
  local cmd
  for cmd in "$@"; do
    command -v "$cmd" >/dev/null 2>&1 || zgt_die "'$cmd' が見つかりません。インストールしてから再実行してください。"
  done
}

# Zed の設定ディレクトリ。Zed 本体の paths::config_dir() に合わせる:
#   macOS: ~/.config/zed   Linux: ${XDG_CONFIG_HOME:-~/.config}/zed
# ZED_CONFIG_DIR で上書きできる (Flatpak 版などパスが異なる場合)
zgt_config_dir() {
  if [ -n "${ZED_CONFIG_DIR:-}" ]; then
    printf '%s\n' "$ZED_CONFIG_DIR"
  elif [ "$(uname -s)" = "Darwin" ]; then
    printf '%s\n' "$HOME/.config/zed"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/zed"
  fi
}

# Zed の tasks.json (コメント・末尾カンマ可) を厳密な JSON に変換して標準出力へ出す
zgt_jsonc_to_json() {
  LC_ALL=C awk '
    function ws(c) { if (pending) pbuf = pbuf c; else printf "%s", c }
    function flush() { if (pending) { printf ",%s", pbuf; pending = 0; pbuf = "" } }
    {
      line = $0; n = length(line); i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (inblock) {
          if (c == "*" && substr(line, i + 1, 1) == "/") { inblock = 0; i += 2; continue }
          i++; continue
        }
        if (instr) {
          printf "%s", c
          if (esc) esc = 0
          else if (c == "\\") esc = 1
          else if (c == "\"") instr = 0
          i++; continue
        }
        if (c == "/" && substr(line, i + 1, 1) == "/") break
        if (c == "/" && substr(line, i + 1, 1) == "*") { inblock = 1; i += 2; continue }
        if (c == " " || c == "\t" || c == "\r") { ws(c); i++; continue }
        if (c == ",") { flush(); pending = 1; pbuf = ""; i++; continue }
        if (c == "]" || c == "}") {
          if (pending) { printf "%s", pbuf; pending = 0; pbuf = "" }
          printf "%s", c; i++; continue
        }
        flush()
        if (c == "\"") instr = 1
        printf "%s", c
        i++
      }
      ws("\n")
    }
    END { flush() }
  ' "$1"
}

# tasks.json として読めるか (トップレベルが配列か) を確認する
zgt_validate_jsonc() {
  zgt_jsonc_to_json "$1" | jq -e 'type == "array"' >/dev/null 2>&1
}

# 管理ブロックの状態: none / ok / broken
zgt_marker_state() {
  ZGT_B="$ZGT_BEGIN" ZGT_E="$ZGT_END" LC_ALL=C awk '
    BEGIN { b = ENVIRON["ZGT_B"]; e = ENVIRON["ZGT_E"] }
    { t = $0; sub(/^[ \t]+/, "", t) }
    index(t, b) == 1 { nb++; if (!lb) lb = NR }
    index(t, e) == 1 { ne++; if (!le) le = NR }
    END {
      if (nb == 0 && ne == 0) print "none"
      else if (nb == 1 && ne == 1 && lb < le) print "ok"
      else print "broken"
    }
  ' "$1"
}

# 管理ブロック (マーカー行を含む) を取り除いた内容を出力する
zgt_strip_block() {
  ZGT_B="$ZGT_BEGIN" ZGT_E="$ZGT_END" LC_ALL=C awk '
    BEGIN { b = ENVIRON["ZGT_B"]; e = ENVIRON["ZGT_E"] }
    { t = $0; sub(/^[ \t]+/, "", t) }
    !skip && index(t, b) == 1 { skip = 1; next }
    skip && index(t, e) == 1 { skip = 0; next }
    !skip { print }
  ' "$1"
}

# 既存の管理ブロックを $2 の内容に差し替えて出力する
zgt_replace_block() {
  ZGT_B="$ZGT_BEGIN" ZGT_E="$ZGT_END" ZGT_BLOCK="$2" LC_ALL=C awk '
    BEGIN { b = ENVIRON["ZGT_B"]; e = ENVIRON["ZGT_E"]; bf = ENVIRON["ZGT_BLOCK"] }
    { t = $0; sub(/^[ \t]+/, "", t) }
    !skip && index(t, b) == 1 {
      while ((getline l < bf) > 0) print l
      close(bf); skip = 1; next
    }
    skip && index(t, e) == 1 { skip = 0; next }
    !skip { print }
  ' "$1"
}

# トップレベル配列の "[" の直後に $2 の内容を差し込んで出力する
# 終了コード 3: 最初の要素が "[" ではない
zgt_insert_block() {
  ZGT_BLOCK="$2" LC_ALL=C awk '
    BEGIN { bf = ENVIRON["ZGT_BLOCK"] }
    done { print; next }
    {
      line = $0; n = length(line); i = 1
      while (i <= n) {
        c = substr(line, i, 1)
        if (inblock) {
          if (c == "*" && substr(line, i + 1, 1) == "/") { inblock = 0; i += 2; continue }
          i++; continue
        }
        if (c == " " || c == "\t" || c == "\r") { i++; continue }
        if (c == "/" && substr(line, i + 1, 1) == "/") break
        if (c == "/" && substr(line, i + 1, 1) == "*") { inblock = 1; i += 2; continue }
        if (c == "[") {
          print substr(line, 1, i)
          while ((getline l < bf) > 0) print l
          close(bf)
          rest = substr(line, i + 1)
          if (rest !~ /^[ \t\r]*$/) print rest
          done = 1
          break
        }
        bad = 1
        exit 3
      }
      if (!done) print
    }
    END { if (bad || !done) exit 3 }
  ' "$1"
}

# tasks.d を結合し、tasks.json に差し込む管理ブロックを出力する
zgt_render_block() {
  local entries
  entries="$("$ZGT_ROOT/build.sh" --runner "$1")" || return 1
  printf '  %s (install.sh が管理。このブロック内は編集しないでください)\n' "$ZGT_BEGIN"
  printf '%s\n' "$entries" | sed '1d;$d' | sed '$s/$/,/'
  printf '  %s\n' "$ZGT_END"
}

# 書き換え前のバックアップを取り、そのパスを出力する
zgt_backup() {
  local src="$1" dir="$2" dest
  mkdir -p "$dir"
  dest="$dir/tasks.json.$(date +%Y%m%d-%H%M%S).$$"
  cp "$src" "$dest"
  printf '%s\n' "$dest"
}
