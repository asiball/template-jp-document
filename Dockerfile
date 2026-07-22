# =============================================================================
# Dockerfile — 決定的なビルド環境(`make pdf-docker` が使用する「正」の環境)
#
# pandoc はベースイメージ同梱のものを使い、Typst は GitHub Releases の musl
# 静的ビルドを、PlantUML は Maven Central の jar を、それぞれ固定バージョン+
# チェックサム検証で導入する。フォントはイメージに焼き込まず、実行時に
# マウントした assets/fonts を --font-path で参照する。
# =============================================================================

# タグ固定(digest 固定が必要な場合は BUILDING.md の手順で PANDOC_IMAGE を上書き)。
ARG PANDOC_IMAGE=pandoc/core:3.10
FROM ${PANDOC_IMAGE}

# Makefile の EXPECTED_* / BUILDING.md と揃える。変更時は TYPST_SHA256 も差し替える。
ARG TYPST_VERSION=0.15.0
# 別アーキテクチャ向けは `--build-arg TYPST_ARCH=aarch64-unknown-linux-musl`
# 等を指定する(TYPST_SHA256 も対応する値に差し替える。BUILDING.md の Docker 節参照)。
ARG TYPST_ARCH=x86_64-unknown-linux-musl
# 既定の TYPST_VERSION / TYPST_ARCH 用の sha256(GitHub Releases のアセット
# ダイジェスト)。不一致の場合ビルドはエラーで停止する。
ARG TYPST_SHA256="59b207df01be2dab9f13e80f73d04d7ff8273ffd46b3dd1b9eef5c60f3eeabea"
# TYPST_SHA256 を明示的に空にする場合は ALLOW_UNVERIFIED=1 の指定を必須とする
# (検証なしの「暗黙のスキップ」を防ぐフェイルセーフ)。
ARG ALLOW_UNVERIFIED=""

USER root

RUN set -eu; \
	apk add --no-cache curl xz ca-certificates; \
	arch_url="https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${TYPST_ARCH}.tar.xz"; \
	curl -fsSL -o /tmp/typst.tar.xz "$arch_url"; \
	if [ -n "$TYPST_SHA256" ]; then \
		echo "${TYPST_SHA256}  /tmp/typst.tar.xz" | sha256sum -c -; \
	elif [ -n "$ALLOW_UNVERIFIED" ]; then \
		echo "WARNING: TYPST_SHA256 が未指定のため、チェックサム検証をスキップしました(ALLOW_UNVERIFIED が明示的に指定されているため続行します)。" >&2; \
	else \
		echo "ERROR: TYPST_SHA256 が未指定です。チェックサム検証なしで Typst バイナリを導入することはできません。" >&2; \
		echo "  取得方法: curl -fsSL '${arch_url}' | sha256sum" >&2; \
		echo "  取得した値を指定してビルド: docker build --build-arg TYPST_SHA256=<sha256> ." >&2; \
		echo "  検証をスキップしてビルドする場合(非推奨): docker build --build-arg ALLOW_UNVERIFIED=1 ." >&2; \
		exit 1; \
	fi; \
	mkdir -p /tmp/typst-extract; \
	tar -xJf /tmp/typst.tar.xz -C /tmp/typst-extract; \
	install -m 0755 "/tmp/typst-extract/typst-${TYPST_ARCH}/typst" /usr/local/bin/typst; \
	rm -rf /tmp/typst.tar.xz /tmp/typst-extract; \
	apk del curl xz

# PlantUML(Markdown から参照する .puml の SVG 変換に使用。README の「図の
# 挿入」節参照)。Maven Central の jar はアーキテクチャ非依存・イミュータブル
# なので、バージョンと sha256 の固定だけで決定的に導入できる。変更時は
# Makefile の EXPECTED_PLANTUML も揃えること。
ARG PLANTUML_VERSION=1.2026.6
ARG PLANTUML_SHA256="e620ae095a2ba0134d3c33fd5ae34ff01e785f3df1796c0898802b8761a033a8"

RUN set -eu; \
	# JRE は headless 版ではなく通常版を使う: Alpine の openjdk21-jre-headless
	# には libfontmanager.so が含まれず、PlantUML のフォント計測(AWT)が
	# UnsatisfiedLinkError で失敗する。
	# graphviz はシーケンス図以外(クラス図・状態遷移図等)のレイアウトに必要。
	# fontconfig + /work/assets/fonts の登録は、実行時にマウントされる同梱
	# フォントを PlantUML(Java)から見えるようにするため: 図中テキストの幅
	# 計測を PDF 描画と同じフォントで行わないと、ラベル幅と箱のサイズが
	# ずれることがある(ttf-dejavu は欧文のフォールバック)。
	apk add --no-cache openjdk21-jre graphviz fontconfig ttf-dejavu curl; \
	curl -fsSL -o /opt/plantuml.jar "https://repo1.maven.org/maven2/net/sourceforge/plantuml/plantuml/${PLANTUML_VERSION}/plantuml-${PLANTUML_VERSION}.jar"; \
	echo "${PLANTUML_SHA256}  /opt/plantuml.jar" | sha256sum -c -; \
	printf '#!/bin/sh\nexec java -Djava.awt.headless=true -jar /opt/plantuml.jar "$@"\n' > /usr/local/bin/plantuml; \
	chmod 0755 /usr/local/bin/plantuml; \
	printf '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig><dir>/work/assets/fonts</dir></fontconfig>\n' > /etc/fonts/conf.d/60-work-assets-fonts.conf; \
	apk del curl

WORKDIR /work

# ベースイメージの ENTRYPOINT ["pandoc"] を解除し、`docker run ... sh -c` で
# pandoc / typst の両方を呼び出せるようにする。
ENTRYPOINT []
