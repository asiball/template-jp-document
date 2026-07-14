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

DOCKER_IMAGE   := jp-spec-builder
DOCKER_TAG     := 1.0
DOCKER_FULLTAG := $(DOCKER_IMAGE):$(DOCKER_TAG)

.PHONY: pdf pdf-docker docker-build clean

pdf: $(BUILD)/$(NAME).pdf

$(BUILD)/$(NAME).typ: $(SRC) $(TEMPLATE) template/spec.typ
	@mkdir -p $(BUILD)
	pandoc \
		--from markdown \
		--to typst \
		--standalone \
		--template $(TEMPLATE) \
		-o $@ \
		$(SRC)

$(BUILD)/$(NAME).pdf: $(BUILD)/$(NAME).typ
	typst compile \
		--root . \
		--font-path $(FONT_DIR) \
		--ignore-system-fonts \
		$(BUILD)/$(NAME).typ \
		$(BUILD)/$(NAME).pdf

docker-build:
	docker build -t $(DOCKER_FULLTAG) -t $(DOCKER_IMAGE):latest .

pdf-docker: docker-build
	@mkdir -p $(BUILD)
	docker run --rm -v $(CURDIR):/work -w /work $(DOCKER_FULLTAG) \
		sh -c '\
			mkdir -p $(BUILD) && \
			pandoc --from markdown --to typst --standalone --template $(TEMPLATE) -o $(BUILD)/$(NAME).typ $(SRC) && \
			typst compile --root . --font-path $(FONT_DIR) --ignore-system-fonts $(BUILD)/$(NAME).typ $(BUILD)/$(NAME).pdf \
		'

clean:
	rm -rf $(BUILD)
