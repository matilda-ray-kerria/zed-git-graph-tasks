#!/usr/bin/env bash
# Zed のグローバル tasks.json に Git Graph 用カスタムコマンドを追加 (再実行で更新) する
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
使い方: ./install.sh [--dry-run]

tasks.d/*.json を結合し、Zed のグローバル tasks.json に管理ブロックとして追加します。
既に追加済みならブロックを最新の内容に差し替えます。既存のタスクやコメントには触れません。

  --dry-run  書き換えずに差分だけ表示する

環境変数:
  ZED_CONFIG_DIR  Zed の設定ディレクトリ (既定: macOS ~/.config/zed, Linux ${XDG_CONFIG_HOME:-~/.config}/zed)
EOF
}

dry_run=0
while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) dry_run=1 ;;
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
runner="$install_dir/zgt-run"

tmp="$(mktemp -d "${TMPDIR:-/tmp}/zgt.XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

zgt_render_block "$runner" >"$tmp/block" || zgt_die "tasks.d の結合に失敗しました"
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
  zgt_validate_jsonc "$tasks_file" ||
    zgt_die "$tasks_file を JSON 配列として読めませんでした。内容を確認してください (変更していません)"
  case "$(zgt_marker_state "$tasks_file")" in
    ok) zgt_replace_block "$tasks_file" "$tmp/block" >"$tmp/new" ;;
    none)
      zgt_insert_block "$tasks_file" "$tmp/block" >"$tmp/new" ||
        zgt_die "$tasks_file の先頭に配列の [ が見つかりませんでした (変更していません)"
      ;;
    *) zgt_die "$tasks_file の管理ブロックのマーカー ($ZGT_BEGIN / $ZGT_END) が壊れています。手で直してから再実行してください (変更していません)" ;;
  esac
fi

# 書き込む前に、結果が読めることと管理タスクの数を確認する
zgt_validate_jsonc "$tmp/new" || zgt_die "生成結果の検証に失敗しました (変更していません)"
actual="$(zgt_jsonc_to_json "$tmp/new" | jq --arg run "$runner" '[.[] | select(.command == $run)] | length')"
[ "$actual" = "$expected" ] ||
  zgt_die "生成結果のタスク数が一致しません (期待 $expected / 実際 $actual)。変更していません"

if [ "$dry_run" -eq 1 ]; then
  echo "# dry-run: $tasks_file への変更 (書き換えはしていません)"
  if [ -e "$tasks_file" ]; then
    diff -u "$tasks_file" "$tmp/new" || true
  else
    diff -u /dev/null "$tmp/new" || true
  fi
  exit 0
fi

# 先にラッパーを置き、tasks.json から存在しないパスを参照しないようにする
mkdir -p "$install_dir"
cp "$ZGT_ROOT/bin/zgt-run" "$runner.tmp"
chmod 755 "$runner.tmp"
mv -f "$runner.tmp" "$runner"

if [ "$created" -eq 1 ]; then
  printf 'created_tasks_json=1\n' >"$install_dir/state"
elif [ ! -e "$install_dir/state" ]; then
  printf 'created_tasks_json=0\n' >"$install_dir/state"
fi

if [ -e "$tasks_file" ] && cmp -s "$tasks_file" "$tmp/new"; then
  echo "tasks.json は最新です ($expected 個のタスク)。ラッパーを更新しました: $runner"
  exit 0
fi

backup=""
[ -e "$tasks_file" ] && backup="$(zgt_backup "$tasks_file" "$install_dir/backups")"

mkdir -p "$config_dir"
# シンボリックリンクを壊さないよう、mv ではなく上書きで書き込む
cat "$tmp/new" >"$tasks_file"

echo "✓ $expected 個のタスクを追加しました: $tasks_file"
[ -n "$backup" ] && echo "  バックアップ: $backup"
echo "  ラッパー:     $runner"
echo
echo "Zed の Git Graph でブランチ名のラベルを右クリック → Custom Commands から使えます。"
