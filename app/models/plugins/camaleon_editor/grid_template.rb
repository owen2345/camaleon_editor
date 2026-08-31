# frozen_string_literal: true

# A named, reusable grid-editor layout stored as a term taxonomy of the site: name is the title,
# description holds the grid content, slug is the template key.
class Plugins::CamaleonEditor::GridTemplate < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :grid_template) }
end
