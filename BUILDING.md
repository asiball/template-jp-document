# BUILDING — ビルド環境の詳細

本書は `template-jp-document` のビルド環境(pandoc / typst のバージョン固定、Docker、フォント)に関する詳細をまとめたものです。日々のビルドコマンドと執筆ルールは `README.md` を参照してください。

## 想定バージョン

このテンプレートは次のバージョンを想定しています(`Dockerfile` / `Makefile` の `EXPECTED_*` で固定)。

| ツール | バージョン | 備考 |
|---|---|---|
| pandoc | 3.10 | 公式リリースバイナリ(Docker ビルドでは `pandoc/core:3.10` ベースイメージ) |
| typst  | 0.15.0 | 公式 GitHub Releases の musl 静的ビルド |
| plantuml | 1.2026.6 | Maven Central の jar(Docker ビルドでは sha256 検証付きで自動導入)。PlantUML 図を参照する文書のビルドにのみ必要 |

**注意**: Ubuntu の apt が提供する pandoc(24.04 時点で 3.1.3)は Typst ライターが古く、表キャプション・`table.header`・`{.unnumbered}`・脚注などこのテンプレートが前提とする出力に対応していないため使用しないでください。下記の公式リリースバイナリか Docker ビルドを使ってください。

バージョンが異なると、見出し番号の折り返しや表の罫線など細部のレンダリングが変わる可能性があります。厳密に一致させたい場合は Docker ビルド(下記)を使ってください。

## ローカルに pandoc / typst をインストールする

インストール方法の例:

```sh
# macOS (Homebrew)
brew install pandoc typst
brew install plantuml graphviz    # PlantUML 図を使う場合のみ(README の「図の挿入」参照)

# Linux / 手動インストール(GitHub Releases から取得)
# pandoc:
#   https://github.com/jgm/pandoc/releases/download/3.10/pandoc-3.10-linux-amd64.tar.gz
# typst:
#   https://github.com/typst/typst/releases/download/v0.15.0/typst-x86_64-unknown-linux-musl.tar.xz
# plantuml(jar 直接利用の場合。Java 実行環境が必要):
#   https://repo1.maven.org/maven2/net/sourceforge/plantuml/plantuml/1.2026.6/plantuml-1.2026.6.jar
#   使い方: make pdf PLANTUML='java -jar /path/to/plantuml-1.2026.6.jar'
```

plantuml が必要になるのは、ビルド対象の文書が PlantUML 変換図(`/build/diagrams/*.svg`)を参照している場合だけです。図を使わない文書のビルドには不要です(`Makefile` が参照の有無を判定します)。シーケンス図以外(クラス図・状態遷移図など)のレイアウトには Graphviz も必要です。

## Docker(推奨・「正」のビルド方法)

`make pdf-docker` がこのテンプレートにおける正式なビルド手順です。pandoc と typst のバージョンを `Dockerfile` 内で固定しているため、実行環境に依存せず同じ PDF が得られます。

```sh
make pdf-docker
```

`docker run` には `--user $(id -u):$(id -g)` を付与しているため、`build/` 配下に生成されるファイルはホスト側の実行ユーザー所有になります(コンテナ内で root 所有になる問題を避けるため)。

同梱の `Dockerfile` がダウンロードする Typst バイナリは既定で x86_64(Linux, musl 静的ビルド)向けです。Apple Silicon などの別アーキテクチャ上でビルドする場合は `TYPST_ARCH` ビルド引数で差し替え、あわせて対応する `TYPST_SHA256`(下記参照)も指定してください(例: `docker build --build-arg TYPST_ARCH=aarch64-unknown-linux-musl --build-arg TYPST_SHA256=<対応するsha256> .`)。

### Typst バイナリのチェックサム検証

`Dockerfile` は Typst の実行バイナリを GitHub Releases から取得し、`Dockerfile` に焼き込み済みの sha256(既定の `TYPST_VERSION` / `TYPST_ARCH` 用)で必ず検証します。ダウンロードしたバイナリが一致しない場合(改ざん・破損・バージョン不一致)はビルドが**エラーで停止**します。通常の `make pdf-docker` では何も指定する必要はありません。

参考: v0.15.0 の musl 静的ビルドの sha256(GitHub Releases のアセットダイジェスト):

| アーキテクチャ | sha256 |
|---|---|
| `x86_64-unknown-linux-musl`(既定。`Dockerfile` に設定済み) | `59b207df01be2dab9f13e80f73d04d7ff8273ffd46b3dd1b9eef5c60f3eeabea` |
| `aarch64-unknown-linux-musl` | `cdf50ffc7b8ba759ed02200632eda3d78eb8b99aacb6611f4f75684990647620` |

`TYPST_VERSION` や `TYPST_ARCH` を変更する場合は、対応するアセットの sha256 を取得して差し替えてください。

