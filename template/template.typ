// =============================================================================
// template.typ — Pandoc 用 Typst テンプレート
//
// `pandoc --from markdown --to typst --template template/template.typ` から
// 使用される。見た目に関する定義は一切ここに書かず、すべて spec.typ 側の
// `spec-doc` 関数に委譲する(責務分離)。
//
// 以下の定義は `pandoc -D typst` が出力するデフォルトテンプレートに由来し、
// Pandoc の Typst ライターが前提とする補助定義(水平線・定義リストなど)を
// 落とさないために保持している。装飾目的の #set 系(フォント・余白・表罫線
// など)はすべて削除し、spec.typ に一元化した。
// -----------------------------------------------------------------------------

#let horizontalrule = line(start: (25%, 0%), end: (75%, 0%))

$if(highlighting-definitions)$
// syntax highlighting functions from skylighting:
$highlighting-definitions$

$endif$
#import "/template/spec.typ": *

$if(smart)$
$else$
#set smartquote(enabled: false)

$endif$
$for(header-includes)$
$header-includes$

$endfor$
#show: doc => spec-doc(
$if(title)$
  title: [$title$],
$endif$
$if(subtitle)$
  subtitle: [$subtitle$],
$endif$
$if(docnumber)$
  docnumber: [$docnumber$],
$endif$
$if(version)$
  version: [$version$],
$endif$
$if(date)$
  date: [$date$],
$endif$
$if(author)$
  author: [$author$],
$endif$
$if(organization)$
  organization: [$organization$],
$endif$
$if(logo)$
  logo: image("$logo$", height: 12mm),
$endif$
$if(revisions)$
  revisions: (
$for(revisions)$
    (
      version: [$revisions.version$],
      date: [$revisions.date$],
      author: [$revisions.author$],
      changes: [$revisions.changes$],
    ),
$endfor$
  ),
$endif$
  doc,
)

$for(include-before)$
$include-before$

$endfor$
$body$

$if(citations)$
$for(nocite-ids)$
#cite(label("${it}"), form: none)
$endfor$
$if(csl)$

#set bibliography(style: "$csl$")
$elseif(bibliographystyle)$

#set bibliography(style: "$bibliographystyle$")
$endif$
$if(bibliography)$

#bibliography(($for(bibliography)$"$bibliography$"$sep$,$endfor$)$if(full-bibliography)$, full: true$endif$)
$endif$
$endif$
$for(include-after)$

$include-after$
$endfor$
