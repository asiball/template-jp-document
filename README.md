# template-jp-document

Markdown で構造だけを書き、体裁の作り込みは Typst テーマに任せる、日本語仕様書のためのドキュメントテンプレートです。最終成果物は A4 縦の PDF です。

## コンセプト

- **Markdown → Pandoc(Typst バックエンド)→ Typst → PDF** という 2 段変換でビルドします。
- Markdown 側は見出し・表・リスト・コードブロックといった「構造」だけを記述します。フォント・配色・余白・罫線などの「美観」は一切書きません。
- 美観に関する定義はすべて `template/spec.typ` に一元化されています。デザインを変えたいときはこのファイルだけを見ればよい、という状態を保つのがこのテンプレートの目的です。
- Markdown 標準の記法では表現できないもの(セル結合を伴う表など)に限り、Pandoc の生 Typst 記法(エスケープハッチ)を使うことを許容します。

なぜこの構成か: Pandoc は Markdown の構造解析とゆるい変換に強く、Typst は組版(段組・見出し番号・和文禁則・シンタックスハイライト)に強い、という役割分担です。LaTeX と比べて Typst はビルドが高速で、テーマ定義が素直な関数ベースの Typst コードで書けるため、体裁の一元管理と保守がしやすくなっています。

## ディレクトリ構成

```
docs/sample-spec.md   サンプル仕様書(構造の書き方の実例)
template/spec.typ      テーマ本体。美観に関する定義はすべてここに集約
template/template.typ  Pandoc 用 Typst テンプレート(構造の橋渡しのみ)
assets/fonts/           同梱フォントと OFL ライセンス
Dockerfile              決定的なビルド環境
Makefile                ビルドコマンド一式
README.md               このファイル
CLAUDE.md               AI エージェント向けの執筆・ビルドガイド
```

## セットアップ

### (a) ローカルに pandoc / typst をインストールする

このテンプレートは次のバージョンで動作確認をしています(このリポジトリの検証環境で実測)。

| ツール | バージョン | 備考 |
|---|---|---|
| pandoc | 3.9 | `pypandoc-binary==1.17` が同梱するバイナリで検証 |
| typst  | 0.13.1 | Typst コンパイラの実バージョン(後述) |

インストール方法の例:

```sh
# macOS (Homebrew)
brew install pandoc typst

# Linux / 手動インストール(GitHub Releases から取得)
# pandoc:
#   https://github.com/jgm/pandoc/releases/download/3.9/pandoc-3.9-linux-amd64.tar.gz
# typst:
#   https://github.com/typst/typst/releases/download/v0.13.1/typst-x86_64-unknown-linux-musl.tar.xz
```

バージョンが異なると、見出し番号の折り返しや表の罫線など細部のレンダリングが変わる可能性があります。厳密に一致させたい場合は Docker ビルド(下記)を使ってください。

### (b) Docker(推奨・「正」のビルド方法)

`make pdf-docker` がこのテンプレートにおける正式なビルド手順です。pandoc と typst のバージョンを `Dockerfile` 内で固定しているため、実行環境に依存せず同じ PDF が得られます。

```sh
make pdf-docker
```

## 使い方

```sh
make pdf                        # docs/sample-spec.md をビルドし build/sample-spec.pdf を生成
make pdf SRC=docs/foo.md        # 任意の Markdown をビルド
make pdf-docker                 # Docker コンテナ内でビルド(正のビルド方法)
make clean                      # build/ を削除
```

`make pdf` は次の 2 段階を実行します。

1. `pandoc --from markdown --to typst --standalone --template template/template.typ` で Markdown を Typst ソースに変換(`build/<name>.typ` に出力)
2. `typst compile --root . --font-path assets/fonts --ignore-system-fonts` で PDF を生成(`build/<name>.pdf`)

## 執筆ルール

