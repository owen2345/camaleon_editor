# frozen_string_literal: true

# Reopening the per-block Style Settings must not crash. A block saved by an older build (or any
# block whose stored style holds a value the colorpicker can't parse as a colour) put a non-colour
# value on the border colour field; initialising the colorpicker on it threw
# `val.toLowerCase is not a function`, which aborted the modal callback so the panel never appeared.
# The recovery now initialises each colorpicker independently and tolerates an unparseable colour.
RSpec.describe 'reopening the grid block style panel', :js do
  init_site

  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    admin_sign_in
    post_type = CamaleonCms::Site.first.post_types.first
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/new"
  end

  # Build a synthetic block carrying the given stored style and open its Style Settings panel.
  # The block lives on window so later execute_script calls (e.g. after a save) can re-read its
  # attributes; Capybara resets the page between examples, so the global cannot leak.
  def open_style_panel(style)
    page.execute_script(<<~JS)
      window.__cama_style_block = jQuery('<div class="btn"></div>').attr('data-style', #{style.to_json.to_json});
      grid_style_setting(window.__cama_style_block, jQuery('<div></div>'));
    JS
  end

  def all_colorpickers_initialised
    page.evaluate_script(<<~JS)
      jQuery('#cama_editor_modal2 .panel_color').toArray().every(function(el){
        return !!jQuery(el).data('colorpicker');
      })
    JS
  end

  it 'initialises every colorpicker even when stored colours are not colour strings' do
    # jQuery coerces numeric-looking data-attributes to Numbers when the widget reads them back,
    # and the colorpicker's colour parser only takes strings.
    open_style_panel('b-c' => '2', 't-c' => '0')

    expect(page).to have_css('#cama_editor_modal2 .panel_color', count: 3)
    expect(all_colorpickers_initialised).to be(true)
  end

  it 'opens the style panel even when a stored style holds a non-colour border value' do
    # A block as the buggy build saved it: the border colour slot carries a width number ("2").
    page.execute_script(<<~JS)
      window.__blk = jQuery('<div class="btn" data-style=\\'{"b-c":"#ffcc00","bo-c":"2","bo-w":"2"}\\'></div>').appendTo('body');
      grid_style_setting(window.__blk, jQuery('<div></div>'), window.__blk);
    JS

    # The ajax modal must load and become visible (its style form fields are present), rather than
    # being aborted by a colorpicker exception. have_css polls, so it waits for the ajax content.
    expect(page).to have_css("#cama_editor_modal2 input[name='bo-w']", visible: :visible, wait: 10)
    expect(page).to have_css("#cama_editor_modal2 input[name='b-c']", visible: :visible)
  end
end
