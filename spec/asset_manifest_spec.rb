# frozen_string_literal: true

# The gem ships a Sprockets manifest (app/assets/config/camaleon_editor.js) that host apps link
# to get the plugin's assets into their precompile set. link_tree without an extension argument
# links no .css.scss files, so every stylesheet was missing from the set and the first page
# referencing one - the grid frontend's basic.css, via the [grid_editor] shortcode - raised
# AssetNotPrecompiledError in host apps. The admin JavaScript was linked all along, which is why
# the editor itself worked while the public rendering failed.
RSpec.describe 'the gem asset manifest' do # rubocop:disable RSpec/DescribeClass
  it 'links the stylesheet entry points alongside the javascripts' do
    linked = Rails.application.assets.find_all_linked_assets('camaleon_editor.js').map(&:logical_path)

    expect(linked).to include(
      'plugins/camaleon_editor/front/basic.css',
      'plugins/camaleon_editor/admin/grid-editor-manifest.css',
      'plugins/camaleon_editor/admin/editor-manifest.js'
    )
  end
end
