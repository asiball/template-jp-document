#!/bin/sh
# =============================================================================
# scripts/container-build.sh — ビルド本体(Docker コンテナ内で実行される)
#
# `make pdf` / `make watch` が docker run 経由で呼び出す。ビルド対象の導出と
# 検証は Makefile 側(validate-src)が行い、結果を環境変数で受け取る。
#
# 環境変数(Makefile が設定する):
#   NAME           文書名(出力ファイル名の元)
#   SRC_INPUTS     pandoc に渡す Markdown(空白区切り。章別ファイル分割では複数)
#   REV_MD         存在する場合のみ: 改訂履歴の Markdown 表ファイルのパス
#   REV_YAML       存在する場合のみ: 改訂履歴の YAML ファイルのパス
#   DIAGRAM_PUMLS  参照図に対応する .puml の一覧(空白区切り。空なら図なし)
#   WATCH          1 なら初回ビルド後に watch モードへ移行する
#   FONT_DIR       フォントの場所(既定: /opt/fonts。イメージ外で実行する
#                  非サポートのローカルビルド時のみ上書きする)
#
# watch モード: 初回ビルド後に typst watch をバックグラウンド起動し、原稿・
# 改訂履歴・参照図の .puml・plantuml.config を 1 秒間隔でポーリングして、
# 変更検知のたびに lint → 変換 → pandoc を再実行する(.typ の再生成を
# typst watch が拾って PDF に反映する)。lint / 変換 / pandoc のエラーでは
# 停止せず監視を継続する。Ctrl-C で typst watch ごと終了する。
# =============================================================================
set -eu

NAME=${NAME:?}
SRC_INPUTS=${SRC_INPUTS:?}
REV_MD=${REV_MD:-}
REV_YAML=${REV_YAML:-}
DIAGRAM_PUMLS=${DIAGRAM_PUMLS:-}
WATCH=${WATCH:-}
FONT_DIR=${FONT_DIR:-/opt/fonts}

BUILD=build
OBJ=$BUILD/obj
DIAGRAM_OUT=$BUILD/diagrams
TEMPLATE=template/template.typ
PLANTUML_CONFIG=template/plantuml.config

if [ -n "$REV_MD" ]; then
	REV_BUILD_YAML="$OBJ/$NAME.revisions.yaml"
	METADATA_FLAG="--metadata-file $REV_BUILD_YAML"
elif [ -n "$REV_YAML" ]; then
	METADATA_FLAG="--metadata-file $REV_YAML"
else
	METADATA_FLAG=""
fi

# 改訂履歴の変換。失敗時に書きかけの出力を残さない(残すと後段の pandoc が
# 壊れた YAML を読む・watch の再変換が誤スキップされるなどの事故につながる)。
convert_revisions() {
	if [ -n "$REV_MD" ]; then
		sh scripts/revisions-md2yaml.sh "$REV_MD" > "$REV_BUILD_YAML" \
			|| { rm -f "$REV_BUILD_YAML"; return 1; }
	fi
}

# 参照図の変換(mtime 比較で変更分のみ)。
convert_diagrams() {
	for p in $DIAGRAM_PUMLS; do
		svg="$DIAGRAM_OUT/$(basename "$p" .puml).svg"
		if [ ! -f "$svg" ] || [ -n "$(find "$p" "$PLANTUML_CONFIG" -newer "$svg" 2>/dev/null)" ]; then
			sh scripts/puml2svg.sh "$p" "$svg" || return 1
		fi
	done
}

# lint → 改訂履歴変換 → 図変換 → pandoc(.typ の再生成まで)。
# $METADATA_FLAG と $SRC_INPUTS は複数語に展開するため意図的にクォートしない。
regenerate_typ() {
	sh scripts/lint.sh $SRC_INPUTS \
		&& convert_revisions \
		&& convert_diagrams \
		&& pandoc \
			--from markdown \
			--to typst \
			--standalone \
			--template "$TEMPLATE" \
			$METADATA_FLAG \
			-o "$OBJ/$NAME.typ" \
			$SRC_INPUTS
}

mkdir -p "$OBJ"
regenerate_typ
typst compile \
	--root . \
	--font-path "$FONT_DIR" \
	--ignore-system-fonts \
	"$OBJ/$NAME.typ" \
	"$BUILD/$NAME.pdf"

[ -n "$WATCH" ] || exit 0

# ---- watch モード -----------------------------------------------------------

stamp="$OBJ/.watch-stamp-$NAME"
touch "$stamp"
typst watch \
	--root . \
	--font-path "$FONT_DIR" \
	--ignore-system-fonts \
	"$OBJ/$NAME.typ" \
	"$BUILD/$NAME.pdf" &
watch_pid=$!
# set -e の下では trap 内の kill / wait の非ゼロ終了でも即座に抜けてしまう
# ため、|| true で握りつぶして必ず exit 0 に到達させる(Ctrl-C は正常終了)。
trap 'echo "watch: 終了します(typst watch を停止します)"; kill $watch_pid 2>/dev/null || true; wait $watch_pid 2>/dev/null || true; exit 0' INT TERM
echo "watch: 変更を監視しています(Ctrl-C で終了)"

while :; do
	if ! kill -0 $watch_pid 2>/dev/null; then
		echo "ERROR: typst watch が終了しました(ログを確認してください)" >&2
		exit 1
	fi
	changed=$(find $SRC_INPUTS $REV_MD $REV_YAML $DIAGRAM_PUMLS "$PLANTUML_CONFIG" -newer "$stamp" 2>/dev/null || true)
	if [ -n "$changed" ]; then
		touch "$stamp"
		if regenerate_typ; then
			echo "watch: 再生成しました($OBJ/$NAME.typ) -- typst watch が自動で再コンパイルします"
		else
			echo "WARNING: 再生成に失敗しました(上記のエラーを参照。watch は継続します。修正して保存すると再試行します)" >&2
		fi
	fi
	sleep 1
done
