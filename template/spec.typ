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

// ---- レイアウト用のマジックナンバー(命名定数) --------------------------
// 表紙タイトルの折り返しヒューリスティック(cover-page で使用)。
#let title-shrink-threshold = 16 // この文字数を超えたら小さいサイズにする
#let title-size-large = 26pt // 閾値以下(短いタイトル)のフォントサイズ
#let title-size-small = 22pt // 閾値超(長いタイトル)のフォントサイズ

// 小書きかな直後の字送り補正量(spec-doc の strong ショウルールで使用)。
#let small-kana-correction = -0.12em

// ---- 和文組版グリッド ----------------------------------------------------
// 行送り設計は okumuralab/typst-js(MIT-0)の方式を参考にした。
// 和文フォントの仮想ボディは実際のグリフより大きく、Typst の既定の
// top-edge(グリフの実測 ascender)のままだと、和文とラテン文字/インライン
// コードが混在する行で行の基準位置がずれ、行送り(baseline から baseline
// までの距離)が行によって微妙に変動してしまう。typst-js の cjkheight
// (0.88em)にならい、和文の仮想ボディ高に top-edge を合わせることで、
// 欧文混じりの行でも行送りが一定になる。
// 行送り = top-edge(0.88em) + leading(0.85em) = 1.73em
// (jsarticle の baselineskip = 1.73 * fontsize と同じピッチ)
#let cjk-top-edge = 0.88em

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
  // 上部: ページ物理上端に全幅で貼り付くブリード帯(余白の外、紙面の最上端)。
  set page(
    numbering: none,
    header: none,
    footer: none,
    background: place(top, rect(width: 100%, height: 8mm, fill: accent-color, inset: 0pt, outset: 0pt)),
  )

  v(1fr)

  // タイトル文字数に応じたフォントサイズ(長いタイトルの折り返しで
  // 1 文字だけが孤立する「泣き別れ」を軽減するヒューリスティック)
  let title-len = if title != none { content-to-string(title).clusters().len() } else { 0 }
  let title-size = if title-len > title-shrink-threshold { title-size-small } else { title-size-large }

  // タイトルブロック(中央。ページのやや上(光学中心)に来るよう、
  // 前後の v(1fr) / v(1.4fr) で余白配分を調整している)
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
    #block(below: 0.9em)[
      #set par(justify: false, linebreaks: "optimized", leading: 0.45em)
      #set text(font: font-sans, size: title-size, weight: "bold")
      #title
    ]
    #if subtitle != none {
      block(below: 1em)[
        #set text(font: font-sans, size: 14pt, weight: "medium", fill: accent-soft)
        #subtitle
      ]
    }
  ]

  v(1.4fr)

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
      #grid(
        columns: (1fr, 1fr),
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
      inset: (x: 8pt, y: 7pt),
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
    title: if title != none { title } else { none },
    author: if author != none { (content-to-string(author),) } else { () },
  )

  // ---- 基本ページ設定 ----
  set page(
    paper: "a4",
    margin: (top: 30mm, bottom: 30mm, left: 25mm, right: 25mm),
    // フッタ(ページ番号)の位置。既定(30%)より 2mm 下げている
    footer-descent: 30% + 2mm,
  )

  // ---- 基本文字設定(本文は明朝) ----
  set text(
    lang: "ja",
    region: "JP",
    font: font-serif,
    size: 10pt,
    cjk-latin-spacing: auto,
    top-edge: cjk-top-edge,
  )
  set par(
    justify: true,
    leading: 0.85em,
    spacing: 0.85em,
    first-line-indent: (amount: 1em, all: true),
  )

  // ---- 見出し番号: レベル3まで "1.1.1" ----
  set heading(numbering: "1.1.1")

  // ---- リンク(濃紺・下線なし。Typst のリンクは既定で下線なし) ----
  show link: set text(fill: accent-color)

  // ---- 強調 ----
  // 小書きかな(「ぁ」「ぃ」「ゃ」等)は字送り(advance width)の右側に
  // 空白を多く持つグリフ設計のため、そのようなかなで終わる強調テキストの
  // 直後に半角記号(コロン等)が続くと不自然な空白が生じる(フォント側の
  // グリフ設計に起因するものであり、cjk-latin-spacing の設定には依らない)。
  // 該当パターンの直後だけわずかに字送りを詰めて補正する。
  let small-kana-tail = "ぁぃぅぇぉっゃゅょゎァィゥェォッャュョヮ"
  show strong: it => {
    let styled = text(weight: "bold", it.body)
    let s = content-to-string(it.body)
    if s.len() > 0 and small-kana-tail.contains(s.last()) {
      box[#styled#h(small-kana-correction)]
    } else {
      styled
    }
  }

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

  // ---- 定義リスト(Markdown の "Term\n: Description" 記法) ----
  // Pandoc の既定 Typst テンプレートに由来する装飾(太字の用語 +
  // インデントされた説明)。見た目の一元化のため template.typ から移設。
  show terms.item: it => block(breakable: false)[
    #text(weight: "bold")[#it.term]
    #block(inset: (left: 1.5em, top: -0.4em))[#it.description]
  ]

  // ---- コードブロック(等幅フォント・低彩度シンタックスハイライト) ----
  // 既定のハイライト配色は彩度が高く紙面の青系規律から浮くため、
  // assets/typst-highlight.tmTheme(低彩度パレット)に差し替える。
  // "--root ." でのビルドを前提としたルート相対パス。背景色はテーマ側
  // では指定しておらず、code-bg(下記の block fill)がそのまま透けて見える。
  set raw(theme: "/assets/typst-highlight.tmTheme")
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

  // インラインコードは、引用ブロック(fill: luma(250))など背景色を持つ
  // 領域の上に置かれても輪郭で判別できるよう、極細のボーダーを付ける
  // (code-bg 自体との明度差だけに頼らない)。
  show raw.where(block: false): box.with(
    fill: code-bg,
    stroke: 0.4pt + luma(225),
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
    inset: (x: 8pt, y: 7pt),
    fill: (x, y) => if y == 0 { table-header-bg } else { none },
  )
  show table.cell.where(y: 0): set text(font: font-sans, weight: "bold")
  // Pandoc は表を align(center)[#table(align: (auto, ...))] として出力するため、
  // 何もしないと本文セルが外側の中央揃えを継承してしまう。既定は左揃え+垂直中央とし、
  // Markdown 側で明示された列揃え(:---: 等)は table の align 引数が優先されるため保持される。
  show table.cell: set align(start + horizon)
  show table: set text(size: 9pt)
  // 本文の top-edge(0.88em)をそのまま表セルにも適用すると、行送りグリッド
  // 用に嵩上げされた分だけセルの行高(inset 込み)が間延びして見える。
  // typst-js の補正(2 × cjkheight − 1 = 0.76em)にならい、表セル内だけ
  // top-edge を下げて行高を詰める。
  show table: set text(top-edge: 0.76em)
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
  // breakable: false, sticky: true で見出しがページ最下部に孤立するのを防ぐ
  // (見出しの直後の内容が次ページに送られる場合、見出し自体も一緒に送られる)。
  show heading.where(level: 2): it => block(above: 1.4em, below: 0.75em, width: 100%, breakable: false, sticky: true)[
    #box(
      inset: (left: 0.65em, top: 0.3em, bottom: 0.3em, right: 0.3em),
      stroke: (left: 3pt + accent-color),
    )[
      #set text(font: font-sans, size: 12pt, weight: "bold")
      #it
    ]
  ]

  // H3: 項。
  show heading.where(level: 3): it => block(above: 1.15em, below: 0.6em, breakable: false, sticky: true)[
    #set text(font: font-sans, size: 10.5pt, weight: "bold")
    #it
  ]

  // H4 以降: 番号なしの小見出し(レベル 4/5/6 すべて同じ見た目)。
  let unnumbered-subheading(it) = block(above: 1.1em, below: 0.5em, breakable: false, sticky: true)[
    #set text(font: font-sans, size: 10pt, weight: "bold", style: "normal")
    #it.body
  ]
  show heading.where(level: 4): unnumbered-subheading
  show heading.where(level: 5): unnumbered-subheading
  show heading.where(level: 6): unnumbered-subheading

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
