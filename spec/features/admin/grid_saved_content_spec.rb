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
