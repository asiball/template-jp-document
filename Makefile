# =============================================================================
# Makefile — Markdown -> Pandoc(Typst backend) -> Typst -> PDF
# =============================================================================
#
# 使い方:
#   make pdf                     docs/sample-spec(章別ファイル分割)をビルド
#   make pdf SRC=docs/foo.md     単一 Markdown ファイルをビルド
#   make pdf SRC=docs/foo        章別ファイル分割ディレクトリをビルド
#   make pdf-docker               Docker コンテナ内でビルド(正のビルド方法)
#   make watch                    執筆中の自動リビルド(README の「執筆中の自動更新」参照)
#   make clean                    build/ を削除
#
# ローカルの `make pdf` は pandoc / typst が PATH 上にあることを前提とする。
# バージョンを揃えて決定的な結果を得たい場合は `make pdf-docker` を使うこと。

SRC        ?= docs/sample-spec
# 末尾スラッシュを除去しておく(SRC=docs/sample-spec/ のような入力に対応)。
# `make pdf SRC=...` のようにコマンドラインで指定された値は、通常の `:=` では
# 上書きできない(コマンドライン変数はファイル内の代入より優先されるため)。
# ここでは意図的に `override` を使い、コマンドライン指定値の末尾スラッシュを
# 正規化する。
override SRC := $(patsubst %/,%,$(SRC))
NAME       := $(basename $(notdir $(SRC)))
BUILD      := build
TEMPLATE   := template/template.typ
FONT_DIR   := assets/fonts
FONTS      := $(wildcard $(FONT_DIR)/*.otf)
HIGHLIGHT_THEME := assets/typst-highlight.tmTheme

# 章別ファイル分割(SRC がディレクトリの場合。README の「章別ファイル分割」
# 節参照)。
#
# ディレクトリ規約:
#   00-meta.md         フロントマター専用(必須)。
#   [0-9][0-9]-*.md    章ファイル。ファイル名の辞書順が章順になる。
#                       00-meta.md 自身もこのパターンにマッチするため、
#                       $(sort ...) した一覧の先頭に自然に来る。
#   revisions.md / revisions.yaml   改訂履歴(下記 REV_MD/REV_YAML と同じ
#                       仕組み。数字プレフィックスを持たないため章 glob には
#                       含まれない)。
#
# SRC_IS_DIR はシェルの `test -d` で判定する(make のパース時に 1 回だけ評価)。
SRC_IS_DIR := $(shell [ -d "$(SRC)" ] && echo 1)

ifeq ($(SRC_IS_DIR),1)
CHAPTER_FILES      := $(sort $(wildcard $(SRC)/[0-9][0-9]-*.md))
META_FILE          := $(SRC)/00-meta.md
NON_META_CHAPTERS  := $(filter-out $(META_FILE),$(CHAPTER_FILES))
SRC_INPUTS         := $(CHAPTER_FILES)
REV_MD             := $(SRC)/revisions.md
REV_YAML           := $(SRC)/revisions.yaml
else
CHAPTER_FILES       :=
META_FILE           :=
NON_META_CHAPTERS   :=
SRC_INPUTS          := $(SRC)
# 改訂履歴の別ファイル化(SRC と同じディレクトリ・同じベース名)。
REV_MD              := $(patsubst %.md,%.revisions.md,$(SRC))
REV_YAML            := $(patsubst %.md,%.revisions.yaml,$(SRC))
endif

# 改訂履歴は次の 2 形式に対応する(README の「改訂履歴の別ファイル化」節参照)。
#
#   1. revisions.md  (推奨): Markdown パイプ表(1 改訂 = 1 行)。
#      scripts/revisions-md2yaml.sh がビルド時に build/<name>.revisions.yaml
#      へ変換し、それを pandoc の --metadata-file として渡す。
#   2. revisions.yaml(代替): トップレベルに `revisions:` 配列を持つ
#      素直な YAML。そのまま --metadata-file として渡す。
#
# 両方が存在する場合はどちらを意図しているか判別できないため、check-versions /
# pdf-docker のガードで明確なエラーにして停止する。どちらも存在しない場合
# METADATA_FLAG は空になる(フロントマター内の revisions のみを使う従来どおり
# の挙動)。
#
# 注意(Pandoc の合成規則): フロントマター側に revisions があると、
# --metadata-file 側の revisions より優先される(上書きされる)。そのため
# revisions はフロントマター・別ファイルのいずれか 1 箇所にのみ書くこと
# (推奨: .revisions.md / revisions.md。README/CLAUDE.md 参照)。
REV_MD_EXISTS    := $(wildcard $(REV_MD))
REV_YAML_EXISTS  := $(wildcard $(REV_YAML))
# watch のポーリング対象(存在する改訂履歴ファイルのみ)
REV_WATCH        := $(REV_MD_EXISTS) $(REV_YAML_EXISTS)

ifneq ($(REV_MD_EXISTS),)
REV_BUILD_YAML := $(BUILD)/$(NAME).revisions.yaml
METADATA_FLAG  := --metadata-file $(REV_BUILD_YAML)
REV_PREREQ     := $(REV_BUILD_YAML)
# pdf-docker の sh -c 内および watch のポーリングループで使う変換コマンド。
REV_CONVERT    := sh scripts/revisions-md2yaml.sh "$(REV_MD)" > "$(REV_BUILD_YAML)"
else ifneq ($(REV_YAML_EXISTS),)
METADATA_FLAG  := --metadata-file $(REV_YAML)
REV_PREREQ     := $(REV_YAML)
REV_CONVERT    := true
else
METADATA_FLAG  :=
REV_PREREQ     :=
REV_CONVERT    := true
endif

# ローカル `make pdf` の検証環境で実測したバージョン(README 参照)。
# `make pdf-docker` はこれらを Dockerfile 内で固定しているため常に一致する。
EXPECTED_PANDOC := 3.9
EXPECTED_TYPST   := 0.13.1

DOCKER_IMAGE   := jp-spec-builder
DOCKER_TAG     := 1.0
DOCKER_FULLTAG := $(DOCKER_IMAGE):$(DOCKER_TAG)

# `make pdf-docker` に渡す Typst バイナリのチェックサム検証用引数。
# 未指定の場合、Dockerfile 側は TYPST_SHA256 と ALLOW_UNVERIFIED が
# 両方とも空ならビルドをエラーで停止する(README 参照)。
#   make pdf-docker TYPST_SHA256=<sha256>
#   make pdf-docker ALLOW_UNVERIFIED=1
TYPST_SHA256     ?=
ALLOW_UNVERIFIED ?=

.PHONY: pdf pdf-docker docker-build watch clean lint lint-src check-versions

pdf: check-versions $(BUILD)/$(NAME).pdf

# 実際の pandoc / typst のバージョンを表示し、期待バージョンと異なる場合は
# 警告を出す(ビルド自体は継続する)。POSIX sh で動作するように書く。
# シムの typst には --version が無い場合があるため、失敗しても継続する。
#
# 冒頭で SRC にスペースが含まれていないかを確認する。Make はスペースを
# 含むパスを引数として安全に扱えない(単語分割される)ため、完全対応は
# せずに明確なエラーで停止する(README/CLAUDE.md 参照)。
# あわせて、SRC に改訂履歴ファイルそのものを指定する誤用と、改訂履歴
# ファイルが .revisions.md / .revisions.yaml の両方存在する競合も検出する。
check-versions:
	@case "$(SRC)" in \
		*" "*) \
			echo "ERROR: SRC のパスにスペースは使えません: $(SRC)" >&2; \
			exit 1 ;; \
		*.revisions.md|*.revisions.yaml) \
			echo "ERROR: SRC に改訂履歴ファイル($(SRC))は指定できません。本文の Markdown(docs/<name>.md または docs/<name>/)を指定してください(改訂履歴ファイルはビルド時に自動で読み込まれます)。" >&2; \
			exit 1 ;; \
	esac
	@if [ ! -e "$(SRC)" ]; then \
		echo "ERROR: SRC が見つかりません: $(SRC)" >&2; \
		exit 1; \
	fi
	@if [ -d "$(SRC)" ]; then \
		if [ ! -f "$(SRC)/00-meta.md" ]; then \
			echo "ERROR: $(SRC)/00-meta.md が見つかりません(章別ファイル分割には 00-meta.md が必須です。README の「章別ファイル分割」参照)。" >&2; \
			exit 1; \
		fi; \
		if [ -z "$(strip $(NON_META_CHAPTERS))" ]; then \
			echo "ERROR: $(SRC) に章ファイル([0-9][0-9]-*.md。00-meta.md 以外)が 1 つも見つかりません。" >&2; \
			exit 1; \
		fi; \
	fi
	@if [ -f "$(REV_MD)" ] && [ -f "$(REV_YAML)" ]; then \
		echo "ERROR: $(REV_MD) と $(REV_YAML) が両方存在します。改訂履歴ファイルはどちらか一方のみにしてください(推奨: $(if $(filter 1,$(SRC_IS_DIR)),revisions.md,.revisions.md))。" >&2; \
		exit 1; \
	fi
	@pandoc_line="$$(pandoc --version 2>/dev/null | head -n1)"; \
	echo "pandoc: $${pandoc_line:-(バージョン取得に失敗しました)}"; \
	pandoc_ver="$$(printf '%s' "$$pandoc_line" | awk '{print $$2}')"; \
	if [ "$$pandoc_ver" != "$(EXPECTED_PANDOC)" ]; then \
		echo "WARNING: pandoc のバージョン($${pandoc_ver:-不明})が期待バージョン($(EXPECTED_PANDOC))と異なります(make pdf-docker で固定環境を使えます)。"; \
	fi; \
	typst_line="$$(typst --version 2>/dev/null | head -n1 || true)"; \
	if [ -z "$$typst_line" ]; then \
		echo "typst: (バージョン取得に失敗しました。この typst は --version に対応していない可能性があります)"; \
	else \
		echo "typst: $$typst_line"; \
		typst_ver="$$(printf '%s' "$$typst_line" | awk '{print $$2}')"; \
		if [ "$$typst_ver" != "$(EXPECTED_TYPST)" ]; then \
			echo "WARNING: typst のバージョン($${typst_ver:-不明})が期待バージョン($(EXPECTED_TYPST))と異なります(make pdf-docker で固定環境を使えます)。"; \
		fi; \
	fi

# 簡易 lint(scripts/lint.sh)。見出しの手動採番などを検知する。
# `make lint` 単体は従来どおり docs/*.md 全件を対象にする。
lint:
	@sh scripts/lint.sh

# ビルド対象の SRC のみを対象に lint だけを単体実行したい場合に使う補助
# ターゲット(SRC のみ対象。`make pdf` 自体は $(BUILD)/$(NAME).typ のレシピ
# 先頭で `sh scripts/lint.sh $(SRC_INPUTS) &&` を実行するため、これを
# prerequisite にはしていない。prerequisite にすると `make -j` 時に pandoc と
# lint が並行実行され、lint 失敗時にも .typ が生成されてしまう問題があった)。
lint-src:
	@sh scripts/lint.sh $(SRC_INPUTS)

# .revisions.md が存在する場合のみ定義される中間 YAML の生成ルール。
# 変換に失敗した場合は書きかけの出力を残さない(次回 make で必ず再試行
# されるようにするため)。
ifneq ($(REV_MD_EXISTS),)
$(REV_BUILD_YAML): $(REV_MD) scripts/revisions-md2yaml.sh
	@mkdir -p "$(BUILD)"
	sh scripts/revisions-md2yaml.sh "$(REV_MD)" > "$@" || { rm -f "$@"; exit 1; }
endif

# $(SRC_INPUTS) は単一ファイルモードでは $(SRC) 1 個、章別ファイル分割モード
# では 00-meta.md を含む章ファイル一覧(ソート済み)になる。pandoc は複数の
# 入力ファイルを連結して 1 文書として処理できる(章の自動採番・ファイル横断
# リンク・脚注・表番号・表紙/目次のいずれも正しく動作することを確認済み)。
$(BUILD)/$(NAME).typ: $(SRC_INPUTS) $(TEMPLATE) template/spec.typ $(REV_PREREQ)
	@mkdir -p "$(BUILD)"
	sh scripts/lint.sh $(SRC_INPUTS) && \
	pandoc \
		--from markdown \
		--to typst \
		--standalone \
		--template "$(TEMPLATE)" \
		$(METADATA_FLAG) \
		-o "$@" \
		$(SRC_INPUTS)

$(BUILD)/$(NAME).pdf: $(BUILD)/$(NAME).typ $(FONTS) $(HIGHLIGHT_THEME)
	typst compile \
		--root . \
		--font-path "$(FONT_DIR)" \
		--ignore-system-fonts \
		"$(BUILD)/$(NAME).typ" \
		"$(BUILD)/$(NAME).pdf"

docker-build:
	docker build \
		--build-arg TYPST_SHA256=$(TYPST_SHA256) \
		--build-arg ALLOW_UNVERIFIED=$(ALLOW_UNVERIFIED) \
		-t $(DOCKER_FULLTAG) -t $(DOCKER_IMAGE):latest .

pdf-docker: docker-build
	@case "$(SRC)" in \
		*" "*) \
			echo "ERROR: SRC のパスにスペースは使えません: $(SRC)" >&2; \
			exit 1 ;; \
		*.revisions.md|*.revisions.yaml) \
			echo "ERROR: SRC に改訂履歴ファイル($(SRC))は指定できません。本文の Markdown(docs/<name>.md または docs/<name>/)を指定してください(改訂履歴ファイルはビルド時に自動で読み込まれます)。" >&2; \
			exit 1 ;; \
	esac
	@if [ ! -e "$(SRC)" ]; then \
		echo "ERROR: SRC が見つかりません: $(SRC)" >&2; \
		exit 1; \
	fi
	@if [ -d "$(SRC)" ]; then \
		if [ ! -f "$(SRC)/00-meta.md" ]; then \
			echo "ERROR: $(SRC)/00-meta.md が見つかりません(章別ファイル分割には 00-meta.md が必須です。README の「章別ファイル分割」参照)。" >&2; \
			exit 1; \
		fi; \
		if [ -z "$(strip $(NON_META_CHAPTERS))" ]; then \
			echo "ERROR: $(SRC) に章ファイル([0-9][0-9]-*.md。00-meta.md 以外)が 1 つも見つかりません。" >&2; \
			exit 1; \
		fi; \
	fi
	@if [ -f "$(REV_MD)" ] && [ -f "$(REV_YAML)" ]; then \
		echo "ERROR: $(REV_MD) と $(REV_YAML) が両方存在します。改訂履歴ファイルはどちらか一方のみにしてください(推奨: $(if $(filter 1,$(SRC_IS_DIR)),revisions.md,.revisions.md))。" >&2; \
		exit 1; \
	fi
	@mkdir -p "$(BUILD)"
	docker run --rm --user $$(id -u):$$(id -g) -v "$(CURDIR)":/work -w /work $(DOCKER_FULLTAG) \
		sh -c '\
			mkdir -p "$(BUILD)" && \
			sh scripts/lint.sh $(SRC_INPUTS) && \
			$(REV_CONVERT) && \
			pandoc --from markdown --to typst --standalone --template "$(TEMPLATE)" $(METADATA_FLAG) -o "$(BUILD)/$(NAME).typ" $(SRC_INPUTS) && \
			typst compile --root . --font-path "$(FONT_DIR)" --ignore-system-fonts "$(BUILD)/$(NAME).typ" "$(BUILD)/$(NAME).pdf" \
		'

# 執筆中の自動リビルド。
#   (a) `pdf` を prerequisite にすることで初回ビルド(check-versions を含む)
#       を通常どおり実行する。
#   (b) `typst watch` をバックグラウンド起動する。.typ / template/*.typ の
#       変更は typst watch 自身が検知して自動リコンパイルする。
#   (c) フォアグラウンドで $(SRC)(と改訂履歴ファイル .revisions.md /
#       .revisions.yaml が存在すればそれも)を 1 秒間隔でポーリングし、変更を
#       検知したら lint→(.revisions.md があれば YAML 変換)→pandoc を再実行
#       して .typ を再生成する(再生成された .typ は typst watch が拾って
#       自動で PDF に反映する)。
#
# POSIX sh のみで実装する(inotifywait/fswatch には依存しない)。mtime 比較は
# `find -newer` + build/ 内のタイムスタンプファイルで行う(移植性のため
# bash 拡張の `test -nt` は使わない)。
#
# lint エラー・pandoc エラー時は watch を継続する(エラーを表示するだけで
# 停止しない)。ファイルが修正されて再度保存されれば、次のポーリングで
# 新しい mtime が検出され自動的に再試行される。
#
# Ctrl-C (SIGINT) / SIGTERM を trap し、バックグラウンドの typst watch を
# 確実に kill してから終了する。
watch: pdf
	@case "$(SRC)" in \
		*" "*) \
			echo "ERROR: SRC のパスにスペースは使えません: $(SRC)" >&2; \
			exit 1 ;; \
	esac
	@stamp="$(BUILD)/.watch-stamp-$(NAME)"; \
	touch "$$stamp"; \
	typst watch \
		--root . \
		--font-path "$(FONT_DIR)" \
		--ignore-system-fonts \
		"$(BUILD)/$(NAME).typ" \
		"$(BUILD)/$(NAME).pdf" & \
	watch_pid=$$!; \
	trap 'echo "watch: 終了します(typst watch を停止します)"; kill $$watch_pid 2>/dev/null; wait $$watch_pid 2>/dev/null; exit 0' INT TERM; \
	echo "watch: $(SRC) の変更を監視しています(Ctrl-C で終了)"; \
	while :; do \
		if ! kill -0 $$watch_pid 2>/dev/null; then \
			echo "ERROR: typst watch が終了しました(ログを確認してください)" >&2; \
			exit 1; \
		fi; \
		changed=$$(find $(SRC_INPUTS) $(REV_WATCH) -newer "$$stamp" 2>/dev/null); \
		if [ -n "$$changed" ]; then \
			touch "$$stamp"; \
			if sh scripts/lint.sh $(SRC_INPUTS); then \
				if $(REV_CONVERT); then \
					if pandoc --from markdown --to typst --standalone --template "$(TEMPLATE)" $(METADATA_FLAG) -o "$(BUILD)/$(NAME).typ" $(SRC_INPUTS); then \
						echo "watch: 再生成しました($(BUILD)/$(NAME).typ) -- typst watch が自動で再コンパイルします"; \
					else \
						echo "WARNING: pandoc の変換に失敗しました(watch は継続します。修正して保存すると再試行します)" >&2; \
					fi; \
				else \
					echo "WARNING: 改訂履歴($(REV_MD))の YAML 変換に失敗しました(watch は継続します。修正して保存すると再試行します)" >&2; \
				fi; \
			else \
				echo "WARNING: lint エラーのため再ビルドをスキップしました(watch は継続します。修正して保存すると再試行します)" >&2; \
			fi; \
		fi; \
		sleep 1; \
	done

clean:
	rm -rf $(BUILD)
