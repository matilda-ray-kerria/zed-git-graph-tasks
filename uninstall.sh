#!/usr/bin/env bash
# install.sh で追加した管理ブロックとラッパーを取り除く
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
使い方: ./uninstall.sh [--dry-run] [--purge]

Zed のグローバル tasks.json から管理ブロックだけを取り除き、ラッパーを削除します。
ブロック外のタスクやコメントには触れません。

  --dry-run  書き換えずに差分だけ表示する
  --purge    バックアップも含めて設定ディレクトリ内の zed-git-graph-tasks/ を削除する

環境変数:
  ZED_CONFIG_DIR  Zed の設定ディレクトリ (既定: macOS ~/.config/zed, Linux ${XDG_CONFIG_HOME:-~/.config}/zed)
EOF
}

dry_run=0
purge=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
    --purge) purge=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) zgt_die "不明な引数: $1" ;;
  esac
  shift
done

zgt_require jq awk sed diff

config_dir="$(zgt_config_dir)"
tasks_file="$config_dir/tasks.json"
install_dir="$config_dir/$ZGT_NAME"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/zgt.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

action=none # none / rewrite / delete
if [ -f "$tasks_file" ]; then
  case "$(zgt_marker_state "$tasks_file")" in
    none) ;;
    ok)
      zgt_strip_block "$tasks_file" >"$tmp/new"
      action=rewrite
      if grep -qx 'created_tasks_json=1' "$install_dir/state" 2>/dev/null &&
        [ "$(tr -d ' \t\r\n' <"$tmp/new")" = "[]" ]; then
        # install.sh が新規作成し、他に何も書かれていなければファイルごと消す
        action=delete
      elif grep -q '[^[:space:]]' "$tmp/new"; then
        zgt_validate_jsonc "$tmp/new" ||
          zgt_die "ブロック削除後の内容を検証できませんでした (変更していません)"
      fi
      ;;
    *) zgt_die "$tasks_file の管理ブロックのマーカー ($ZGT_BEGIN / $ZGT_END) が壊れています。手で直してから再実行してください (変更していません)" ;;
  esac
fi

if [ "$dry_run" -eq 1 ]; then
  echo "# dry-run (書き換えはしていません)"
  case "$action" in
    none) echo "$tasks_file に管理ブロックはありません" ;;
    rewrite) diff -u "$tasks_file" "$tmp/new" || true ;;
    delete) echo "$tasks_file を削除します (install.sh が作成したファイルのため)" ;;
  esac
  [ -d "$install_dir" ] && echo "$install_dir/zgt-run と state を削除します"
  [ "$purge" -eq 1 ] && [ -d "$install_dir" ] && echo "$install_dir をバックアップごと削除します"
  exit 0
fi

backup=""
case "$action" in
  none) echo "$tasks_file に管理ブロックはありません" ;;
  rewrite)
    backup="$(zgt_backup "$tasks_file" "$install_dir/backups")"
    cat "$tmp/new" >"$tasks_file"
    echo "✓ 管理ブロックを取り除きました: $tasks_file"
    ;;
  delete)
    backup="$(zgt_backup "$tasks_file" "$install_dir/backups")"
    rm -f "$tasks_file"
    echo "✓ $tasks_file を削除しました (install.sh が作成したファイルのため)"
    ;;
esac

if [ -d "$install_dir" ]; then
  rm -f "$install_dir/zgt-run" "$install_dir/state"
  if [ "$purge" -eq 1 ]; then
    rm -rf "$install_dir"
    echo "✓ $install_dir を削除しました"
  else
    rmdir "$install_dir/backups" 2>/dev/null || true
    rmdir "$install_dir" 2>/dev/null || true
    [ -n "$backup" ] && echo "  バックアップ: $backup"
    [ -d "$install_dir" ] && echo "  (バックアップを消すには ./uninstall.sh --purge)"
  fi
fi
exit 0