sha256 の取得方法(ワンライナー。URL のバージョン・アーキテクチャは適宜読み替え):

```sh
curl -fsSL "https://github.com/typst/typst/releases/download/v0.15.0/typst-x86_64-unknown-linux-musl.tar.xz" | sha256sum
```

取得した値を指定してビルドする:

```sh
make pdf-docker TYPST_SHA256=<取得したsha256>
```

チェックサム検証なしでビルドする場合(非推奨。検証値を用意できない例外的な場合のみ。焼き込み済みの既定値による検証もスキップされます):

```sh
make pdf-docker ALLOW_UNVERIFIED=1
```

### PlantUML jar のチェックサム検証

`Dockerfile` は PlantUML の jar を Maven Central(`repo1.maven.org`)から取得し、焼き込み済みの sha256 で必ず検証します。Maven Central の成果物はイミュータブル(同一バージョンの再 push 不可)で、jar はアーキテクチャ非依存のため、バージョンと sha256 の固定だけで決定的に導入できます。

| バージョン | sha256 |
|---|---|
| 1.2026.6(既定。`Dockerfile` に設定済み) | `e620ae095a2ba0134d3c33fd5ae34ff01e785f3df1796c0898802b8761a033a8` |

バージョンを変更する場合は、`Dockerfile` の `PLANTUML_VERSION` / `PLANTUML_SHA256` と `Makefile` の `EXPECTED_PLANTUML` をあわせて更新してください。sha256 の取得方法:

```sh
curl -fsSL "https://repo1.maven.org/maven2/net/sourceforge/plantuml/plantuml/<version>/plantuml-<version>.jar" | sha256sum
```

**図中テキストのフォントについて**: 全 PlantUML 図には `template/plantuml.config` が共通適用され、図中テキストのフォントを本文と同じ `Source Han Sans JP` に指定しています。生成される SVG はテキストをアウトライン化せずフォント名参照のまま保持し、Typst が `assets/fonts/`(`--font-path`)から解決して描画するため、最終 PDF のフォントは実行環境に依存しません。また Docker イメージには「実行時にマウントされる `/work/assets/fonts` を参照する fontconfig 設定」を焼き込んであり、PlantUML(Java)によるテキスト幅の計測も同じフォントで行われます(計測フォントが異なると、ラベル幅と図形サイズがずれることがあります)。

### ベースイメージ(pandoc/core)の digest 固定

`Dockerfile` は既定で `pandoc/core:3.10` をタグ指定で使用しています。タグはリポジトリ側で再 push されうるため、より厳密な決定性が必要な場合は digest を固定してください。

```sh
docker pull pandoc/core:3.10
docker inspect --format '{{index .RepoDigests 0}}' pandoc/core:3.10
# 例: pandoc/core@sha256:<digest>
```

取得した digest を `PANDOC_IMAGE` ビルド引数として指定します(`docker build` を直接呼ぶか、`Makefile` の `docker-build` ターゲットに引数を追加してください)。

```sh
docker build --build-arg PANDOC_IMAGE=pandoc/core@sha256:<digest> -t jp-spec-builder .
```

## ビルドの決定性について

同じ Markdown から常に同じ PDF(バイト単位ではなく見た目単位)を再現できるよう、次の対策をしています。

- **バージョンピン**: `Dockerfile` で pandoc(ベースイメージ)と typst(`ARG TYPST_VERSION`)、plantuml(`ARG PLANTUML_VERSION`)のバージョンを固定しています。PlantUML はバージョンによって図のレイアウトが微妙に変わるため、図の見た目を厳密に揃えたい場合も `make pdf-docker` を使ってください。
- **`--ignore-system-fonts`**: `typst compile` に必ず付与し、実行環境にインストールされているフォントの影響を受けないようにしています。フォントは `assets/fonts/`(`--font-path`)のみを参照します。
- **`date: none`**: `spec-doc` 内部で PDF のドキュメントメタデータの `date` は常に `none` に設定しています(ビルド実行時刻を PDF に埋め込まない)。表紙に表示される発行日は YAML メタデータの `date` フィールド(文字列)であり、ビルド時刻とは無関係です。
- **CI での検証**: GitHub Actions(`.github/workflows/build.yml`)が PR のたびに `make pdf-docker` で同梱サンプル 2 種(章別ファイル分割・単一ファイル)をビルドし、固定ツールチェーンの取得(ベースイメージのタグ・Typst の sha256 検証を含む)から PDF 生成までを通しで検証します。生成された PDF はワークフローのアーティファクトとしてダウンロードでき、PR 上で見た目を確認できます。

## フォント

`assets/fonts/` に同梱しているフォントと、Typst で指定する際の実際のファミリー名(OpenType name テーブルに基づく)は次のとおりです。

