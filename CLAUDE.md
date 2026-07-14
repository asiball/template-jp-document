# CLAUDE.md

このリポジトリで Markdown 仕様書を執筆・ビルドする AI エージェント向けの手引きです。人間向けの詳しい説明は `README.md` を参照してください。

## ビルドコマンド

```sh
make pdf                      # docs/sample-spec.md を build/sample-spec.pdf にビルド
make pdf SRC=docs/foo.md      # 任意の Markdown をビルド
make clean                    # build/ を削除
```

`make pdf` は 2 段階です。

1. `pandoc --from markdown --to typst --standalone --template template/template.typ -o build/<name>.typ <SRC>`
2. `typst compile --root . --font-path assets/fonts --ignore-system-fonts build/<name>.typ build/<name>.pdf`

pandoc / typst が PATH にない場合は `make pdf-docker` を使う(Docker イメージ内でビルド)。

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
   確認観点: 表紙のレイアウト崩れ、改訂履歴・目次のページ番号、見出しの採番が二重になっていないか(下記の注意参照)、表のヘッダ網掛け・罫線、コードブロックの等幅フォント、和文の禁則・justify、ヘッダ/フッタが表紙に出ていないか、フォント未解決による代替フォント(明朝でない文字など)。
5. 崩れがあれば `template/spec.typ` (見た目) または Markdown 本文(構造)を修正し、3〜4 を再度回す。

## 執筆ルールの要点

- **Markdown は構造のみ**。フォント指定・色・余白などのスタイル記述は書かない。すべて `template/spec.typ` が担う。
- **見出しに手動で番号を振らない**。`# はじめに` と書けば `1 はじめに` のように自動採番される。`# 1. はじめに` のように自分で番号を書くと、Typst の自動採番と二重になって `1 1. はじめに` のような表示になってしまう(実際に起きたバグなので特に注意)。
- 見出しレベル: H1=章(章ごとに自動改ページ)、H2=節、H3=項、H4 以降=番号なし小見出し。
- 表・コードブロック・脚注は Markdown 標準の記法をそのまま使う。表の網掛け・罫線・キャプション書式は自動適用される。

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
- `spec-doc`: メインエントリポイント。見出し・表・コード・リンク・引用などの show/set ルール一式と、表紙 → 改訂履歴+目次 → 本文(ページ番号 1 起算)という全体構成を持つ

`template/template.typ` は Pandoc のメタデータを `spec-doc(...)` の引数へ橋渡しするだけで、見た目に関する記述を追加してはいけない。
