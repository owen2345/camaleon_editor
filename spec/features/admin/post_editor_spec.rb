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

  # A page loaded in place (the Admin AJAX plugin swaps the admin's content for a response that
  # brings the editor's script along) evaluates the script again, while the lists of hooks it adds
  # to are the page's and stay: the hooks are added once, and the toolbar offers one button.
  it 'adds its hooks once, however often its script is evaluated' do
    install_plugin_and_open_post_editor
    find('.mce-btn', text: 'Grid Editor')

    before, after, buttons = page.evaluate_script(<<~JS)
      (function(){
        var hooks = function(){
          return jQuery.map(['init', 'settings', 'setups', 'custom_toolbar'], function(list){
            return tinymce_global_settings[list].length;
          });
        };
        var before = hooks();
        jQuery.ajax({url: jQuery('script[src*="editor-manifest"]').attr('src'), dataType: 'script', async: false});
        return [before, hooks(), cama_get_tinymce_settings().toolbar.split('grid_editor').length - 1];
      })()
    JS

    expect(after).to eq(before)
    expect(buttons).to eq(1)
  end
end
