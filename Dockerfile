# =============================================================================
# Dockerfile — 決定的なビルド環境(Markdown -> Pandoc(Typst) -> Typst -> PDF)
#
# `make pdf-docker` が使用する「正」のビルド環境。pandoc はベースイメージに
# 同梱されているものをそのまま使い、Typst は静的ビルドの musl バイナリを
# GitHub Releases から取得して固定バージョンで導入する。
#
# フォントはイメージに焼き込まない。実行時に `docker run -v $(CURDIR):/work`
# でホストの assets/fonts をマウントし、Makefile 側で
# `typst compile --font-path assets/fonts --ignore-system-fonts` を指定する
# ことで一元管理する(README / Makefile と整合させている)。
# =============================================================================

# pandoc のバージョン固定(Makefile の EXPECTED_PANDOC / README と揃える)。
# ベースイメージはタグ(pandoc/core:3.10)で固定しているが、タグはリポジトリ側で
# 再 push されうるため digest 固定ではない。より厳密な決定性が必要な場合は、
# README の手順で実 digest を取得し
# `--build-arg PANDOC_IMAGE=pandoc/core@sha256:<digest>` を指定すること。
ARG PANDOC_IMAGE=pandoc/core:3.10
FROM ${PANDOC_IMAGE}

# Typst コンパイラのバージョン固定(Makefile の EXPECTED_TYPST / README と
# 揃える)。バージョンを変更する場合は、下記 TYPST_SHA256 も対応する値に
# 差し替えたうえで、README の手順に従って出力 PDF を再検証すること。
ARG TYPST_VERSION=0.15.0
# Typst の GitHub Releases アセット名に含まれるターゲットトリプル。既定は
# x86_64(Linux, musl 静的ビルド)。Apple Silicon 等の別アーキテクチャ向けに
# ビルドする場合は `--build-arg TYPST_ARCH=aarch64-unknown-linux-musl` の
# ように指定する(その場合 TYPST_SHA256 も対応する値に差し替えること。
# README の Docker 節を参照)。
ARG TYPST_ARCH=x86_64-unknown-linux-musl
# 既定値は、既定の TYPST_VERSION / TYPST_ARCH(v0.15.0 / x86_64 musl)の
# リリースアセットの sha256(GitHub Releases が公開するアセットダイジェスト)。
# TYPST_VERSION / TYPST_ARCH を変更する場合は、README の手順で対応する値を
# 取得し `--build-arg TYPST_SHA256=<sha256>` で差し替えること(不一致の場合
# ビルドはエラーで停止する)。
ARG TYPST_SHA256="59b207df01be2dab9f13e80f73d04d7ff8273ffd46b3dd1b9eef5c60f3eeabea"
# TYPST_SHA256 を明示的に空(--build-arg TYPST_SHA256=)にしてビルドする場合、
# 検証なしでバイナリを信頼することに明示的に同意したことを示すため
# ALLOW_UNVERIFIED=1 の指定を必須とする(指定がなければビルドをエラーで停止
# する。「暗黙のスキップ」を避けるためのフェイルセーフ)。
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

WORKDIR /work

# ベースイメージ (pandoc/core) は ENTRYPOINT ["pandoc"] を設定しているため、
# そのままでは `docker run ... sh -c '...'` が `pandoc sh -c '...'` として
# 解釈されてしまう。pandoc に加えて typst も呼び出せるようにするため、
# ENTRYPOINT を明示的にクリアしておく。実行コマンドは Makefile
# (pdf-docker ターゲット) 側で `docker run ... jp-spec-builder sh -c '...'`
# として指定する。
ENTRYPOINT []
