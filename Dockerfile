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

# このセッションでの検証で確認した pandoc の実バージョンに固定する。
# (pypandoc-binary==1.17 が同梱する pandoc は `pandoc --version` で 3.9 と報告された)
# ベースイメージはタグ(pandoc/core:3.9)で固定しているが、タグはリポジトリ側で
# 再 push されうるため digest 固定ではない。より厳密な決定性が必要な場合は、
# README の手順で実 digest を取得し
# `--build-arg PANDOC_IMAGE=pandoc/core@sha256:<digest>` を指定すること。
ARG PANDOC_IMAGE=pandoc/core:3.9
FROM ${PANDOC_IMAGE}

# Typst の実コンパイラバージョンは、typst (PyPI, Python バインディング) 0.13.7 が
# 内部で埋め込んでいるコンパイラの自己申告バージョン(#str(sys.version) で確認)に
# 合わせて 0.13.1 に固定している。ローカル検証との挙動差異を避けるため、
# Typst のバージョンを変更する場合は README の手順に従って再検証すること。
ARG TYPST_VERSION=0.13.1
# Typst の GitHub Releases アセット名に含まれるターゲットトリプル。既定は
# x86_64(Linux, musl 静的ビルド)。Apple Silicon 等の別アーキテクチャ向けに
# ビルドする場合は `--build-arg TYPST_ARCH=aarch64-unknown-linux-musl` の
# ように指定する(README の Docker 節を参照)。
ARG TYPST_ARCH=x86_64-unknown-linux-musl
# 空文字のままではチェックサム検証を行えない(このセッションのネットワーク
# 制約により GitHub Releases のアセットへ直接アクセスできず、実際の sha256 を
# 取得できなかったため)。本番運用では README の手順で実値を取得し、
# `--build-arg TYPST_SHA256=<sha256>` を必ず指定すること。
ARG TYPST_SHA256=""
# TYPST_SHA256 を指定せずにビルドする場合、検証なしでバイナリを信頼することに
# 明示的に同意したことを示すため ALLOW_UNVERIFIED=1 の指定を必須とする
# (指定がなければビルドをエラーで停止する。「暗黙のスキップ」を避けるための
# フェイルセーフ)。
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
