#!/bin/sh
# =============================================================================
# scripts/list-diagram-refs.sh — Markdown が参照する PlantUML 変換図を列挙する
#
# 使い方:
#   scripts/list-diagram-refs.sh file.md...
#
# 引数の Markdown から `](/build/diagrams/<name>.svg` 形式の画像参照を抽出
# し、ルートの `/` を除いたパス(build/diagrams/<name>.svg)を 1 行 1 件・
# 重複排除して出力する。Makefile がこのパスから <name> の 1:1 対応で
# assets/diagrams/<name>.puml を逆引きし、ビルド対象の文書が参照する図だけを
# 変換対象にする。
#
# コードフェンス(``` / ~~~)の中は除外する(記法の説明として書かれた参照
# 例を実参照と誤認すると、存在しないソースの変換を要求してしまうため)。
# =============================================================================
set -eu

awk '
	# CommonMark はフェンス文字の行頭連続数(run 長)で開始・終了を判定する。
	# 3 文字一致だけで見ると、4 バッククォート以上のフェンス内に ``` が
	# 現れたときに誤って閉じてしまう(lint.sh と同じ判定仕様)。
	function fence_run(s,    c, n) {
		c = substr(s, 1, 1)
		n = 0
		while (substr(s, n + 1, 1) == c) n++
		return n
	}
	{
		c = substr($0, 1, 1)
		if (c == "`" || c == "~") {
			n = fence_run($0)
			if (n >= 3) {
				if (in_fence == 0) {
					in_fence = 1
					fence_char = c
					fence_len = n
					next
				}
				rest = substr($0, n + 1)
				gsub(/[ \t]/, "", rest)
				if (c == fence_char && n >= fence_len && rest == "") {
					in_fence = 0
					next
				}
			}
		}
	}
	in_fence { next }
	{
		line = $0
		while (match(line, /\]\(\/build\/diagrams\/[^) ]+\.svg/)) {
			# マッチは "](/build/..." なので、先頭の "](" と "/" を除く
			print substr(line, RSTART + 3, RLENGTH - 3)
			line = substr(line, RSTART + RLENGTH)
		}
	}
' "$@" | sort -u
