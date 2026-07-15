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
# 末尾スラッシュを正規化する(コマンドライン指定値の上書きには override が必要)。
override SRC := $(patsubst %/,%,$(SRC))
NAME       := $(basename $(notdir $(SRC)))
BUILD      := build
TEMPLATE   := template/template.typ
FONT_DIR   := assets/fonts
FONTS      := $(wildcard $(FONT_DIR)/*.otf)
HIGHLIGHT_THEME := assets/typst-highlight.tmTheme

# 章別ファイル分割(SRC がディレクトリの場合)。00-meta.md がフロントマター
# 専用、[0-9][0-9]-*.md が章ファイルでファイル名の辞書順が章順(規約の詳細は
# README の「章別ファイル分割」節参照)。
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

# 改訂履歴の別ファイル対応(README の「改訂履歴の別ファイル化」節参照)。
#   revisions.md  (推奨): scripts/revisions-md2yaml.sh で YAML に変換してから
#                  pandoc の --metadata-file として渡す。
#   revisions.yaml(代替): そのまま --metadata-file として渡す。
# 両方存在する場合は validate-src がエラーで停止する。どちらも無ければ
# METADATA_FLAG は空(フロントマター内の revisions のみを使う)。
REV_MD_EXISTS    := $(wildcard $(REV_MD))
REV_YAML_EXISTS  := $(wildcard $(REV_YAML))
# watch のポーリング対象(存在する改訂履歴ファイルのみ)
REV_WATCH        := $(REV_MD_EXISTS) $(REV_YAML_EXISTS)

ifneq ($(REV_MD_EXISTS),)
REV_BUILD_YAML := $(BUILD)/$(NAME).revisions.yaml
METADATA_FLAG  := --metadata-file $(REV_BUILD_YAML)
REV_PREREQ     := $(REV_BUILD_YAML)
# 変換コマンド(生成ルール・pdf-docker・watch で共用)。失敗時に書きかけの
# 出力を残さない(残すと mtime 比較で次回の変換がスキップされ、改訂履歴が
# 静かに欠落するため)。
REV_CONVERT    := { sh scripts/revisions-md2yaml.sh "$(REV_MD)" > "$(REV_BUILD_YAML)" || { rm -f "$(REV_BUILD_YAML)"; false; }; }
else ifneq ($(REV_YAML_EXISTS),)
METADATA_FLAG  := --metadata-file $(REV_YAML)
REV_PREREQ     := $(REV_YAML)
REV_CONVERT    := true
else
METADATA_FLAG  :=
REV_PREREQ     :=
REV_CONVERT    := true
endif

# 期待バージョン(Dockerfile の固定値と揃える。README 参照)。
EXPECTED_PANDOC := 3.10
EXPECTED_TYPST   := 0.15.0

DOCKER_IMAGE   := jp-spec-builder
# ツールチェーン(pandoc / typst)の固定バージョンを変更したら上げる。
DOCKER_TAG     := 2.0
DOCKER_FULLTAG := $(DOCKER_IMAGE):$(DOCKER_TAG)

# Typst バイナリのチェックサム検証(既定値は Dockerfile に設定済みのため
# 通常は指定不要。バージョン/アーキテクチャ変更時のみ上書きする。README 参照)。
#   make pdf-docker TYPST_SHA256=<sha256>   検証値を差し替える
#   make pdf-docker ALLOW_UNVERIFIED=1      検証をスキップする(非推奨)
TYPST_SHA256     ?=
ALLOW_UNVERIFIED ?=

# SRC / 改訂履歴ファイルの共通検証(check-versions と pdf-docker のレシピ
# 先頭から $(validate-src) で展開する)。スペースを含むパスは Make が単語分割
# してしまうため、対応せず明確なエラーで停止する。
define validate-src
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
endef

.PHONY: pdf pdf-docker docker-build watch clean lint lint-src check-versions

pdf: check-versions $(BUILD)/$(NAME).pdf

# 検証(validate-src)に続けて pandoc / typst のバージョンを表示し、期待
# バージョンと異なる場合は警告する(ビルドは継続)。
check-versions:
	$(validate-src)
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

# ビルド対象の SRC だけを lint する補助ターゲット。`make pdf` は .typ の
# レシピ内で lint を実行する(prerequisite にすると -j 時に lint と pandoc が
# 並行し、lint 失敗でも .typ が生成されてしまうため)。
lint-src:
	@sh scripts/lint.sh $(SRC_INPUTS)

# .revisions.md がある場合のみ定義される中間 YAML の生成ルール。
# check-versions は order-only: `make -j` でも検証を変換より先に完了させる。
ifneq ($(REV_MD_EXISTS),)
$(REV_BUILD_YAML): $(REV_MD) scripts/revisions-md2yaml.sh | check-versions
	@mkdir -p "$(BUILD)"
	$(REV_CONVERT)
endif

# pandoc は複数の入力ファイル($(SRC_INPUTS))を連結して 1 文書として処理する。
# check-versions は order-only: -j 時も検証を先に完了させつつ、phony 起因の
# 再ビルドは起こさない。
$(BUILD)/$(NAME).typ: $(SRC_INPUTS) $(TEMPLATE) template/spec.typ $(REV_PREREQ) | check-versions
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

# TYPST_SHA256 / ALLOW_UNVERIFIED は指定時のみ --build-arg で渡す(空文字を
# 渡すと Dockerfile の既定 sha256 を潰すため)。ALLOW_UNVERIFIED=1 単独指定時
# は sha を明示的に空で渡して検証をスキップさせる。
docker-build:
	docker build \
		$(if $(TYPST_SHA256),--build-arg TYPST_SHA256=$(TYPST_SHA256),$(if $(ALLOW_UNVERIFIED),--build-arg TYPST_SHA256= --build-arg ALLOW_UNVERIFIED=$(ALLOW_UNVERIFIED))) \
		-t $(DOCKER_FULLTAG) -t $(DOCKER_IMAGE):latest .

pdf-docker: docker-build
	$(validate-src)
	@mkdir -p "$(BUILD)"
	docker run --rm --user $$(id -u):$$(id -g) -v "$(CURDIR)":/work -w /work $(DOCKER_FULLTAG) \
		sh -c '\
			mkdir -p "$(BUILD)" && \
			sh scripts/lint.sh $(SRC_INPUTS) && \
			$(REV_CONVERT) && \
			pandoc --from markdown --to typst --standalone --template "$(TEMPLATE)" $(METADATA_FLAG) -o "$(BUILD)/$(NAME).typ" $(SRC_INPUTS) && \
			typst compile --root . --font-path "$(FONT_DIR)" --ignore-system-fonts "$(BUILD)/$(NAME).typ" "$(BUILD)/$(NAME).pdf" \
		'

# 執筆中の自動リビルド: 初回ビルド(pdf)→ typst watch をバックグラウンド起動
# → $(SRC_INPUTS)(+改訂履歴ファイル)を 1 秒間隔でポーリングし、変更検知で
# lint → YAML 変換 → pandoc を再実行する(.typ の再生成は typst watch が拾って
# PDF に反映する)。POSIX sh のみで実装(mtime 比較は `find -newer` + スタンプ
# ファイル)。lint / pandoc のエラーでは停止せず監視を継続する。Ctrl-C で
# typst watch ごと終了する。SRC の検証は prerequisite の pdf 側で実施済み。
watch: pdf
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
