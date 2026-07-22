# =============================================================================
# Dockerfile — ビルド環境(すべてのビルドはこのイメージ内で実行する)
#
# pandoc はベースイメージ同梱のものを使い、Typst は GitHub Releases の musl
# 静的ビルドを、PlantUML は Maven Central の jar を、フォントは Adobe の
# GitHub リポジトリのリリースタグを、それぞれ固定バージョン+チェックサム
# 検証で導入する。フォントは /opt/fonts に焼き込み、typst の --font-path と
# PlantUML の文字幅計測(fontconfig)の両方から参照する。
# =============================================================================

# タグ固定(digest 固定が必要な場合は BUILDING.md の手順で PANDOC_IMAGE を上書き)。
ARG PANDOC_IMAGE=pandoc/core:3.10
FROM ${PANDOC_IMAGE}

# 変更時は TYPST_SHA256 も差し替え、Makefile の DOCKER_TAG を上げる(BUILDING.md 参照)。
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
# Makefile の DOCKER_TAG を上げること。
ARG PLANTUML_VERSION=1.2026.6
ARG PLANTUML_SHA256="e620ae095a2ba0134d3c33fd5ae34ff01e785f3df1796c0898802b8761a033a8"

RUN set -eu; \
	# JRE は headless 版ではなく通常版を使う: Alpine の openjdk21-jre-headless
	# には libfontmanager.so が含まれず、PlantUML のフォント計測(AWT)が
	# UnsatisfiedLinkError で失敗する。
	# graphviz はシーケンス図以外(クラス図・状態遷移図等)のレイアウトに必要。
	# fontconfig + /opt/fonts の登録は、イメージに焼き込むフォントを
	# PlantUML(Java)から見えるようにするため: 図中テキストの幅計測を
	# PDF 描画と同じフォントで行わないと、ラベル幅と箱のサイズがずれる
	# ことがある(ttf-dejavu は欧文のフォールバック)。
	apk add --no-cache openjdk21-jre graphviz fontconfig ttf-dejavu curl; \
	curl -fsSL -o /opt/plantuml.jar "https://repo1.maven.org/maven2/net/sourceforge/plantuml/plantuml/${PLANTUML_VERSION}/plantuml-${PLANTUML_VERSION}.jar"; \
	echo "${PLANTUML_SHA256}  /opt/plantuml.jar" | sha256sum -c -; \
	printf '#!/bin/sh\nexec java -Djava.awt.headless=true -jar /opt/plantuml.jar "$@"\n' > /usr/local/bin/plantuml; \
	chmod 0755 /usr/local/bin/plantuml; \
	printf '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig><dir>/opt/fonts</dir></fontconfig>\n' > /etc/fonts/conf.d/60-opt-fonts.conf; \
	apk del curl

# フォント(Adobe Source Han。BUILDING.md の「フォント」節参照)。
# 各リポジトリのリリースタグの raw URL から取得し sha256 で検証する
# (タグ付きコミットのファイルはイミュータブルなので、これで決定的に導入
# できる)。OFL の再配布条件に従い、ライセンス文書もフォントと同じ場所に置く。
# フォントを差し替える場合はこの一覧と template/spec.typ のフォント定数・
# template/plantuml.config をあわせて変更する(BUILDING.md の手順参照)。
RUN set -eu; \
	apk add --no-cache curl; \
	mkdir -p /opt/fonts; \
	base="https://raw.githubusercontent.com/adobe-fonts"; \
	for spec in \
		"e5f502bb193c28829895b098498f0f9dd8f658c760b0f83656ad41c1137a8785:source-han-serif/2.003R/SubsetOTF/JP/SourceHanSerifJP-Regular.otf" \
		"13473d3c1cf1fdb0e08d5e5e093cf9fc57d3e59d9d13cf7f6369615bf96397ee:source-han-serif/2.003R/SubsetOTF/JP/SourceHanSerifJP-Bold.otf" \
		"5d39f8eaaa9ad2aed93166b0a4fc4a43ac82de8a5c6112992446c24d88b595f9:source-han-sans/2.005R/SubsetOTF/JP/SourceHanSansJP-Medium.otf" \
		"3a2722f94c97a53b172579a10ef8fc34b3fa8a6bb4f7947a2ec709ab647fb755:source-han-sans/2.005R/SubsetOTF/JP/SourceHanSansJP-Bold.otf" \
		"06751f8f4b9263da7bf2ce12ba4375daba4880a8e6d4ccb61b2adb6d6401fc10:source-han-code-jp/2.012R/OTF/SourceHanCodeJP-Regular.otf" \
		"4141bf4789f4c0d0160df1dcc550d03764977464dc8d923b6741dbcb95110b6e:source-han-code-jp/2.012R/OTF/SourceHanCodeJP-Bold.otf" \
	; do \
		sha="${spec%%:*}"; path="${spec#*:}"; \
		file="/opt/fonts/$(basename "$path")"; \
		curl -fsSL -o "$file" "$base/$path"; \
		echo "$sha  $file" | sha256sum -c -; \
	done; \
	curl -fsSL -o /opt/fonts/LICENSE-SourceHanSerif.txt "$base/source-han-serif/2.003R/LICENSE.txt"; \
	echo "9ff5bb567e1b92c801fc1069e5fbf992ff8efccacb9db94e5959a5b3ba9bb903  /opt/fonts/LICENSE-SourceHanSerif.txt" | sha256sum -c -; \
	curl -fsSL -o /opt/fonts/LICENSE-SourceHanSans.txt "$base/source-han-sans/2.005R/LICENSE.txt"; \
	echo "fcac737e761ec63dbfbdce11030a1780161920d80315edba9c8beff1c2bac5a2  /opt/fonts/LICENSE-SourceHanSans.txt" | sha256sum -c -; \
	curl -fsSL -o /opt/fonts/LICENSE-SourceHanCodeJP.txt "$base/source-han-code-jp/2.012R/LICENSE.txt"; \
	echo "6a73f9541c2de74158c0e7cf6b0a58ef774f5a780bf191f2d7ec9cc53efe2bf2  /opt/fonts/LICENSE-SourceHanCodeJP.txt" | sha256sum -c -; \
	apk del curl

WORKDIR /work

# ベースイメージの ENTRYPOINT ["pandoc"] を解除し、`docker run ... sh -c` で
# pandoc / typst の両方を呼び出せるようにする。
ENTRYPOINT []
