#!/usr/bin/env bash
# Zed のグローバル tasks.json に Git Graph 用カスタムコマンドを追加 (再実行で更新) する
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

# 引数より先にメッセージが要る場合に備えて英語を読んでおく
zgt_load_lang en

dry_run=0
help=0
lang=""
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
    -h | --help) help=1 ;;
    *) [ -n "$bad_arg" ] || bad_arg="$1" ;;
  esac
  shift
done

config_dir="$(zgt_config_dir)"
tasks_file="$config_dir/tasks.json"
install_dir="$config_dir/$ZGT_NAME"
runner="$install_dir/zgt-run"
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

zgt_require jq awk sed diff

tmp="$(mktemp -d "${TMPDIR:-/tmp}/zgt.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

zgt_render_block "$runner" >"$tmp/block" || zgt_die "$(zgt_msg BUILD_FAILED)"
expected="$("$ZGT_ROOT/build.sh" | jq 'length')"

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
actual="$(zgt_jsonc_to_json "$tmp/new" | jq --arg run "$runner" '[.[] | select(.command == $run)] | length')"
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

# 先にラッパーとメッセージを置き、tasks.json から存在しないパスを参照しないようにする
mkdir -p "$install_dir"
cp "$ZGT_ROOT/lang/$lang.sh" "$install_dir/messages.sh.tmp"
mv -f "$install_dir/messages.sh.tmp" "$install_dir/messages.sh"
cp "$ZGT_ROOT/bin/zgt-run" "$runner.tmp"
chmod 755 "$runner.tmp"
mv -f "$runner.tmp" "$runner"

# state: tasks.json を新しく作ったか (アンインストール時に消してよいか) と、選んだ言語
[ "$created" -eq 1 ] || [ "$(zgt_state_get "$state" created_tasks_json)" != 1 ] || created=1
printf 'created_tasks_json=%s\nlang=%s\n' "$created" "$lang" >"$state"

if [ -e "$tasks_file" ] && cmp -s "$tasks_file" "$tmp/new"; then
  zgt_msg UP_TO_DATE "$expected" "$runner"
  echo
  zgt_msg LANG_AT "$MSG_LANG_NAME"
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
