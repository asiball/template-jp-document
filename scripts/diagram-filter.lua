-- =============================================================================
-- scripts/diagram-filter.lua — PlantUML ソース参照を生成済み SVG に差し替える
--
-- Markdown 側は管理対象のソース(/assets/diagrams/<name>.puml)だけを参照し、
-- ビルド時にこのフィルタが Makefile の変換出力(/build/diagrams/<name>.svg)へ
-- パスを書き換える。執筆者が中間生成物のパスを知る必要をなくすための橋渡し
-- であり、SVG の生成自体は scripts/puml2svg.sh(Makefile から実行)が担う。
-- =============================================================================

function Image(img)
	local name = img.src:match("^/assets/diagrams/(.+)%.puml$")
	if name then
		img.src = "/build/diagrams/" .. name .. ".svg"
	end
	return img
end