- **Markdown は構造のみ**。太字・斜体・表・コードブロック・脚注・リンクなど Markdown 標準の記法で表現できることは、それだけを使ってください。フォント指定や色付けなど見た目に関する記述は書かないでください。
- **見出しに手動で番号を振らない**。`# はじめに` のように書き、`1. はじめに` のように自分で番号を付けないでください。番号は Typst 側の `#set heading(numbering: "1.1.1")` が章(H1)〜項(H3)まで自動的に採番します。H4 以降は番号なしの小見出しとして扱われます。
- **見出しレベルの運用**:
  - H1: 章(章ごとに自動でページが変わります)
  - H2: 節
  - H3: 項
  - H4 以降: 番号なしの小見出し(多用しすぎない)
- **表**: Markdown のパイプテーブルを使ってください。キャプションを付けたい場合は表の直後に `: キャプション文` を書きます(Pandoc の table caption 記法)。ヘッダ行の網掛け・罫線・フォントは自動で適用されます。
- **コードブロック**: フェンス付きコードブロックに言語名を指定してください(例: ` ```json `)。Typst 組み込みのシンタックスハイライトが自動的に適用されます。インラインコードはバッククォート 1 つで囲みます。
- **脚注**: `本文[^1]` と `[^1]: 脚注の内容` の組み合わせで書けます。
- **括弧**: 和文中の括弧は全角括弧を使い、英数字のみを囲む場合は半角括弧を使ってください（例: 「REST API(以下、「本 API」という)」→「REST API（以下、「本 API」という）」）。コードブロック・インラインコード内の括弧は対象外です。

### メタデータ(YAML フロントマター)一覧

| 変数 | 必須 | 説明 |
|---|---|---|
| `title` | 必須 | 表紙・ヘッダに表示するタイトル |
| `subtitle` | 任意 | サブタイトル |
| `docnumber` | 任意 | 文書番号(表紙・ヘッダに表示) |
| `version` | 任意 | 版数 |
| `date` | 任意 | 発行日 |
| `author` | 任意 | 作成者 |
| `organization` | 任意 | 発行組織名 |
| `logo` | 任意 | 表紙に表示する組織ロゴ画像のパス(リポジトリルートからの絶対パス、例: `/assets/logo.png`)。推奨高さの目安は 12mm 程度(横幅は画像のアスペクト比に応じて自動調整される)。未指定の場合は表紙にロゴを表示しない |
| `revisions` | 任意 | 改訂履歴の配列。各要素は `version` / `date` / `author` / `changes` を持つ |

例:

```yaml
---
title: "在庫管理API 仕様書"
subtitle: "REST API 設計仕様"
docnumber: "SPEC-2026-001"
version: "1.2"
date: "2026-07-14"
author: "山田太郎"
organization: "株式会社サンプル"
revisions:
  - version: "1.0"
    date: "2026-05-01"
    author: "山田太郎"
    changes: "初版作成"
---
```

## エスケープハッチ(生 Typst の使い方)

大半の内容は素の Markdown で書けますが、次のように **Markdown 標準の記法では表現できない場合に限り**、Pandoc の生 Typst 記法を使ってよいことにしています。

````markdown
```{=typst}
#table(
  columns: 2,
  [結合セル], table.cell(rowspan: 2)[縦結合],
  [通常セル],
)
```
````

使ってよい場面の例:

- 表のセル結合(`table.cell(colspan: ..., rowspan: ...)`)
- Markdown の表現力を超える複雑なレイアウト

**乱用しない**でください。見た目を整えるためだけに生 Typst を使うのは避け、まずは Markdown 標準の記法と `spec.typ` 側の自動スタイリングで表現できないか検討してください。

`template/template.typ` は `#import "/template/spec.typ": *` によって `spec.typ` の定義一式(色定数・フォント定数・ヘルパー関数)を取り込んでいます。そのため生 Typst ブロックの中でも、たとえば `accent-color`(濃紺のアクセントカラー)や `font-sans` などをそのまま参照できます。`docs/sample-spec.md` の「付録A」に実例があります。

## フォント

`assets/fonts/` に同梱しているフォントと、Typst で指定する際の実際のファミリー名は次のとおりです(このリポジトリの検証環境で `fontTools` により実測)。

