# frozen_string_literal: true

RSpec.describe Plugins::CamaleonEditor::GridTemplate do
  init_site

  it 'stores grid templates on the grid_template term taxonomy' do
    template = @site.grid_templates.create!(name: 'Two columns', slug: 'two-cols', description: '<div>x</div>')

    expect(template.taxonomy).to eq('grid_template')
    expect(described_class.all).to include(template)
  end

  it 'wires the Site#grid_templates association added by config/custom_models.rb' do
    template = @site.grid_templates.create!(name: 'Hero', slug: 'hero', description: '<div>y</div>')

    expect(template.parent_id).to eq(@site.id)
    expect(@site.grid_templates.reload).to include(template)
  end

  it 'does not leak other term taxonomies into the default scope' do
    expect(described_class.all).not_to include(*CamaleonCms::TermTaxonomy.unscoped.where.not(taxonomy: 'grid_template'))
  end
end
