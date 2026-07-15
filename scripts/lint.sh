#!/bin/sh
# =============================================================================
# scripts/lint.sh — docs/*.md および docs/<name>/(章別ファイル分割)に対する
# 簡易 lint
#
# 使い方:
#   scripts/lint.sh            docs/*.md 全件 + docs/*/ の章別ファイル分割
#                               ディレクトリすべてを対象にする(引数なし)。
#   scripts/lint.sh file...    引数で渡したファイルのみを対象にする
#                               (`make pdf` が SRC のビルド対象だけを渡す)。
#
# --- モード判定 ---------------------------------------------------------
# 各ファイルは、その親ディレクトリ名で「単一ファイルモード」か「章別ファイル
# 分割モード」かを判定する。親ディレクトリ名が `docs` であれば単一ファイル
# モード(例: docs/foo.md)、それ以外であれば章別ファイル分割モード(例:
# docs/foo/01-bar.md の親ディレクトリ名は `foo`)とみなす。
# 章別ファイル分割モードのうち、ファイル名が `00-meta.md` であれば「メタ
# ファイル」(単一ファイルモードと同じフロントマター+title 必須ルール)、
# それ以外は「章ファイル」(フロントマター禁止ルール)として扱う。
#
# --- 検査内容 -------------------------------------------------------------
#
#   エラー(exit 1): YAML フロントマターの title: 欠落・空
#     単一ファイルモードのファイル、および章別ファイル分割の 00-meta.md が
#     対象。ファイル先頭が `---` で始まるフロントマターを持ち、かつその中に
#     `title:` フィールドが無ければエラーにする(フロントマター自体が
#     無い場合もエラー)。`title:` フィールドはあっても値が空(`title:` の
#     みで終わる、または空白のみ)の場合もエラーにする。表紙・ヘッダの
#     表示に title が必須なため。
#
#   エラー(exit 1): 章ファイルへの YAML フロントマター混入
#     章別ファイル分割モードで、00-meta.md 以外の章ファイルの先頭行が `---`
#     の場合にエラーにする。Pandoc は複数入力ファイルを連結するとき、後方の
#     ファイルのフロントマターが前方のフロントマターを上書きする(このリポ
#     ジトリで確認済み)。章ファイルにフロントマターが混入すると、00-meta.md
#     で設定した title 等が意図せず上書き・消去される事故につながるため、
#     章ファイルにはフロントマターを一切書かせない。
#
#   エラー(exit 1): 見出し行における手動採番の検出
#     - `# 1. foo` / `## 2) foo` のような `#{1,6} <数字>[.)]<空白>` 形式
#       (番号 + ドット/括弧 + 空白)
#     - `# 第1章 foo` / `## 第2節 foo` / `### 第3項 bar` のような
#       `#{1,6} 第<数字>(章|節|項)` 形式、および `# 1章 foo` のように
#       「第」を省いた `#{1,6} <数字>(章|節|項)` 形式
#       (実装注記: `第?[0-9]+...` のように `?` を多バイト文字である「第」の
#       直後に付けると、このスクリプトが動く C/POSIX ロケールの grep -E では
#       バイト単位でマッチしてしまい正しく動作しない。そのため
#       `(第[0-9]+|[0-9]+)(章|節|項)` という二分岐の形で書いている)
#     見出しの番号は Typst 側の #set heading(numbering: "1.1.1") が自動的に
#     付与するため、手動採番があると二重採番(例: 「1 1. はじめに」)に
#     なってしまう(CLAUDE.md 参照)。この検査はモードに関わらず全ファイルに
#     適用する。
#
#   警告(exit 0。ビルドは継続): 見出し行が数字で始まる(手動採番の疑い)
#     `# 1 はじめに` / `## 2.5 系` のような `#{1,6} <数字>(.<数字>)*<空白>`
#     形式。ERROR 側のパターン(番号+ドット/括弧、第N章/節/項)に一致しない
#     場合に限る。`## 2.5 系` のようなバージョン表記の正当な見出しも
#     このパターンに一致するため、誤検知の可能性がある旨を警告するに
#     とどめ、ビルドは止めない。
#
#   警告(exit 0。ビルドは継続): ```{=typst} ブロック内の装飾コード検出
#     `set text(` / `text(font:` / `text(fill:` / `set page(` のいずれかが
#     含まれる場合、見た目に関する記述は template/spec.typ に一元化すべき
#     旨を警告する。
#
#   警告(exit 0。ビルドは継続): 章ファイル間での脚注定義 ID の重複
#     章別ファイル分割モードにおいて、同じディレクトリ内の複数の章ファイル
#     (00-meta.md を含む)で同一の脚注定義 ID(`[^id]:`)が使われている場合に
#     警告する。pandoc が複数ファイルを連結すると脚注 ID が衝突するため。
#
# コードフェンス(``` ... ``` または ~~~ ... ~~~)の中身は見出し風の文字列を
# 誤検知しないようスキップする。ただし ```{=typst} / ~~~{=typst} フェンスの
# 中身だけは、上記の装飾コード検出の対象とする。
#
# 除外: <name>.revisions.md(改訂履歴のパイプ表ファイル。単一ファイルモード)
# および revisions.md / revisions.yaml(章別ファイル分割ディレクトリの改訂
# 履歴ファイル)は仕様書本文ではないため lint の対象外とする。
# =============================================================================
set -eu

