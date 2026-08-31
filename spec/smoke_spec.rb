# frozen_string_literal: true

# End-to-end smoke test: boots a camaleon_cms-backed dummy app with this plugin loaded (the test env
# eager-loads, so a plugin class referencing a missing constant fails the whole boot) and asserts the
# camaleon_editor plugin is wired up -- discovered by the CMS as a gem-mode plugin, its hook methods
# defined on the helper camaleon_plugin.json names, and its admin routes drawn.
RSpec.describe 'camaleon_editor plugin', type: :model do
  it 'loads the engine and top-level constant' do
    expect(defined?(CamaleonEditor)).to eq('constant')
    expect(CamaleonEditor::VERSION).to be_a(String)
    expect(CamaleonEditor::Engine.ancestors).to include(Rails::Engine)
  end

  it 'defines every hook method camaleon_plugin.json names on the plugin helper' do
    hook_methods = %i[camaleon_editor_on_active camaleon_editor_on_inactive camaleon_editor_on_upgrade
                      camaleon_editor_admin camaleon_editor_post_form camaleon_editor_front]
    expect(Plugins::CamaleonEditor::MainHelper.instance_methods).to include(*hook_methods)
  end

  it 'is discovered by Camaleon as a gem-mode plugin' do
    info = PluginRoutes.plugin_info('camaleon_editor')
    expect(info).to be_present
    expect(info['key']).to eq('camaleon_editor')
    expect(info['gem_mode']).to be(true)
  end

  it 'ships its grid-template model on Camaleon term taxonomies' do
    expect(Plugins::CamaleonEditor::GridTemplate.ancestors).to include(CamaleonCms::TermTaxonomy)
  end

  it 'draws its admin routes on the host application' do
    expect(Rails.application.routes.url_helpers)
      .to respond_to(:admin_plugins_camaleon_editor_grid_editor_index_path)
  end
end
