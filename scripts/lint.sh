#!/bin/sh
# =============================================================================
# scripts/lint.sh — docs/*.md に対する簡易 lint
#
# 検査内容:
#   エラー(exit 1): 見出し行における手動採番の検出
#     - `# 1. foo` / `## 2) foo` のような `#{1,6} <数字>[.)]` 形式
#     - `# 第1章 foo` のような `#{1,6} 第<数字>章` 形式
#     見出しの番号は Typst 側の #set heading(numbering: "1.1.1") が自動的に
#     付与するため、手動採番があると二重採番(例: 「1 1. はじめに」)に
#     なってしまう(CLAUDE.md 参照)。
#
#   警告(exit 0。ビルドは継続): ```{=typst} ブロック内の装飾コード検出
#     `set text(` / `text(font:` / `text(fill:` / `set page(` のいずれかが
#     含まれる場合、見た目に関する記述は template/spec.typ に一元化すべき
#     旨を警告する。
#
# コードフェンス(``` ... ```)の中身は見出し風の文字列を誤検知しないよう
# スキップする。ただし ```{=typst} フェンスの中身だけは、上記の装飾コード
# 検出の対象とする。
# =============================================================================
set -eu

found_error=0

for f in docs/*.md; do
	[ -f "$f" ] || continue

	in_fence=0
	fence_lang=""
	lineno=0

	while IFS= read -r line || [ -n "$line" ]; do
		lineno=$((lineno + 1))

		case "$line" in
			'```'*)
				if [ "$in_fence" -eq 0 ]; then
					in_fence=1
					fence_lang=$(printf '%s' "$line" | sed 's/^```//')
				else
					in_fence=0
					fence_lang=""
				fi
				continue
				;;
		esac

		if [ "$in_fence" -eq 1 ]; then
			if [ "$fence_lang" = "{=typst}" ]; then
				case "$line" in
					*'set text('*|*'text(font:'*|*'text(fill:'*|*'set page('*)
						trimmed=$(printf '%s' "$line" | sed -E 's/^[[:space:]]+//')
						echo "WARNING: $f:$lineno: 生 Typst ブロック内に装飾コードが見つかりました(美観は spec.typ へ): $trimmed"
						;;
				esac
			fi
			continue
		fi

		case "$line" in
			'#'*)
				if printf '%s' "$line" | grep -Eq '^#{1,6} '; then
					rest=$(printf '%s' "$line" | sed -E 's/^#{1,6} //')
					if printf '%s' "$rest" | grep -Eq '^[0-9]+[.)]'; then
						echo "ERROR: $f:$lineno: 見出しに手動採番が付与されています(自動採番と二重になります): $line"
						found_error=1
					elif printf '%s' "$rest" | grep -Eq '^第[0-9]+章'; then
						echo "ERROR: $f:$lineno: 見出しに手動採番(第N章)が付与されています(自動採番と二重になります): $line"
						found_error=1
					fi
				fi
				;;
		esac
	done < "$f"
done

if [ "$found_error" -eq 1 ]; then
	echo "lint: 見出しの手動採番エラーが見つかりました。上記の該当行を修正してください。" >&2
	exit 1
fi

exit 0