| ファイル | 用途 | Typst 上のファミリー名 | ウェイト |
|---|---|---|---|
| `SourceHanSerifJP-Regular.otf` | 本文(明朝) | `Source Han Serif JP` | Regular (400) |
| `SourceHanSerifJP-Bold.otf` | 本文太字 | `Source Han Serif JP` | Bold (700) |
| `SourceHanSansJP-Medium.otf` | 見出し・表・UI(ゴシック) | `Source Han Sans JP` | Medium (500) |
| `SourceHanSansJP-Bold.otf` | 見出し太字 | `Source Han Sans JP` | Bold (700) |
| `SourceHanCodeJP-Regular.otf` | コード(等幅) | `Source Han Code JP R` | Regular (400) |
| `SourceHanCodeJP-Bold.otf` | コード太字 | `Source Han Code JP R` | Bold (700) |

いずれも [Adobe Source Han (Noto CJK 系)](https://github.com/adobe-fonts) のフォントで、[SIL Open Font License 1.1](https://scripts.sil.org/OFL) の下で配布されています。ライセンス条文は `assets/fonts/LICENSE-*.txt` に同梱しています(OFL の再配布条件に従い、フォントとライセンス文書を必ずセットで扱ってください)。

**著作権表示について**: `LICENSE-SourceHanCodeJP.txt` に著作権表示ブロックが無いこと、`LICENSE-SourceHanSerif.txt` の著作権年がフォント実体の name テーブルの年と一致しないことは、いずれも上流リポジトリの `LICENSE.txt` 由来であり、本リポジトリで手を加えたものではありません(著作権表示自体は各フォントの OpenType name テーブルに記載されています)。

**注意(重要)**: `Source Han Code JP` のファイル内部の正式なファミリー名(OpenType name テーブル)は、見かけ上は `Source Han Code JP` ですが、Typst のフォントマッチングでは `Source Han Code JP R` を指定しないと解決できません(`R`/`B` が weight として自動分離されないため)。同様に `Source Han Sans JP Medium` は `Source Han Sans JP`(ファミリー名からウェイト語が自動的に取り除かれる)として解決されます。フォントを差し替える際は、`fontTools` などで name テーブルを確認し、`template/spec.typ` 冒頭の `font-serif` / `font-sans` / `font-code` の値を実際に解決できるファミリー名に合わせて修正してください。

### 別フォントへの差し替え手順(例: UDEV Gothic など)

1. `assets/fonts/` に新しいフォントファイルとライセンス文書を配置する(不要になった同梱フォントは削除してよい)。
2. `fontTools` 等で正しいファミリー名を確認する(`Source Han Code JP` の例のように、見かけと実際の解決名が異なることがあるため、必ず実際にコンパイルして確認すること)。
3. `template/spec.typ` 冒頭の `font-serif` / `font-sans` / `font-code` を新しいファミリー名に書き換える。PlantUML 図を使っている場合は `template/plantuml.config` の `defaultFontName` もあわせて書き換える(図中テキストも Typst が同じ仕組みでフォント解決するため)。
4. `make pdf` を実行し、`Typst warning: unknown font family: ...` が出ないことを確認する(PlantUML 図がある場合は図中テキストの描画も確認する)。

## シンタックスハイライト

コードブロックのシンタックスハイライト配色は `assets/typst-highlight.tmTheme`(TextMate 形式の配色テーマ)で定義しています。既定のハイライト配色は彩度の高い色(赤紫・鮮緑等)を含み、本テンプレートの青系を基調とした紙面の規律から浮いてしまうため、低彩度のパレットに差し替えています。`template/spec.typ` 側で `set raw(theme: "/assets/typst-highlight.tmTheme")` として読み込んでいます(`--root .` 前提のルート相対パス)。コードブロックの背景色(`code-bg`)はテーマではなく `spec.typ` 側で描画しているため、テーマファイル自体には背景色を指定していません。配色を変更したい場合はこの tmTheme ファイルを編集してください。

## 既知の制約・注意点

- 本テンプレートは Typst 0.15 系の構文を前提としています。
- Docker イメージの `TYPST_SHA256` には、既定の `TYPST_VERSION` / `TYPST_ARCH`(v0.15.0 / x86_64 musl)向けの値が `Dockerfile` に設定済みで、ビルド時に必ず検証されます。Typst のバージョンやアーキテクチャを変更する場合は、対応する sha256 への差し替えが必要です(上記「Typst バイナリのチェックサム検証」参照)。
- `pandoc/core` ベースイメージは既定でタグ(`pandoc/core:3.10`)固定であり、digest 固定ではありません。より厳密な決定性が必要な場合は上記「ベースイメージ(pandoc/core)の digest 固定」の手順に従い `PANDOC_IMAGE` を digest 指定に切り替えてください。