if [ "$#" -eq 0 ]; then
	set -- docs/*.md
	for d in docs/*/; do
		[ -d "$d" ] || continue
		d=${d%/}
		chapters=""
		for cf in "$d"/[0-9][0-9]-*.md; do
			[ -f "$cf" ] || continue
			chapters="$chapters $cf"
		done
		if [ -n "$chapters" ]; then
			set -- "$@" $chapters
		fi
	done
fi

found_error=0
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

for f in "$@"; do
	[ -f "$f" ] || continue
	case "$f" in
		*.revisions.md) continue ;;
	esac
	base=$(basename "$f")
	case "$base" in
		revisions.md|revisions.yaml) continue ;;
	esac

	parent_dir=$(dirname "$f")
	parent_name=$(basename "$parent_dir")
	is_chapter_mode=0
	if [ "$parent_name" != "docs" ]; then
		is_chapter_mode=1
	fi

	if [ "$is_chapter_mode" -eq 1 ] && [ "$base" != "00-meta.md" ]; then
		# --- 章ファイル: フロントマター混入チェック ---
		first_line=$(head -n1 "$f" || true)
		if [ "$first_line" = "---" ]; then
			echo "ERROR: $f: 章ファイルの先頭に YAML フロントマター(---)が見つかりました。フロントマターは 00-meta.md にのみ書いてください(pandoc で複数ファイルを連結する際、後方ファイルのフロントマターが前方を上書きするため、章ファイルへの混入は意図しない上書き事故につながります)。" >&2
			found_error=1
		fi
	else
		# --- フロントマターの title: チェック(単一ファイルモード / 00-meta.md) ---
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
				title_value=$(awk -v end="$fm_end_lineno" 'NR>1 && NR<end && $0 ~ /^title:[[:space:]]*/ {sub(/^title:[[:space:]]*/, ""); print; exit}' "$f")
				has_title=$(awk -v end="$fm_end_lineno" 'NR>1 && NR<end && $0 ~ /^title:[[:space:]]*/ {print "1"; exit}' "$f")
				if [ -z "$has_title" ]; then
					echo "ERROR: $f: YAML フロントマターに title: が見つかりません(表紙・ヘッダに必要です)。" >&2
					found_error=1
				else
					trimmed_title=$(printf '%s' "$title_value" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
					if [ -z "$trimmed_title" ]; then
						echo "ERROR: $f: YAML フロントマターの title: の値が空です(表紙・ヘッダに必要です)。" >&2
						found_error=1
					fi
				fi
			fi
		fi
	fi

	in_fence=0
	fence_lang=""
	fence_marker=""
	lineno=0

	while IFS= read -r line || [ -n "$line" ]; do
		lineno=$((lineno + 1))

		case "$line" in
			'```'*|'~~~'*)
				marker=$(printf '%s' "$line" | cut -c1-3)
				if [ "$in_fence" -eq 0 ]; then
					in_fence=1
					fence_marker="$marker"
					fence_lang=$(printf '%s' "$line" | sed -E 's/^(```|~~~)//')
					continue
				elif [ "$marker" = "$fence_marker" ]; then
					in_fence=0
					fence_lang=""
					fence_marker=""
					continue
				fi
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
					if printf '%s' "$rest" | grep -Eq '^[0-9]+[.)] '; then
						echo "ERROR: $f:$lineno: 見出しに手動採番が付与されています(自動採番と二重になります): $line"
						found_error=1
					elif printf '%s' "$rest" | grep -Eq '^(第[0-9]+|[0-9]+)(章|節|項)'; then
						echo "ERROR: $f:$lineno: 見出しに手動採番(第N章/節/項)が付与されています(自動採番と二重になります): $line"
						found_error=1
					elif printf '%s' "$rest" | grep -Eq '^[0-9]+(\.[0-9]+)* '; then
						echo "WARNING: $f:$lineno: 見出しが数字で始まっています(手動採番の可能性があります。バージョン表記などの正当な見出しであれば無視してください): $line"
					fi
				fi
				;;
		esac

		# --- 脚注定義 ID の収集(章別ファイル分割時の重複検出用) ---
		if [ "$is_chapter_mode" -eq 1 ]; then
			case "$line" in
				'[^'*)
					fid=$(printf '%s' "$line" | sed -n -E 's/^\[\^([^]]+)\]:.*/\1/p')
					if [ -n "$fid" ]; then
						key=$(printf '%s' "$parent_dir" | cksum | awk '{print $1}')
						printf '%s\t%s\n' "$fid" "$f" >> "$tmp/footnotes-$key.txt"
					fi
					;;
			esac
		fi
	done < "$f"
done

# --- 脚注定義 ID の重複チェック(章別ファイル分割ディレクトリごと) ---
for accum in "$tmp"/footnotes-*.txt; do
	[ -f "$accum" ] || continue
	awk -F'\t' '
		{
			pair = $1 SUBSEP $2
			if (!(pair in seen)) {
				seen[pair] = 1
				count[$1]++
				files[$1] = files[$1] " " $2
			}
		}
		END {
			for (id in count) {
				if (count[id] > 1) {
					printf "WARNING: 脚注ID \"[^%s]\" が複数の章ファイルで重複定義されています(pandoc 連結時に衝突します):%s\n", id, files[id]
				}
			}
		}
	' "$accum"
done

if [ "$found_error" -eq 1 ]; then
	echo "lint: 見出しの手動採番エラー・フロントマターの不備・章ファイルへのフロントマター混入のいずれかが見つかりました。上記の該当行を修正してください。" >&2
	exit 1
fi

exit 0
