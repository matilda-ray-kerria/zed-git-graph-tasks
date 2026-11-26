#!/usr/bin/env bash
# tasks.d/*.json (断片ファイル) を結合し、1 つの JSON 配列として標準出力に出す
set -euo pipefail

ZGT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$ZGT_ROOT/lib/common.sh"

# メッセージの言語は環境変数 ZGT_LANG (install.sh が渡す)。無い / 不明なら英語
zgt_load_lang "${ZGT_LANG:-en}" || zgt_load_lang en

expand=0
while [ $# -gt 0 ]; do
  case "$1" in
    --expand)
      expand=1
      shift
      ;;
    -h | --help)
      printf '%s\n' "$MSG_BUILD_USAGE"
      exit 0
      ;;
    *) zgt_die "$(zgt_msg UNKNOWN_ARG "$1")" ;;
  esac
done

zgt_require jq

shopt -s nullglob
files=("$ZGT_ROOT"/tasks.d/*.json)
[ ${#files[@]} -gt 0 ] || zgt_die "$(zgt_msg NO_FRAGMENTS)"

for f in "${files[@]}"; do
  jq -e 'type == "array" and all(.[]; type == "object"
           and (.label | type) == "string" and (.command | type) == "string")' \
    "$f" >/dev/null || zgt_die "$(zgt_msg BAD_FRAGMENT "$f")"
done

if [ "$expand" -eq 0 ]; then
  jq -s --indent 2 'add' "${files[@]}"
  exit 0
fi

# "command": "__ZGT_RUN__" を sh -c <起動スクリプト> zgt-run <args...> に置き換える
jq -s --indent 2 --arg placeholder "$ZGT_PLACEHOLDER" --arg loader "$(zgt_loader)" '
  add | map(if .command == $placeholder
    then .command = "sh" | .args = ["-c", $loader, "zgt-run"] + (.args // [])
    else . end)' "${files[@]}"
