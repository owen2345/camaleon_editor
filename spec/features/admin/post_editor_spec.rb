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
  # brings the editor's script along) evaluates the script again, while jQuery, the lists of hooks
  # the script adds to and what other scripts registered with the editor are the page's and stay.
  # The script does its work once: a text editor set up afterwards has one Grid Editor button, and
  # a block kind another script registered is still there.
  it 'does its work once, however often its script is evaluated' do
    install_plugin_and_open_post_editor

    evaluated_again, hooks_before, hooks_after, kind_kept = page.evaluate_script(<<~JS)
      (function(){
        var hooks = function(){
          return jQuery.map(['init', 'settings', 'setups', 'custom_toolbar'], function(list){
            return tinymce_global_settings[list].length;
          });
        };
        var before = hooks(), tabs_builder = window.grid_tab_builder;
        jQuery.fn.gridEditor_options.faq = {title: 'FAQ', callback: function(){}};
        jQuery.ajax({url: jQuery('script[src*="editor-manifest"]').attr('src'), dataType: 'script', async: false});
        jQuery('<textarea id="later_editor"></textarea>').appendTo('body');
        tinymce.init(cama_get_tinymce_settings({selector: '#later_editor'}));
        return [window.grid_tab_builder !== tabs_builder, before, hooks(), 'faq' in jQuery.fn.gridEditor_options];
      })()
    JS
    wait_for_text_editor("tinymce.get('later_editor')")
    buttons = page.evaluate_script(<<~JS)
      jQuery(tinymce.get('later_editor').editorContainer).find('.mce-btn').filter(function(){
        return jQuery(this).text() === 'Grid Editor';
      }).length
    JS

    expect(evaluated_again).to be(true)
    expect(hooks_after).to eq(hooks_before)
    expect(buttons).to eq(1)
    expect(kind_kept).to be(true)
  end
end
