# CLAUDE.md

このリポジトリで Markdown 仕様書を執筆・ビルドする AI エージェント向けの手引きです。人間向けの詳しい説明は `README.md` を参照してください。

## ビルドコマンド

```sh
make pdf                      # docs/sample-spec(章別ファイル分割)を build/sample-spec.pdf にビルド
make pdf SRC=docs/foo.md      # 単一 Markdown ファイルをビルド
make pdf SRC=docs/foo         # 章別ファイル分割ディレクトリをビルド(下記参照)
make watch SRC=docs/foo.md    # 執筆中の自動リビルド(保存するたびに再ビルド。Ctrl-C で終了)
make lint                     # docs/*.md(単一ファイル)+ docs/*/(章別ファイル分割)の簡易 lint のみを実行
make clean                    # build/ を削除
```

`make pdf` は次の順で実行されます(`Makefile` の実行順)。

1. 実際の pandoc / typst のバージョンを表示し、期待バージョン(README 参照)と異なる場合は警告を表示する(ビルドは継続する)。あわせて `SRC` の存在確認(章別ファイル分割の場合は `00-meta.md` と章ファイルの有無)を行う。
2. `scripts/lint.sh` でビルド対象の Markdown を簡易チェックする(`make lint` は `docs/*.md` 全件 + `docs/*/` の章別ファイル分割ディレクトリすべてが対象。ただし改訂履歴ファイル `docs/*.revisions.md` / `docs/<name>/revisions.md` は仕様書本文ではないため lint.sh 側で除外される。`.revisions.yaml` / `revisions.yaml` も対象外)。
   - **エラー(ビルド停止)**: 見出しの手動採番(`# 1. foo` / `## 2) foo` のような「番号+ドット/括弧+空白」、`# 第1章 foo` / `# 1章 foo` のような「(第)N章/節/項」)、YAML フロントマターの `title:` 欠落・空、章別ファイル分割時に `00-meta.md` 以外の章ファイルへ YAML フロントマターが混入していること(後方ファイルが前方を上書きする合成規則による事故防止。下記「章別ファイル分割」参照)。
   - **警告(ビルド継続)**: 見出しが数字で始まる(`## 2.5 系` 等。上記エラーパターンに一致しない、手動採番の疑いがあるだけのケース)、生 Typst(` ```{=typst} `)ブロック内の装飾コード(`set text(` 等)、章別ファイル分割時に同一ディレクトリ内の章ファイル間で脚注定義 ID(`[^id]:`)が重複していること。
3. `pandoc --from markdown --to typst --standalone --template template/template.typ -o build/<name>.typ <SRC_INPUTS>`。`<SRC_INPUTS>` は単一ファイルモードでは `SRC` 1 個、章別ファイル分割モードでは `00-meta.md` を含む章ファイル一覧(ファイル名の辞書順)。pandoc は複数の入力ファイルを連結して 1 文書として処理でき、章の自動採番・ファイル横断リンク・脚注・表番号・表紙/目次のいずれも単一ファイルと同様に正しく動作する。改訂履歴の別ファイルがある場合は `--metadata-file` が自動付与される: `revisions.md`(単一ファイルモードでは `docs/<name>.revisions.md`。推奨。Markdown パイプ表)なら `scripts/revisions-md2yaml.sh` が `build/<name>.revisions.yaml` へ変換してから、`revisions.yaml`(単一ファイルモードでは `docs/<name>.revisions.yaml`。代替)ならそのまま渡される。**両方が存在するとエラーで停止する**。`SRC` に `.revisions.md` / `.revisions.yaml` そのものを指定してもエラーで停止する
4. `typst compile --root . --font-path assets/fonts --ignore-system-fonts build/<name>.typ build/<name>.pdf`

pandoc / typst が PATH にない場合は `make pdf-docker` を使う(Docker イメージ内でビルド)。

`SRC` のパスにスペースは使えない(Make の引数分割の制約のため)。スペースを含むパスを指定すると `make pdf` / `make pdf-docker` / `make watch` は明確なエラーメッセージで停止する(章別ファイル分割のディレクトリパスも対象)。

`make watch` は (a) 初回 `make pdf` 相当を実行 → (b) `typst watch` をバックグラウンド起動(`.typ` / `template/*.typ` の変更を自動検知)→ (c) `<SRC_INPUTS>`(と改訂履歴の別ファイルが存在すればそれも)を 1 秒間隔でポーリングし、変更を検知したら lint →(`.revisions.md` / `revisions.md` があれば YAML 変換)→ pandoc を再実行して `.typ` を再生成する、という三段構成。章別ファイル分割の場合、章ファイルを 1 つ編集して保存するだけで `<SRC_INPUTS>` 全体が pandoc に再度渡され `.typ` 全体が再生成される(章ファイルを新規追加した場合はポーリング対象に含まれないため `make watch` の再起動が必要)。lint / 変換 / pandoc がエラーになっても watch 自体は停止せず継続する(修正して保存すれば次のポーリングで再試行される)。Ctrl-C で `typst watch` の子プロセスごと終了する。詳細は README の「執筆中の自動更新」節を参照。

## 章別ファイル分割

`SRC` にディレクトリを指定すると(例: `docs/sample-spec`)、章ごとに分けた複数の Markdown ファイルを 1 文書としてビルドできる。ディレクトリ規約:

- **`00-meta.md`**: フロントマター専用・必須。ここにのみ `title` 等のメタデータを書く。
- **`[0-9][0-9]-*.md`**: 章ファイル。ファイル名の辞書順が章順(`00-meta.md` は自然に先頭に来る)。1 つ以上必須。後から章を挿入しやすいよう `10-`, `20-`, `30-` のように番号を飛ばして振る運用も可。
- **`revisions.md`(推奨)/ `revisions.yaml`(代替)**: 単一ファイルモードの `<name>.revisions.md` / `<name>.revisions.yaml` と同じ仕組み(README の「改訂履歴の別ファイル化」参照)。

**フロントマターは 00-meta.md にのみ書くこと**。Pandoc は複数入力ファイルを連結する際、後方ファイルのフロントマターが前方を上書きするため、章ファイルにフロントマターを混入させると `title` 等が意図せず上書き・消去される(`scripts/lint.sh` がこれをエラーで検出する)。脚注定義 ID(`[^id]:`)は分割全体で一意にすること(重複すると連結時に衝突する。`scripts/lint.sh` が警告で検出する)。

実例: `docs/sample-spec/` が章別ファイル分割、`docs/wareki-api-spec.md` が単一ファイル方式。

## 執筆 → ビルド → 確認 → 修正のループ

1. `docs/*.md` を編集する(構造のみ。スタイル記述は禁止。詳細は README の「執筆ルール」参照)。
2. `make pdf` を実行する。
3. **Typst のエラーを読む**:
   - `typst compile` が失敗したら、エラーメッセージの該当行を `build/<name>.typ` で直接開いて確認する。これは Pandoc が生成した Typst ソースなので、Markdown のどの記述がどの Typst コードに対応するかを突き合わせながら原因を特定する。
   - `unknown font family: ...` という警告/エラーが出た場合は、`template/spec.typ` の `font-serif` / `font-sans` / `font-code` に指定しているファミリー名と、`assets/fonts/` 内フォントの実際の name テーブルが一致しているか確認する(`fontTools` で確認できる)。CJK フォントは表面上のファミリー名と Typst が実際に解決するファミリー名が異なることがある(例: `Source Han Code JP` ではなく `Source Han Code JP R` でないと解決できない)。
   - Typst の構文エラー(`expected comma` 等)は行番号が付かないことがある。疑わしい箇所を最小構成に切り出して単体コンパイルすると原因を特定しやすい。
4. **PDF を目視確認する**。可能であれば PNG に書き出して確認する:
   ```sh
   # Python バインディングがあれば以下でページごとの PNG を得られる
   python3 -c "import typst; typst.compile('build/<name>.typ', output='build/<name>-{p}.png', root='.', font_paths=['assets/fonts'], ignore_system_fonts=True, format='png', ppi=150)"
   ```
   確認観点: 表紙のレイアウト崩れ、改訂履歴・目次のページ番号、見出しの採番が二重になっていないか(下記の注意参照)、表のヘッダ網掛け・罫線、コードブロックの等幅フォント、和文の禁則・justify、ヘッダ/フッタが表紙に出ていないか、フォント未解決による代替フォント(明朝でない文字など)、表紙タイトルの泣き別れ(1 文字だけの行)、章末の数行・表・コード片だけが孤立したほぼ白紙のページ(本文の編集で吸収する)、同種の表の幅が揃っているか(列幅はパイプテーブル区切り行のダッシュ比率で統一できる)。
5. 崩れがあれば `template/spec.typ` (見た目) または Markdown 本文(構造)を修正し、3〜4 を再度回す。

## 執筆ルールの要点

- **Markdown は構造のみ**。フォント指定・色・余白などのスタイル記述は書かない。すべて `template/spec.typ` が担う。
- **見出しに手動で番号を振らない**。`# はじめに` と書けば `1 はじめに` のように自動採番される。`# 1. はじめに` のように自分で番号を書くと、Typst の自動採番と二重になって `1 1. はじめに` のような表示になってしまう(実際に起きたバグなので特に注意)。
- 見出しレベル: H1=章(章ごとに自動改ページ)、H2=節、H3=項、H4 以降=番号なし小見出し。
- 表・コードブロック・脚注は Markdown 標準の記法をそのまま使う。表の網掛け・罫線・キャプション書式は自動適用される。
- **改訂履歴(`revisions`)が長くなったら別ファイルに切り出せる**。推奨は `docs/<name>.revisions.md`(章別ファイル分割の場合は `docs/<name>/revisions.md`)という Markdown パイプ表(列は「版数|日付|作成者|改訂内容」の 4 列固定、1 改訂 = 1 行、セル内に生の `|` は不可)。代替として `docs/<name>.revisions.yaml` / `docs/<name>/revisions.yaml`(トップレベルに `revisions:` 配列)も使える。いずれも置くだけで `Makefile` が自動検出して pandoc の `--metadata-file` に反映する(`docs/wareki-api-spec.md` + `docs/wareki-api-spec.revisions.md` が単一ファイルモードの実例)。`.revisions.md` と `.revisions.yaml` の併存はビルドエラーになる。Pandoc の合成規則上、フロントマター側の `revisions` は `--metadata-file` 側より優先されて上書きされるため、**`revisions` はフロントマター・別ファイルのいずれか 1 箇所にのみ書く**(推奨: `.revisions.md` / `revisions.md`)。詳細は README の「改訂履歴の別ファイル化」節を参照。

## エスケープハッチの判断基準

生 Typst(` ```{=typst} ` フェンス)は次のように判断する。

- **使ってよい**: セル結合(`table.cell(colspan:, rowspan:)`)など、Markdown 標準の記法では原理的に表現できないもの。
- **使うべきでない**: 見た目の微調整、Markdown で表現できる内容(それは `spec.typ` 側の show/set ルールを直すべき)。
- 生 Typst ブロック内では `template/spec.typ` の色定数・フォント定数・ヘルパー関数を `accent-color` などとしてそのまま参照できる(`template/template.typ` が `#import "/template/spec.typ": *` している)。table を生 Typst で書く場合も、罫線やヘッダ網掛けは `spec.typ` の `show table: ...` が自動適用するので、通常は `#table(...)` を素直に書けば十分(手動で block 装飾を重ねる必要はない)。

## 見た目を変更したいとき

`template/spec.typ` のみを編集する。主な構成:

- 冒頭: 色定数(`accent-color` 等)・フォント定数(`font-serif` / `font-sans` / `font-code`)
- `cover-page`: 表紙
- `revision-history`: 改訂履歴表
- `doc-header` / `doc-footer`: 2 ページ目以降のヘッダ・フッタ
- `spec-doc`: メインエントリポイント。見出し・表・コード・リンク・引用などの show/set ルール一式と、表紙 → 改訂履歴 → 目次 → 本文(ページ番号 1 起算。改訂履歴と目次はそれぞれ独立したページ)という全体構成を持つ

`template/template.typ` は Pandoc のメタデータを `spec-doc(...)` の引数へ橋渡しするだけで、見た目に関する記述を追加してはいけない。
