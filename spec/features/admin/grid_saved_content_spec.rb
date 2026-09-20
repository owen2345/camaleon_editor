# frozen_string_literal: true

# Opening a post whose content is a grid rebuilds the grid editor from that content. Whatever the
# content holds, the editor must either show it or leave it alone: an empty grid over content it
# could not read is one auto_save away from replacing that content.
RSpec.describe 'reopening a post whose content is a grid', :js do
  init_site

  # The marker in front of the grid ends in "]</div>", and so does any block whose text ends in a
  # bracket - a footnote, a shortcode. Only the marker may be taken off.
  it 'rebuilds a grid whose block text ends in a bracket' do
    store_post_content(@post, grid_post_content(grid_with_block('Steps: [done]')))
    open_post_in_editor(@post)

    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_column .drg_item')
    trigger_grid_auto_save
    expect(saved_grid_content).to include('Steps: [done]')
  end

  # Content carrying the grid marker that does not hold a grid (hand-edited, damaged, produced by
  # something else) must not be shown as an empty grid, whose first change would overwrite it.
  it 'keeps content it cannot read as a grid in the text editor, and says so' do
    content = grid_post_content('<p>legacy paragraph</p>')
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_css('.mce-tinymce')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea').val()")).to eq(content)
  end

  # Going to the text editor and back shows the editor built earlier: the content is not read again.
  it 'shows the existing editor again without reading the content a second time' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>kept</p>')))
    open_post_in_editor(@post)
    find('.panel_grid_editor .panel_grid_body .drg_item')

    accept_confirm { find('.grid_editor_menu .toggle_panel_grid').click }
    expect(page).to have_css('.mce-tinymce')
    page.execute_script(<<~JS)
      window.__cama_parses = 0;
      var parse = jQuery.parseHTML;
      jQuery.parseHTML = function(){ window.__cama_parses++; return parse.apply(this, arguments); };
    JS
    open_grid_editor

    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_item', count: 1)
    expect(page.evaluate_script('window.__cama_parses')).to eq(0)
  end

  # The editor holds one grid: opening the first of several would drop the others at the next save.
  it 'keeps content holding several grids in the text editor' do
    content = grid_post_content(grid_body_markup + grid_body_markup(grid_column_markup(col: 12, title: '100%')))
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea').val()")).to eq(content)
  end

  it 'keeps content holding several grids inside a wrapper in the text editor' do
    grids = grid_body_markup + grid_body_markup(grid_column_markup(col: 12, title: '100%'))
    content = grid_post_content(%(<div class="panel_grid_body_w">#{grids}</div>))
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea').val()")).to eq(content)
  end

  # Several grids are several grids side by side. Grid markup pasted into a block of the one grid is
  # that block's content, and goes where the block goes.
  it 'opens a wrapped grid whose block holds grid markup of its own' do
    pasted = '<div class="panel_grid_body">pasted</div>'
    store_post_content(@post, grid_post_content(%(<div class="panel_grid_body_w">#{grid_with_block(pasted)}</div>)))
    open_post_in_editor(@post)

    expect(page).to have_css('.panel_grid_editor .drg_item .panel_grid_body', text: 'pasted', visible: :all)
    expect(page).to have_no_css('#cama_alert_modal')
  end

  # The grid markup in a block is content, not a second grid of the editor's: it gets no column or
  # block chrome, which the export would not take off again, and is saved as it was stored.
  it 'saves grid markup held by a block as it was stored' do
    pasted = grid_with_block('pasted')
    store_post_content(@post, grid_post_content(grid_with_block(pasted)))
    open_post_in_editor(@post)

    expect(page).to have_css('.panel_grid_editor .drg_item .panel_grid_body', text: 'pasted', visible: :all)
    expect(page).to have_no_css('.panel_grid_editor .drg_item .panel_grid_body .header_box', visible: :all)
    expect(page).to have_no_css('.panel_grid_editor .drg_item .ui-sortable', visible: :all)
    trigger_grid_auto_save
    expect(saved_grid_content).to include(pasted)
  end

  # The export takes the editor's chrome off the grid's own columns and blocks. What a block holds may
  # carry the same names - a Bootstrap button, a header box of its own - and is not the editor's to strip.
  it 'leaves the classes and boxes of grid markup held by a block alone at export' do
    held = '<a class="btn btn-default" href="#"><span class="header_box">Buy</span> now</a>'
    pasted = grid_body_markup(grid_column_markup(held))
    store_post_content(@post, grid_post_content(grid_with_block(pasted)))
    open_post_in_editor(@post)

    expect(page).to have_css('.panel_grid_editor .drg_item .panel_grid_body', visible: :all)
    trigger_grid_auto_save
    expect(saved_grid_content).to include(pasted)
  end

  # The editor saves the grid and nothing else: content with more to it than the grid would lose the
  # rest at the first auto_save, so it is not opened as a grid.
  it 'keeps content with markup beside the grid in the text editor' do
    content = grid_post_content("#{grid_body_markup}<p>after the grid</p>")
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea').val()")).to eq(content)
  end

  # Beside the grid is beside it at any depth: inside a wrapper the grid has siblings too.
  it 'keeps content with markup beside a wrapped grid in the text editor' do
    content = grid_post_content(%(<div class="panel_grid_body_w">#{grid_body_markup}<p>after the grid</p></div>))
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea').val()")).to eq(content)
  end

  it 'opens a grid that has only what the text editor leaves around a block beside it' do
    leftovers = '<p>&nbsp;</p><br><p><br></p><div><span> </span></div>'
    store_post_content(@post, grid_post_content("\n#{grid_body_markup}\n#{leftovers}"))
    open_post_in_editor(@post)

    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_column')
    expect(page).to have_no_css('#cama_alert_modal')
  end

  # A marker without a libraries list is still a marker: left in front of the content, its div would
  # be taken for the grid, and the real content behind it dropped at the first auto_save.
  it 'does not take a bare marker for the grid' do
    content = '<div>[grid_editor]</div><div><p>legacy paragraph</p></div>'
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea').val()")).to eq(content)
  end

  # Reading the content is one thing, rebuilding the grid from it another: the column and block
  # parsers, and the widgets they set up, can throw on a grid they do not expect. By then the text
  # editor is hidden and the grid editor is not in the page yet.
  it 'keeps the content in the text editor when rebuilding the grid throws' do
    open_post_in_editor(@post)
    find('.mce-tinymce')
    content = grid_post_content(grid_with_block('<p>kept</p>'))

    page.execute_script(<<~JS, content)
      jQuery.fn.sortable = function(){ throw new Error('widget broke'); };
      jQuery('#form-post textarea.tinymce_textarea').first().val(arguments[0]).gridEditor(tinymce.activeEditor);
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_css('.mce-tinymce')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea').first().val()")).to eq(content)
  end

  # The same goes for content that is no grid yet: when building the editor throws, the text editor
  # must not stay hidden behind an editor that never arrived.
  it 'brings the text editor back when building the editor over ordinary content throws' do
    open_post_in_editor(@post)
    find('.mce-tinymce')
    page.execute_script("jQuery.fn.tooltip = function(){ throw new Error('widget broke'); };")

    accept_confirm { find('.mce-btn', text: 'Grid Editor').click }

    expect(page).to have_css('.mce-tinymce')
    expect(page).to have_no_css('.panel_grid_editor')
    # the author confirmed a switch that did not happen, and is told so
    expect(page).to have_css('#cama_alert_modal', text: 'The grid editor could not be opened')
  end

  # A theme hook or a hand edit can leave an id or a class of its own on the grid root; the public
  # page may style by them, so they have to survive the editor.
  it 'keeps the attributes the saved grid root carries' do
    body = %(<div class="panel_grid_body row hero" id="landing" data-theme="dark">#{grid_column_markup}</div>)
    store_post_content(@post, grid_post_content(body))
    open_post_in_editor(@post)
    find('.panel_grid_editor .panel_grid_body .drg_column')
    trigger_grid_auto_save

    expect(saved_grid_content).to include('id="landing"', 'data-theme="dark"')
    expect(saved_grid_content).to match(/class="[^"]*\bhero\b/)
  end

  # Called on several fields at once, jQuery's before() gave each its own editor; so does the editor.
  it 'builds an editor for each field of a set' do
    open_post_in_editor(@post)
    find('.mce-tinymce')

    page.execute_script(<<~JS)
      jQuery('<div id="cama_two_fields"><textarea></textarea><textarea></textarea></div>').appendTo('#form-post');
      jQuery('#cama_two_fields textarea').gridEditor(tinymce.activeEditor);
    JS

    expect(page).to have_css('#cama_two_fields .panel_grid_editor + textarea', count: 2, visible: :all)
  end

  it 'does not give a saved grid root back a class it was saved without' do
    store_post_content(@post, grid_post_content(%(<div class="panel_grid_body hero">#{grid_column_markup}</div>)))
    open_post_in_editor(@post)
    find('.panel_grid_editor .panel_grid_body .drg_column')
    trigger_grid_auto_save

    root_classes = saved_grid_content[/<div class="([^"]*panel_grid_body[^"]*)"/, 1].split
    expect(root_classes).to include('hero')
    expect(root_classes).not_to include('row')
  end

  # A host page can build its field first and attach it later; jQuery's before() quietly did
  # nothing for a detached field, and its native replacement must not throw instead.
  it 'does not break on a text field that is not in the page yet' do
    open_post_in_editor(@post)
    find('.mce-tinymce')

    error = page.evaluate_script(<<~JS)
      (function(){
        try { jQuery('<textarea></textarea>').gridEditor(tinymce.activeEditor); return null; }
        catch(e){ return e.message; }
      })()
    JS

    expect(error).to be_nil
  end
end
