# frozen_string_literal: true

# End-to-end: with the plugin active, opening the admin post editor loads the grid-editor assets and
# grid-editor.js registers its "Grid Editor" toolbar button on Camaleon's TinyMCE editor.
RSpec.describe 'the grid editor in the admin post editor', :js do
  init_site

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
  end

  it 'loads the editor assets and offers the Grid Editor toolbar button' do
    admin_sign_in
    post_type = CamaleonCms::Site.first.post_types.first

    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/new"

    expect(page).to have_css('script[src*="editor-manifest"]', visible: :all)
    expect(page).to have_css('.mce-btn', text: 'Grid Editor')
  end
end
