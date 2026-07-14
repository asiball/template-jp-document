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
FROM pandoc/core:3.9

# Typst の実コンパイラバージョンは、typst (PyPI, Python バインディング) 0.13.7 が
# 内部で埋め込んでいるコンパイラの自己申告バージョン(#str(sys.version) で確認)に
# 合わせて 0.13.1 に固定している。ローカル検証との挙動差異を避けるため、
# Typst のバージョンを変更する場合は README の手順に従って再検証すること。
ARG TYPST_VERSION=0.13.1
# 空文字のままならチェックサム検証をスキップする(このセッションのネットワーク
# 制約により GitHub Releases のアセットへ直接アクセスできず、実際の sha256 を
# 取得できなかったため)。本番運用では README の手順で実値を取得し、
# `--build-arg TYPST_SHA256=<sha256>` を必ず指定すること。
ARG TYPST_SHA256=""

USER root

RUN set -eu; \
	apk add --no-cache curl xz ca-certificates; \
	arch_url="https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-x86_64-unknown-linux-musl.tar.xz"; \
	curl -fsSL -o /tmp/typst.tar.xz "$arch_url"; \
	if [ -n "$TYPST_SHA256" ]; then \
		echo "${TYPST_SHA256}  /tmp/typst.tar.xz" | sha256sum -c -; \
	else \
		echo "WARNING: TYPST_SHA256 が未指定のため、チェックサム検証をスキップしました。" >&2; \
	fi; \
	mkdir -p /tmp/typst-extract; \
	tar -xJf /tmp/typst.tar.xz -C /tmp/typst-extract; \
	install -m 0755 "/tmp/typst-extract/typst-x86_64-unknown-linux-musl/typst" /usr/local/bin/typst; \
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