| ファイル | 用途 | Typst 上のファミリー名 | ウェイト |
|---|---|---|---|
| `SourceHanSerifJP-Regular.otf` | 本文(明朝) | `Source Han Serif JP` | Regular (400) |
| `SourceHanSerifJP-Bold.otf` | 本文太字 | `Source Han Serif JP` | Bold (700) |
| `SourceHanSansJP-Medium.otf` | 見出し・表・UI(ゴシック) | `Source Han Sans JP` | Medium (500) |
| `SourceHanSansJP-Bold.otf` | 見出し太字 | `Source Han Sans JP` | Bold (700) |
| `SourceHanCodeJP-Regular.otf` | コード(等幅) | `Source Han Code JP R` | Regular (400) |
| `SourceHanCodeJP-Bold.otf` | コード太字 | `Source Han Code JP R` | Bold (700) |

いずれも [Adobe Source Han (Noto CJK 系)](https://github.com/adobe-fonts) のフォントで、[SIL Open Font License 1.1](https://scripts.sil.org/OFL) の下で配布されています。ライセンス条文は `assets/fonts/LICENSE-*.txt` に同梱しています(OFL の再配布条件に従い、フォントとライセンス文書を必ずセットで扱ってください)。

**注意(重要)**: `Source Han Code JP` のファイル内部の正式なファミリー名(OpenType name テーブル)は、見かけ上は `Source Han Code JP` ですが、Typst のフォントマッチングでは `Source Han Code JP R` を指定しないと解決できません(`R`/`B` が weight として自動分離されないため)。同様に `Source Han Sans JP Medium` は `Source Han Sans JP`(ファミリー名からウェイト語が自動的に取り除かれる)として解決されます。フォントを差し替える際は、`fontTools` などで name テーブルを確認し、`template/spec.typ` 冒頭の `font-serif` / `font-sans` / `font-code` の値を実際に解決できるファミリー名に合わせて修正してください。

### 別フォントへの差し替え手順(例: UDEV Gothic など)

1. `assets/fonts/` に新しいフォントファイルとライセンス文書を配置する(不要になった同梱フォントは削除してよい)。
2. `fontTools` 等で正しいファミリー名を確認する(`Source Han Code JP` の例のように、見かけと実際の解決名が異なることがあるため、必ず実際にコンパイルして確認すること)。
3. `template/spec.typ` 冒頭の `font-serif` / `font-sans` / `font-code` を新しいファミリー名に書き換える。
4. `make pdf` を実行し、`Typst warning: unknown font family: ...` が出ないことを確認する。

## ビルドの決定性について

同じ Markdown から常に同じ PDF(バイト単位ではなく見た目単位)を再現できるよう、次の対策をしています。

- **バージョンピン**: `Dockerfile` で pandoc(ベースイメージ)と typst(`ARG TYPST_VERSION`)のバージョンを固定しています。
- **`--ignore-system-fonts`**: `typst compile` に必ず付与し、実行環境にインストールされているフォントの影響を受けないようにしています。フォントは `assets/fonts/`(`--font-path`)のみを参照します。
- **`date: none`**: `spec-doc` 内部で PDF のドキュメントメタデータの `date` は常に `none` に設定しています(ビルド実行時刻を PDF に埋め込まない)。表紙に表示される発行日は YAML メタデータの `date` フィールド(文字列)であり、ビルド時刻とは無関係です。

## 既知の制約・注意点

- 本テンプレートは Typst 0.13 系の構文を前提としています。
- Docker イメージの `TYPST_SHA256` はデフォルトで未設定です。ネットワーク制約のある環境で本テンプレートを作成したため実際のチェックサム値を取得できておらず、指定しない場合はチェックサム検証をスキップします。本番運用では [Typst の Releases ページ](https://github.com/typst/typst/releases) で該当バージョンの `typst-x86_64-unknown-linux-musl.tar.xz` の sha256 を取得し、`docker build --build-arg TYPST_SHA256=<sha256> ...` のように指定することを強く推奨します(`make docker-build` を直接呼ぶか、Makefile の `pdf-docker` ターゲットに引数を追加してください)。
