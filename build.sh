#!/usr/bin/env bash
# tasks.d/*.json (断片ファイル) を結合し、1 つの JSON 配列として標準出力に出す
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

usage() {
  cat <<'EOF'
使い方: ./build.sh [--runner PATH]

tasks.d/*.json を名前順に結合して標準出力に出します。
  --runner PATH  "command": "__ZGT_RUN__" を PATH に置き換える (install.sh が使用)
EOF
}

runner="$ZGT_PLACEHOLDER"
while [ $# -gt 0 ]; do
  case "$1" in
    --runner)
      [ $# -ge 2 ] || zgt_die "--runner には値が必要です"
      runner="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *) zgt_die "不明な引数: $1" ;;
  esac
done

zgt_require jq

shopt -s nullglob
files=("$ZGT_ROOT"/tasks.d/*.json)
[ ${#files[@]} -gt 0 ] || zgt_die "tasks.d/*.json がありません"

for f in "${files[@]}"; do
  jq -e 'type == "array" and all(.[]; type == "object"
           and (.label | type) == "string" and (.command | type) == "string")' \
    "$f" >/dev/null ||
    zgt_die "不正な断片ファイル: $f (label と command を持つオブジェクトの配列にしてください)"
done

jq -s --indent 2 --arg placeholder "$ZGT_PLACEHOLDER" --arg run "$runner" \
  'add | map(if .command == $placeholder then .command = $run else . end)' \
  "${files[@]}"
