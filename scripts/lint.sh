#!/bin/sh
# =============================================================================
# scripts/lint.sh — docs/*.md に対する簡易 lint
#
# 使い方:
#   scripts/lint.sh            docs/*.md 全件を対象にする(引数なし)
#   scripts/lint.sh file...    引数で渡したファイルのみを対象にする
#
# 検査内容:
#   エラー(exit 1): YAML フロントマターの title: 欠落
#     ファイル先頭が `---` で始まるフロントマターを持ち、かつその中に
#     `title:` フィールドが無ければエラーにする(フロントマター自体が
#     無い場合もエラー)。表紙・ヘッダの表示に title が必須なため。
#
#   エラー(exit 1): 見出し行における手動採番の検出
#     - `# 1. foo` / `## 2) foo` のような `#{1,6} <数字>[.)]` 形式
#     - `# 第1章 foo` / `## 第2節 foo` / `### 第3項 bar` のような
#       `#{1,6} 第<数字>(章|節|項)` 形式
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
#
# 注意: これは簡易チェックであり、数値で始まる正当な見出し(例:
# `## 2.5 系` のようなバージョン表記)も誤検知しうる。該当する場合は
# 見出しの書き方を変えて回避すること。
# =============================================================================
set -eu

if [ "$#" -eq 0 ]; then
	set -- docs/*.md
fi

found_error=0

for f in "$@"; do
	[ -f "$f" ] || continue

	# --- フロントマターの title: チェック ---
	first_line=$(head -n1 "$f" || true)
	if [ "$first_line" != "---" ]; then
		echo "ERROR: $f: YAML フロントマター(ファイル先頭の --- ブロック)が見つかりません(表紙・ヘッダに title が必要です)。" >&2
		found_error=1
	else
		fm_end_lineno=$(awk 'NR>1 && $0=="---" {print NR; exit}' "$f")
		if [ -z "$fm_end_lineno" ]; then
			echo "ERROR: $f: YAML フロントマターの終端(---)が見つかりません(表紙・ヘッダに title が必要です)。" >&2
			found_error=1
		else
			has_title=$(awk -v end="$fm_end_lineno" 'NR>1 && NR<end && $0 ~ /^title:[[:space:]]*/ {print "1"; exit}' "$f")
			if [ -z "$has_title" ]; then
				echo "ERROR: $f: YAML フロントマターに title: が見つかりません(表紙・ヘッダに必要です)。" >&2
				found_error=1
			fi
		fi
	fi

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
					elif printf '%s' "$rest" | grep -Eq '^第[0-9]+(章|節|項)'; then
						echo "ERROR: $f:$lineno: 見出しに手動採番(第N章/節/項)が付与されています(自動採番と二重になります): $line"
						found_error=1
					fi
				fi
				;;
		esac
	done < "$f"
done

if [ "$found_error" -eq 1 ]; then
	echo "lint: 見出しの手動採番エラーまたはフロントマターの不備が見つかりました。上記の該当行を修正してください。" >&2
	exit 1
fi

exit 0
