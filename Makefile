# =============================================================================
# Makefile — Markdown -> Pandoc(Typst backend) -> Typst -> PDF
# =============================================================================
#
# 使い方:
#   make pdf                     docs/sample-spec.md をビルド
#   make pdf SRC=docs/foo.md     任意の Markdown をビルド
#   make pdf-docker               Docker コンテナ内でビルド(正のビルド方法)
#   make clean                    build/ を削除
#
# ローカルの `make pdf` は pandoc / typst が PATH 上にあることを前提とする。
# バージョンを揃えて決定的な結果を得たい場合は `make pdf-docker` を使うこと。

SRC        ?= docs/sample-spec.md
NAME       := $(basename $(notdir $(SRC)))
BUILD      := build
TEMPLATE   := template/template.typ
FONT_DIR   := assets/fonts
FONTS      := $(wildcard $(FONT_DIR)/*.otf)
HIGHLIGHT_THEME := assets/typst-highlight.tmTheme

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

.PHONY: pdf pdf-docker docker-build clean lint lint-src check-versions

pdf: check-versions lint-src $(BUILD)/$(NAME).pdf

# 実際の pandoc / typst のバージョンを表示し、期待バージョンと異なる場合は
# 警告を出す(ビルド自体は継続する)。POSIX sh で動作するように書く。
# シムの typst には --version が無い場合があるため、失敗しても継続する。
#
# 冒頭で SRC にスペースが含まれていないかを確認する。Make はスペースを
# 含むパスを引数として安全に扱えない(単語分割される)ため、完全対応は
# せずに明確なエラーで停止する(README/CLAUDE.md 参照)。
check-versions:
	@case "$(SRC)" in \
		*" "*) \
			echo "ERROR: SRC のパスにスペースは使えません: $(SRC)" >&2; \
			exit 1 ;; \
	esac
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

# `make pdf` の内部で走る lint は、ビルド対象の SRC のみを対象にする。
lint-src:
	@sh scripts/lint.sh "$(SRC)"

$(BUILD)/$(NAME).typ: $(SRC) $(TEMPLATE) template/spec.typ
	@mkdir -p "$(BUILD)"
	pandoc \
		--from markdown \
		--to typst \
		--standalone \
		--template "$(TEMPLATE)" \
		-o "$@" \
		"$(SRC)"

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
	esac
	@mkdir -p "$(BUILD)"
	docker run --rm --user $$(id -u):$$(id -g) -v "$(CURDIR)":/work -w /work $(DOCKER_FULLTAG) \
		sh -c '\
			mkdir -p "$(BUILD)" && \
			pandoc --from markdown --to typst --standalone --template "$(TEMPLATE)" -o "$(BUILD)/$(NAME).typ" "$(SRC)" && \
			typst compile --root . --font-path "$(FONT_DIR)" --ignore-system-fonts "$(BUILD)/$(NAME).typ" "$(BUILD)/$(NAME).pdf" \
		'

clean:
	rm -rf $(BUILD)
