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
  - version: "1.1"
    date: "2026-06-10"
    author: "鈴木花子"
    changes: "API仕様の章を追加、エンドポイント一覧を拡充"
  - version: "1.2"
    date: "2026-07-14"
    author: "山田太郎"
    changes: "非機能要件を追記し、用語定義を見直し"
---

<!--
  このサンプルは、社内向け在庫管理システムが提供する REST API の仕様書
  を想定した例です。Markdown は構造（見出し・表・リスト・コード）のみを
  記述し、体裁（フォント・色・余白など）は一切記述しません。体裁の責務は
  すべて template/spec.typ 側に集約されています。

  見出しには「1.」「1.1」のような番号を手で書かないでください。
  Typst 側の #set heading(numbering: "1.1.1") が自動的に採番します。
-->

