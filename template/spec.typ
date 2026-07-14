// =============================================================================
// spec.typ — 日本語仕様書テンプレートのテーマ本体
//
// 美観に関する責務はすべてこのファイルに集約する。Markdown / Pandoc 側は
// 構造(見出し・表・コードなど)のみを担当し、見た目はここで一元管理する。
//
// エントリポイントは `spec-doc` 関数。template/template.typ から
// `#show: spec-doc.with(...)` の形で呼び出される。
// =============================================================================

// ---- 配色 -------------------------------------------------------------
#let accent-color = rgb("#1f4e79") // 濃紺(アクセント)
#let accent-soft = rgb("#4a6d8c") // やや明るい濃紺(補助テキスト等)
#let rule-gray = rgb("#c9c9c9") // 罫線グレー
#let header-gray = rgb("#8a8a8a") // ヘッダ/フッタの淡いグレー
#let body-text-gray = rgb("#4d4d4d") // 引用文などの本文グレー
#let table-header-bg = rgb("#eef1f5") // 表ヘッダの薄グレー地
#let code-bg = luma(248) // コードブロック背景
#let code-border = luma(222) // コードブロック枠線

// ---- フォント -----------------------------------------------------------
#let font-serif = "Source Han Serif JP" // 本文(明朝)
#let font-sans = "Source Han Sans JP" // 見出し・表・UI 要素(ゴシック)
// 注意: フォント内部の name テーブルでは "Source Han Code JP R" が実際に
// マッチするファミリー名(Typst は "R"/"B" を weight として自動分離しない)。
#let font-code = "Source Han Code JP R" // コード(等幅)

// =============================================================================
// 内部ユーティリティ
// =============================================================================

// content を平文文字列に変換する(document() の author 等は str を要求するため)
#let content-to-string(content) = {
  if type(content) == str {
    content
  } else if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  } else {
    ""
  }
}

// 表紙・改訂履歴などで使う細い罫線
#let thin-rule(width: 100%, weight: 0.6pt, color: rule-gray) = {
  line(length: width, stroke: weight + color)
}

// 章(H1)扉に使う太めの濃紺罫線
#let accent-rule(width: 100%, weight: 1.1pt) = {
  line(length: width, stroke: weight + accent-color)
}

