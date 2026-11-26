#!/usr/bin/env bash
# Zed のグローバル tasks.json に Git Graph 用カスタムコマンドを追加 (再実行で更新) する。
# --remote <host> のときは、SSH 接続先に zgt-run と messages.sh だけを置く
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

# 引数より先にメッセージが要る場合に備えて英語を読んでおく
zgt_load_lang en

dry_run=0
help=0
lang=""
remote_host=""
bad_arg=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --lang)
      [ $# -ge 2 ] || zgt_die "$(zgt_msg NEEDS_VALUE --lang)"
      lang="$2"
      shift
      ;;
    --lang=*) lang="${1#--lang=}" ;;
    --remote)
      [ $# -ge 2 ] || zgt_die "$(zgt_msg NEEDS_VALUE --remote)"
      remote_host="$2"
      shift
      ;;
    --remote=*) remote_host="${1#--remote=}" ;;
    -h | --help) help=1 ;;
    *) [ -n "$bad_arg" ] || bad_arg="$1" ;;
  esac
  shift
done

config_dir="$(zgt_config_dir)"
tasks_file="$config_dir/tasks.json"
install_dir="$config_dir/$ZGT_NAME" # state と backups (tasks.json の管理用)
data_dir="$(zgt_data_dir)"          # zgt-run と messages.sh
runner="$data_dir/zgt-run"
state="$install_dir/state"

# 言語: --lang > 前回の選択 > 英語
[ -n "$lang" ] || lang="$(zgt_state_get "$state" lang)"
[ -n "$lang" ] || lang=en
zgt_load_lang "$lang" || zgt_die "$(zgt_msg UNKNOWN_LANG "$lang" "$(zgt_languages)")"
export ZGT_LANG="$lang"

[ -z "$bad_arg" ] || zgt_die "$(zgt_msg UNKNOWN_ARG "$bad_arg")"
if [ "$help" -eq 1 ]; then
  printf '%s\n' "$MSG_INSTALL_USAGE"
  exit 0
fi

# ---- SSH 接続先に zgt-run を置く ----
if [ -n "$remote_host" ]; then
  ssh_cmd="${ZGT_SSH:-ssh}"
  zgt_require tar "$ssh_cmd"
  # shellcheck disable=SC2016
  remote_dir='$HOME/.local/share/'"$ZGT_NAME"
  if [ "$dry_run" -eq 1 ]; then
    zgt_msg REMOTE_DRYRUN "$remote_host" "~/.local/share/$ZGT_NAME" "$MSG_LANG_NAME"
    echo
    exit 0
  fi
  stage="$(mktemp -d "${TMPDIR:-/tmp}/zgt.XXXXXX")"
  trap 'rm -rf "$stage"' EXIT
  cp "$ZGT_ROOT/bin/zgt-run" "$stage/zgt-run"
  cp "$ZGT_ROOT/lang/$lang.sh" "$stage/messages.sh"
  chmod 755 "$stage/zgt-run"
  # 接続先のログインシェルが何であっても動くよう sh -c '...' で包む (中身に ' を含めない)
  remote_script="set -e; d=\"$remote_dir\"; mkdir -p \"\$d\"; tar -xf - -C \"\$d\"; chmod 755 \"\$d/zgt-run\"; for c in bash git; do command -v \$c >/dev/null 2>&1 || echo missing:\$c; done"
  out="$(tar -cf - -C "$stage" zgt-run messages.sh | "$ssh_cmd" "$remote_host" "sh -c '$remote_script'")" ||
    zgt_die "$(zgt_msg REMOTE_FAILED "$remote_host")"
  zgt_msg REMOTE_INSTALLED "$remote_host" "~/.local/share/$ZGT_NAME"
  echo
  zgt_msg LANG_AT "$MSG_LANG_NAME"
  echo
  for c in $(printf '%s\n' "$out" | sed -n 's/^missing://p'); do
    zgt_msg REMOTE_MISSING_CMD "$remote_host" "$c"
    echo
  done
  exit 0
fi

# ---- ローカルにインストールする ----
zgt_require jq awk sed diff

tmp="$(mktemp -d "${TMPDIR:-/tmp}/zgt.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

