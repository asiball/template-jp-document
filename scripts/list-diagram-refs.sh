#!/bin/sh
# =============================================================================
# scripts/list-diagram-refs.sh — Markdown が参照する PlantUML ソースを列挙する
#
# 使い方:
#   scripts/list-diagram-refs.sh file.md...
#
# 引数の Markdown から `](/assets/diagrams/<name>.puml` 形式の画像参照を抽出
# し、ルートの `/` を除いたパス(assets/diagrams/<name>.puml)を 1 行 1 件・
# 重複排除して出力する。Makefile がこの出力から変換対象 SVG の依存関係を
# 組み立てる(ビルド対象の文書が参照する図だけを変換し、図を使わない文書の
# ビルドに plantuml を要求しないため)。
#
# コードフェンス(``` / ~~~)の中は除外する(記法の説明として書かれた参照
# 例を実参照と誤認すると、存在しないファイルの変換を要求してしまうため)。
# =============================================================================
set -eu

awk '
	/^(```|~~~)/ {
		marker = substr($0, 1, 3)
		if (in_fence) {
			if (marker == fence_marker) { in_fence = 0 }
		} else {
			in_fence = 1
			fence_marker = marker
		}
		next
	}
	in_fence { next }
	{
		line = $0
		while (match(line, /\]\(\/assets\/diagrams\/[^) ]+\.puml/)) {
			# マッチは "](/assets/..." なので、先頭の "](" と "/" を除く
			print substr(line, RSTART + 3, RLENGTH - 3)
			line = substr(line, RSTART + RLENGTH)
		}
	}
' "$@" | sort -u
