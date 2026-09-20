# frozen_string_literal: true

# End-to-end: with the plugin active, opening the admin post editor loads the grid-editor assets and
# grid-editor.js registers its "Grid Editor" toolbar button on Camaleon's TinyMCE editor.
RSpec.describe 'the grid editor in the admin post editor', :js do
  init_site

  it 'loads the editor assets and offers the Grid Editor toolbar button' do
    install_plugin_and_open_post_editor

    expect(page).to have_css('script[src*="editor-manifest"]', visible: :all)
    expect(page).to have_css('.mce-btn', text: 'Grid Editor')
  end
end
