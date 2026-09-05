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
      jQuery('#cama_editor_style_modal .panel_color').toArray().every(function(el){
        return !!jQuery(el).data('colorpicker');
      })
    JS
  end

  it 'initialises every colorpicker even when stored colours are not colour strings' do
    # jQuery coerces numeric-looking data-attributes to Numbers when the widget reads them back,
    # and the colorpicker's colour parser only takes strings.
    open_style_panel('b-c' => '2', 't-c' => '0')

    expect(page).to have_css('#cama_editor_style_modal .panel_color', count: 3)
    expect(all_colorpickers_initialised).to be(true)
  end

  it 'opens its own modal even while an item-form modal holds the shared id' do
    # The tabs/slider/gallery/accordion item forms open a modal with id cama_editor_modal2. A
    # style panel opened from a grid nested inside one of them must not be swallowed by
    # open_modal's existing-id short-circuit, which re-shows the old modal with its old callbacks.
    page.execute_script(%(jQuery('<div id="cama_editor_modal2" class="modal"></div>').appendTo('body');))
    open_style_panel('b-c' => '#ffcc00')

    expect(page).to have_css("#cama_editor_style_modal input[name='bo-w']")
  end

  def capture_console_warnings
    page.execute_script(<<~JS)
      window.__cama_warns = [];
      var original = console.warn;
      console.warn = function(){ window.__cama_warns.push(String(arguments[0])); original.apply(console, arguments); };
    JS
  end

  it 'opens the panel and warns when a colorpicker cannot initialise at all' do
    # A broken widget (dropped asset, plugin name collision) must degrade one field, not the
    # whole panel - and must say so, not fail silently.
    capture_console_warnings
    page.execute_script("jQuery.fn.colorpicker = function(){ throw new Error('widget broken'); };")
    open_style_panel('b-c' => '#ffcc00')

    expect(page).to have_css("#cama_editor_style_modal input[name='bo-w']")
    expect(page.evaluate_script('window.__cama_warns.length')).to be > 0
  end

  it 'opens the panel and warns when the upload field initialiser is broken' do
    capture_console_warnings
    page.execute_script("jQuery.fn.input_upload_field = function(){ throw new Error('uploader broken'); };")
    open_style_panel('b-c' => '#ffcc00')

    expect(page).to have_css("#cama_editor_style_modal input[name='bo-w']")
    expect(page.evaluate_script('window.__cama_warns.length')).to be > 0
  end

  it 'opens the panel even when a stored style holds a key that is not a field name' do
    # Stored styles ride along in grid templates, so keys are data: a quote in a key must not
    # abort the recovery (jQuery throws on the malformed selector it would produce).
    open_style_panel("a']" => 'junk', 'b-c' => '#ffcc00')

    expect(page).to have_css("#cama_editor_style_modal input[name='b-c']")
    expect(page.find("#cama_editor_style_modal input[name='b-c']").value).to eq('#ffcc00')
  end

  it 'migrates a legacy width stored under the colour name and heals the block on save' do
    # A block as the buggy build saved it: both border inputs shared name="bo-c", so only the
    # width survived, filed under the colour key - a bo-w key could not exist yet.
    open_style_panel('b-c' => '#ffcc00', 'bo-c' => '2')

    expect(page).to have_css("#cama_editor_style_modal input[name='bo-w']")
    expect(page.find("#cama_editor_style_modal input[name='bo-w']").value).to eq('2')
    expect(page.find("#cama_editor_style_modal input[name='bo-c']").value).to eq('')

    page.find('#cama_editor_style_modal .modal_submit').click

    saved = JSON.parse(page.evaluate_script("window.__cama_style_block.attr('data-style')"))
    expect(saved).to include('bo-w' => '2', 'b-c' => '#ffcc00')
    expect(saved).not_to have_key('bo-c')
    expect(page.evaluate_script('window.__cama_style_block[0].style.borderTopWidth')).to eq('2px')
    expect(page.evaluate_script('window.__cama_style_block[0].style.borderTopStyle')).to eq('solid')
  end
end