zgt_render_block >"$tmp/block" || zgt_die "$(zgt_msg BUILD_FAILED)"
expected="$("$ZGT_ROOT/build.sh" | jq 'length')"
loader="$(zgt_loader)"

created=0
if [ ! -e "$tasks_file" ] || ! grep -q '[^[:space:]]' "$tasks_file"; then
  # 無い / 空のファイルは新しく作る
  {
    printf '[\n'
    cat "$tmp/block"
    printf ']\n'
  } >"$tmp/new"
  [ -e "$tasks_file" ] || created=1
else
  zgt_validate_jsonc "$tasks_file" || zgt_die "$(zgt_msg TASKS_UNREADABLE "$tasks_file")"
  case "$(zgt_marker_state "$tasks_file")" in
    ok) zgt_replace_block "$tasks_file" "$tmp/block" >"$tmp/new" ;;
    none)
      zgt_insert_block "$tasks_file" "$tmp/block" >"$tmp/new" ||
        zgt_die "$(zgt_msg NO_ARRAY_START "$tasks_file")"
      ;;
    *) zgt_die "$(zgt_msg BROKEN_MARKERS "$tasks_file" "$ZGT_BEGIN" "$ZGT_END")" ;;
  esac
fi

# 書き込む前に、結果が読めることと管理タスクの数を確認する
zgt_validate_jsonc "$tmp/new" || zgt_die "$(zgt_msg VERIFY_FAILED)"
actual="$(zgt_jsonc_to_json "$tmp/new" |
  jq --arg loader "$loader" '[.[] | select(.command == "sh" and .args[1] == $loader)] | length')"
[ "$actual" = "$expected" ] || zgt_die "$(zgt_msg COUNT_MISMATCH "$expected" "$actual")"

if [ "$dry_run" -eq 1 ]; then
  zgt_msg DRYRUN_INSTALL "$tasks_file"
  echo
  if [ -e "$tasks_file" ]; then
    diff -u "$tasks_file" "$tmp/new" || true
  else
    diff -u /dev/null "$tmp/new" || true
  fi
  exit 0
fi

# 先にラッパーとメッセージを置き、tasks.json から存在しないファイルを参照しないようにする
mkdir -p "$data_dir" "$install_dir"
cp "$ZGT_ROOT/lang/$lang.sh" "$data_dir/messages.sh.tmp"
mv -f "$data_dir/messages.sh.tmp" "$data_dir/messages.sh"
cp "$ZGT_ROOT/bin/zgt-run" "$runner.tmp"
chmod 755 "$runner.tmp"
mv -f "$runner.tmp" "$runner"
# 以前の版の置き場所 (Zed の設定ディレクトリ) に残っていれば消す
rm -f "$install_dir/zgt-run" "$install_dir/messages.sh"

# state: tasks.json を新しく作ったか (アンインストール時に消してよいか) と、選んだ言語
[ "$created" -eq 1 ] || [ "$(zgt_state_get "$state" created_tasks_json)" != 1 ] || created=1
printf 'created_tasks_json=%s\nlang=%s\n' "$created" "$lang" >"$state"

if [ -e "$tasks_file" ] && cmp -s "$tasks_file" "$tmp/new"; then
  zgt_msg UP_TO_DATE "$expected" "$runner"
  echo
  zgt_msg LANG_AT "$MSG_LANG_NAME"
  echo
  zgt_msg REMOTE_HINT
  echo
  exit 0
fi

backup=""
[ -e "$tasks_file" ] && backup="$(zgt_backup "$tasks_file" "$install_dir/backups")"

mkdir -p "$config_dir"
# シンボリックリンクを壊さないよう、mv ではなく上書きで書き込む
cat "$tmp/new" >"$tasks_file"

zgt_msg INSTALLED "$expected" "$tasks_file"
echo
[ -n "$backup" ] && zgt_msg BACKUP_AT "$backup" && echo
zgt_msg RUNNER_AT "$runner"
echo
zgt_msg LANG_AT "$MSG_LANG_NAME"
echo
echo
zgt_msg HOW_TO_USE
echo
zgt_msg REMOTE_HINT
echo
