#!/usr/bin/env bash
# install.sh で追加した管理ブロックとラッパーを取り除く
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

config_dir="$(zgt_config_dir)"
tasks_file="$config_dir/tasks.json"
install_dir="$config_dir/$ZGT_NAME"
state="$install_dir/state"

# メッセージはインストール時に選んだ言語で出す (無ければ英語)
zgt_load_lang "$(zgt_state_get "$state" lang)" || zgt_load_lang en

dry_run=0
purge=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --purge) purge=1 ;;
    -h | --help)
      printf '%s\n' "$MSG_UNINSTALL_USAGE"
      exit 0
      ;;
    *) zgt_die "$(zgt_msg UNKNOWN_ARG "$1")" ;;
  esac
  shift
done

zgt_require jq awk sed diff

tmp="$(mktemp -d "${TMPDIR:-/tmp}/zgt.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

action=none # none / rewrite / delete
if [ -f "$tasks_file" ]; then
  case "$(zgt_marker_state "$tasks_file")" in
    none) ;;
    ok)
      zgt_strip_block "$tasks_file" >"$tmp/new"
      action=rewrite
      if [ "$(zgt_state_get "$state" created_tasks_json)" = 1 ] &&
        [ "$(tr -d ' \t\r\n' <"$tmp/new")" = "[]" ]; then
        # install.sh が新規作成し、他に何も書かれていなければファイルごと消す
        action=delete
      elif grep -q '[^[:space:]]' "$tmp/new"; then
        zgt_validate_jsonc "$tmp/new" || zgt_die "$(zgt_msg STRIP_VERIFY_FAILED)"
      fi
      ;;
    *) zgt_die "$(zgt_msg BROKEN_MARKERS "$tasks_file" "$ZGT_BEGIN" "$ZGT_END")" ;;
  esac
fi

say() {
  zgt_msg "$@"
  echo
}

if [ "$dry_run" -eq 1 ]; then
  say DRYRUN
  case "$action" in
    none) say NO_BLOCK "$tasks_file" ;;
    rewrite) diff -u "$tasks_file" "$tmp/new" || true ;;
    delete) say WILL_DELETE "$tasks_file" ;;
  esac
  [ -d "$install_dir" ] && say WILL_REMOVE_RUNNER "$install_dir"
  [ "$purge" -eq 1 ] && [ -d "$install_dir" ] && say WILL_PURGE "$install_dir"
  exit 0
fi

backup=""
case "$action" in
  none) say NO_BLOCK "$tasks_file" ;;
  rewrite)
    backup="$(zgt_backup "$tasks_file" "$install_dir/backups")"
    cat "$tmp/new" >"$tasks_file"
    say BLOCK_REMOVED "$tasks_file"
    ;;
  delete)
    backup="$(zgt_backup "$tasks_file" "$install_dir/backups")"
    rm -f "$tasks_file"
    say DELETED "$tasks_file"
    ;;
esac

if [ -d "$install_dir" ]; then
  rm -f "$install_dir/zgt-run" "$install_dir/messages.sh" "$state"
  if [ "$purge" -eq 1 ]; then
    rm -rf "$install_dir"
    say PURGED "$install_dir"
  else
    rmdir "$install_dir/backups" 2>/dev/null || true
    rmdir "$install_dir" 2>/dev/null || true
    [ -n "$backup" ] && say BACKUP_AT "$backup"
    [ -d "$install_dir" ] && say PURGE_HINT
  fi
fi
exit 0
