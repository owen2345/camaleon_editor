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
    expect(text_editor_content).to eq(content)
  end

  # The author repairs such content in the text editor, and the button builds the grid from the
  # current content of the text editor. The field holds the last write of the editor (at a focus
  # loss or with a draft), which can still be the old content.
  it 'opens the grid from what the text editor holds once the content was mended there' do
    grid = grid_post_content(grid_with_block('<p>kept</p>'))
    store_post_content(@post, "#{grid}<p>written after the grid</p>")
    open_post_in_editor(@post)
    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    close_alert

    text_editor_holds(grid)
    open_grid_editor

    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_item', count: 1)
    expect(page).to have_no_css('body.modal-open')

    submit_post_form
    expect(post_content).to include('<p>kept</p>')
    expect(post_content).not_to include('written after the grid')
  end

  # In a post in more than one language, the field of a language is a copy. The post sends the
  # content that core composed when a copy last triggered a change. The button triggers that change.
  it 'has a post in several languages send the content mended in the text editor' do
    grid = grid_post_content(grid_with_block('<p>kept</p>'))
    @site.set_meta('languages_site', %w[en es])
    store_post_content(@post, { en: "#{grid}<p>written after the grid</p>", es: '<p>spanish</p>' }.to_translate)
    open_post_in_editor(@post)
    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    close_alert

    text_editor_holds(grid)
    open_grid_editor
    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_item', count: 1)

    expect(composed_content).to include('<p>kept</p>', '<p>spanish</p>')
    expect(composed_content).not_to include('written after the grid')
  end

  # A visit to the text editor with no changes there shows the same grid editor again, and does not
  # parse the content again. (With changes, the grid is built again: see grid_post_save_spec.)
  it 'shows the existing editor again without parsing the content a second time' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>kept</p>')))
    open_post_in_editor(@post)

    leave_for_the_text_editor
    page.execute_script(<<~JS)
      window.__cama_parses = 0;
      var parse = jQuery.parseHTML;
      jQuery.parseHTML = function(){ window.__cama_parses++; return parse.apply(this, arguments); };
    JS
    open_grid_editor

    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_item', count: 1)
    expect(page.evaluate_script('window.__cama_parses')).to eq(0)
  end

  # A column or block dropped from the palette is a copy of a palette entry, which has no menu. The
  # copy gets its menu one time, when the sort that puts it in the grid ends.
  it 'gives a column and a block dropped in from the palette their one menu, kept as they are sorted' do
    install_plugin_and_open_post_editor
    open_grid_editor
    expect(page).to have_css('.grid_editor_menu .drg_column, .grid_editor_menu .drg_item')
    expect(page).to have_no_css('.grid_editor_menu .header_box .dropdown', visible: :all)

    # Do what a drop does for each sortable: put a copy of the entry in it, then end the sort.
    page.execute_script("jQuery('.grid_editor_menu [data-col=\"6\"]').first().clone().appendTo(#{GRID_ROOT});")
    end_a_sort(GRID_ROOT, '.drg_column')
    page.execute_script("jQuery('.grid_editor_menu [data-kind=\"text\"]').first().clone()" \
                        ".appendTo(#{FIRST_COLUMN_AREA});")
    end_a_sort(FIRST_COLUMN_AREA, '.drg_item')
    end_a_sort(GRID_ROOT, '.drg_column')
    end_a_sort(FIRST_COLUMN_AREA, '.drg_item')

    expect(page).to have_css('.panel_grid_body .drg_column > .header_box .dropdown', count: 1, visible: :all)
    expect(page).to have_css('.panel_grid_body .drg_item > .header_box .dropdown', count: 1, visible: :all)
  end

  # The columns and blocks of a rebuilt grid already have a menu: a sort adds no second menu.
  it 'leaves a column and a block of a rebuilt grid their one menu when they are sorted' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>kept</p>')))
    open_post_in_editor(@post)

    # Run the sort-end handler of the grid sortables, for the column and for its block.
    end_a_sort(GRID_ROOT, '.drg_column')
    end_a_sort(FIRST_COLUMN_AREA, '.drg_item')

    expect(page).to have_css('.panel_grid_body .drg_column > .header_box .dropdown', count: 1, visible: :all)
    expect(page).to have_css('.panel_grid_body .drg_item > .header_box .dropdown', count: 1, visible: :all)
  end

  # The editor holds one grid: opening the first of several would drop the others at the next save.
  it 'keeps content holding several grids in the text editor' do
    content = grid_post_content(grid_body_markup + grid_body_markup(grid_column_markup(col: 12, title: '100%')))
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(text_editor_content).to eq(content)
  end

  it 'keeps content holding several grids inside a wrapper in the text editor' do
    grids = grid_body_markup + grid_body_markup(grid_column_markup(col: 12, title: '100%'))
    content = grid_post_content(%(<div class="panel_grid_body_w">#{grids}</div>))
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(text_editor_content).to eq(content)
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
    expect(text_editor_content).to eq(content)
  end

  # Beside the grid is beside it at any depth: inside a wrapper the grid has siblings too.
  it 'keeps content with markup beside a wrapped grid in the text editor' do
    content = grid_post_content(%(<div class="panel_grid_body_w">#{grid_body_markup}<p>after the grid</p></div>))
    store_post_content(@post, content)
    open_post_in_editor(@post)

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(text_editor_content).to eq(content)
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
    expect(text_editor_content).to eq(content)
  end

  # Reading the content is one thing, rebuilding the grid from it another: the column and block
  # parsers, and the widgets they set up, can throw on a grid they do not expect. By then the text
  # editor is hidden and the grid editor is not in the page yet.
  it 'keeps the content in the text editor when rebuilding the grid throws' do
    open_post_in_editor(@post)
    content = grid_post_content(grid_with_block('<p>kept</p>'))

    # the field and the text editor hold the same content, as they do when the page opens with it
    page.execute_script(<<~JS, content)
      jQuery.fn.sortable = function(){ throw new Error('widget broke'); };
      tinymce.activeEditor.setContent(arguments[0]);
      jQuery('#form-post textarea.tinymce_textarea').first().val(arguments[0]).gridEditor(tinymce.activeEditor);
    JS

    expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
    expect(page).to have_css('.mce-tinymce')
    expect(page).to have_no_css('.panel_grid_editor')
    expect(saved_grid_content).to be_nil
    expect(text_editor_content).to eq(content)
  end

  # The same goes for content that is no grid yet: when building the editor throws, the text editor
  # must not stay hidden behind an editor that never arrived.
  it 'brings the text editor back when building the editor over ordinary content throws' do
    open_post_in_editor(@post)
    page.execute_script("jQuery.fn.tooltip = function(){ throw new Error('widget broke'); };")

    open_grid_editor

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
    trigger_grid_auto_save

    expect(saved_grid_content).to include('id="landing"', 'data-theme="dark"')
    expect(saved_grid_content).to match(/class="[^"]*\bhero\b/)
  end

  # Called on several fields at once, jQuery's before() gave each its own editor; so does the editor.
  it 'builds an editor for each field of a set' do
    open_post_in_editor(@post)

    page.execute_script(<<~JS)
      jQuery('<div id="cama_two_fields"><textarea></textarea><textarea></textarea></div>').appendTo('#form-post');
      jQuery('#cama_two_fields textarea').gridEditor(tinymce.activeEditor);
    JS

    expect(page).to have_css('#cama_two_fields .panel_grid_editor + textarea', count: 2, visible: :all)
  end

  it 'does not give a saved grid root back a class it was saved without' do
    store_post_content(@post, grid_post_content(%(<div class="panel_grid_body hero">#{grid_column_markup}</div>)))
    open_post_in_editor(@post)
    trigger_grid_auto_save

    root_classes = saved_grid_content[/<div class="([^"]*panel_grid_body[^"]*)"/, 1].split
    expect(root_classes).to include('hero')
    expect(root_classes).not_to include('row')
  end

  # A host page can build its field first and attach it later; jQuery's before() quietly did
  # nothing for a detached field, and its native replacement must not throw instead.
  it 'does not break on a text field that is not in the page yet' do
    open_post_in_editor(@post)

    error = page.evaluate_script(<<~JS)
      (function(){
        try { jQuery('<textarea></textarea>').gridEditor(tinymce.activeEditor); return null; }
        catch(e){ return e.message; }
      })()
    JS

    expect(error).to be_nil
  end
end