// =============================================================================
// 表紙
// =============================================================================
#let cover-page(
  title: none,
  subtitle: none,
  docnumber: none,
  version: none,
  date: none,
  author: none,
  organization: none,
  logo: none,
) = {
  set page(numbering: none, header: none, footer: none)

  // 上部の細い濃紺ルール
  v(8mm)
  accent-rule(weight: 1.4pt)
  v(1fr)

  // タイトル文字数に応じたフォントサイズ(長いタイトルの折り返しで
  // 1 文字だけが孤立する「泣き別れ」を軽減するヒューリスティック)
  let title-len = if title != none { content-to-string(title).clusters().len() } else { 0 }
  let title-size = if title-len > 16 { 22pt } else { 26pt }

  // タイトルブロック(中央)
  align(center)[
    #if logo != none {
      block(below: 1.2em)[#logo]
    }
    #if organization != none {
      block(below: 2em)[
        #set text(font: font-sans, size: 11pt, fill: accent-soft, weight: "medium")
        #organization
      ]
    }
    #block(below: if subtitle == none { 0em } else { 0.9em })[
      #set par(justify: false, linebreaks: "optimized", leading: 0.45em)
      #set text(font: font-sans, size: title-size, weight: "bold")
      #title
    ]
    #if subtitle != none {
      block[
        #set text(font: font-sans, size: 14pt, weight: "medium", fill: accent-soft)
        #subtitle
      ]
    }
  ]

  v(1fr)

  // 下部の書誌情報(整列テーブル)
  let info-rows = ()
  if docnumber != none { info-rows.push(([文書番号], [#docnumber])) }
  if version != none { info-rows.push(([版数], [#version])) }
  if date != none { info-rows.push(([発行日], [#date])) }
  if author != none { info-rows.push(([作成者], [#author])) }

  align(center)[
    #block(width: 80%)[
      #thin-rule(weight: 0.8pt)
      #v(0.9em)
      #set text(font: font-sans, size: 10pt)
      #table(
        columns: (1fr, 1fr),
        stroke: none,
        fill: none,
        inset: (x: 4pt, y: 5pt),
        align: (left, left),
        ..info-rows.flatten()
      )
    ]
  ]

  v(12mm)
  accent-rule(weight: 1.4pt)
  v(4mm)
}

// =============================================================================
// 改訂履歴
// =============================================================================
#let revision-history(revisions: ()) = {
  if revisions.len() > 0 {
    heading(level: 1, numbering: none, outlined: false)[改訂履歴]
    v(0.4em)
    set text(font: font-sans, size: 9pt)
    table(
      columns: (10%, 18%, 22%, 50%),
      stroke: none,
      inset: (x: 8pt, y: 6pt),
      align: (center + horizon, center + horizon, center + horizon, left + horizon),
      table.header([版数], [日付], [作成者], [改訂内容]),
      table.hline(),
      ..revisions
        .map(r => (
          [#r.version],
          [#r.date],
          [#r.author],
          [#r.changes],
        ))
        .flatten()
    )
  }
}

// =============================================================================
// ヘッダ・フッタ(本文用)
// =============================================================================
#let doc-header(title: none, docnumber: none) = context {
  set text(font: font-sans, size: 8pt, fill: header-gray)
  grid(
    columns: (1fr, auto),
    align: (left + horizon, right + horizon),
    [#title],
    [#if docnumber != none [#docnumber]],
  )
  v(-0.35em)
  thin-rule(weight: 0.5pt, color: rule-gray)
}

#let doc-footer() = context {
  set align(center)
  set text(font: font-sans, size: 8.5pt, fill: header-gray)
  [#counter(page).display("1") / #counter(page).final().first()]
}

// =============================================================================
// spec-doc: メインエントリポイント
// =============================================================================
#let spec-doc(
  title: none,
  subtitle: none,
  docnumber: none,
  version: none,
  date: none,
  author: none,
  organization: none,
  logo: none,
  revisions: (),
  body,
) = {
  // ---- 文書メタデータ(date は決定的ビルドのため常に none) ----
  set document(
    title: if title != none { title } else { auto },
    author: if author != none { (content-to-string(author),) } else { () },
  )

  // ---- 基本ページ設定 ----
  set page(
    paper: "a4",
    margin: (top: 30mm, bottom: 30mm, left: 25mm, right: 25mm),
  )

  // ---- 基本文字設定(本文は明朝) ----
  set text(
    lang: "ja",
    region: "JP",
    font: font-serif,
    size: 10pt,
    cjk-latin-spacing: auto,
  )
  set par(
    justify: true,
    leading: 0.85em,
    first-line-indent: (amount: 1em, all: true),
  )

  // ---- 見出し番号: レベル3まで "1.1.1" ----
  set heading(numbering: "1.1.1")

  // ---- リンク(濃紺・下線なし。Typst のリンクは既定で下線なし) ----
  show link: set text(fill: accent-color)

  // ---- 強調 ----
  show strong: set text(weight: "bold")

  // ---- 引用(blockquote) ----
  show quote.where(block: true): it => block(
    width: 100%,
    inset: (left: 1.1em, top: 0.5em, bottom: 0.5em, right: 0.6em),
    stroke: (left: 2pt + accent-soft),
    fill: luma(250),
  )[
    #set text(fill: body-text-gray, style: "normal")
    #it.body
  ]

  // ---- リスト ----
  set list(marker: ([•], [–]), indent: 0.3em, spacing: 0.65em)
  set enum(indent: 0.3em, spacing: 0.65em)

  // ---- コードブロック(等幅フォント) ----
  show raw: set text(font: font-code)

  // 短いコードブロックはページ境界で分割せず丸ごと次ページへ送る
  // (ページ末尾に上枠だけの空断片が残るのを防ぐ)。長いものだけ分割を許可する。
  show raw.where(block: true): it => block(
    width: 100%,
    fill: code-bg,
    stroke: 0.6pt + code-border,
    radius: 2pt,
    inset: 8pt,
    breakable: it.text.split("\n").len() > 20,
  )[
    #set text(size: 8.5pt)
    #set par(justify: false, leading: 0.72em)
    #it
  ]

  show raw.where(block: false): box.with(
    fill: code-bg,
    outset: (y: 2.5pt),
    inset: (x: 3pt),
    radius: 2pt,
  )

  // ---- 表 ----
  // 注意: show table.cell.where(y:0): set table.cell(fill: ...) は
  // このバージョンの Typst では反映されないため、table 自体の fill を
  // 位置関数で与える方式を用いている(bold は show/set text で問題なく反映される)。
  set table(
    stroke: none,
    inset: (x: 8pt, y: 6pt),
    fill: (x, y) => if y == 0 { table-header-bg } else { none },
  )
  show table.cell.where(y: 0): set text(font: font-sans, weight: "bold")
  // Pandoc は表を align(center)[#table(align: (auto, ...))] として出力するため、
  // 何もしないと本文セルが外側の中央揃えを継承してしまう。既定は左揃え+垂直中央とし、
  // Markdown 側で明示された列揃え(:---: 等)は table の align 引数が優先されるため保持される。
  show table.cell: set align(start + horizon)
  show table: set text(size: 9pt)
  show table: it => block(
    stroke: (top: 1.1pt + accent-color, bottom: 1.1pt + accent-color),
    inset: 0pt,
    it,
  )
  show table.hline: set line(stroke: 0.6pt + rule-gray)

  show figure.where(kind: table): set figure.caption(position: top)
  show figure.where(kind: image): set figure.caption(position: bottom)
  show figure.caption: set text(font: font-sans, size: 9pt)

  // ---- 脚注 ----
  set footnote.entry(separator: thin-rule(width: 30%, weight: 0.5pt))
  show footnote.entry: set text(size: 8.5pt)

  // ---- 見出しスタイル ----
  // H1: 章。ページを改め、太めの濃紺ルールを前後に配置する。
  show heading.where(level: 1): it => {
    if it.outlined {
      pagebreak(weak: true)
    }
    block(above: 0em, below: 1.5em, width: 100%)[
      #v(0.4em)
      #set text(font: font-sans, size: 16pt, weight: "bold")
      #it
      #v(0.6em)
      #accent-rule(weight: 1.1pt)
    ]
  }

  // H2: 節。左に太い濃紺バー。
  show heading.where(level: 2): it => block(above: 1.6em, below: 0.9em, width: 100%)[
    #box(
      inset: (left: 0.65em, top: 0.3em, bottom: 0.3em, right: 0.3em),
      stroke: (left: 3pt + accent-color),
    )[
      #set text(font: font-sans, size: 12pt, weight: "bold")
      #it
    ]
  ]

  // H3: 項。
  show heading.where(level: 3): it => block(above: 1.3em, below: 0.7em)[
    #set text(font: font-sans, size: 10.5pt, weight: "bold")
    #it
  ]

  // H4 以降: 番号なしの小見出し。
  show heading.where(level: 4): it => block(above: 1.1em, below: 0.5em)[
    #set text(font: font-sans, size: 10pt, weight: "bold", style: "normal")
    #it.body
  ]

  // ---- 目次の見出し文字 ----
  // 章(level 1)は太字ゴシックにして視覚的な階層を強調する。節・項は
  // 現状のまま(フォントのみゴシックに揃える)。
  show outline.entry: it => {
    set text(font: font-sans)
    if it.level == 1 {
      v(0.6em, weak: true)
      set text(weight: "bold")
      it
    } else {
      it
    }
  }

  // ===========================================================================
  // 1. 表紙
  // ===========================================================================
  cover-page(
    title: title,
    subtitle: subtitle,
    docnumber: docnumber,
    version: version,
    date: date,
    author: author,
    organization: organization,
    logo: logo,
  )

  pagebreak()

  // ===========================================================================
  // 2. 改訂履歴 + 目次(2ページ目以降はヘッダのみ表示、フッタは非表示)
  // ===========================================================================
  set page(
    header: doc-header(title: title, docnumber: docnumber),
    footer: none,
    numbering: none,
  )

  revision-history(revisions: revisions)

  if revisions.len() > 0 {
    v(2em)
  }

  heading(level: 1, numbering: none, outlined: false)[目次]
  v(0.4em)
  outline(title: none, depth: 3, indent: auto)

  pagebreak()

  // ===========================================================================
  // 3. 本文(ページ番号を 1 から起算)
  // ===========================================================================
  counter(page).update(1)
  set page(
    header: doc-header(title: title, docnumber: docnumber),
    footer: doc-footer(),
    numbering: "1",
  )

  body
}
