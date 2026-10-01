# frozen_string_literal: true

# The specs read what the grid exported from a record of their own, not from the post's textarea:
# the text editor writes there too, in its own serialization and at moments of its own. This is
# the record held to that, with the text editor made to write right after the grid.
RSpec.describe 'the record of what the grid exports', :js do
  init_site

  def post_textarea
    page.evaluate_script("jQuery('.panel_grid_editor').next('textarea').val()")
  end

  # What core does when the text editor loses focus, two seconds after the form opened and with
  # every draft: the text editor's content goes into its textarea.
  def let_the_text_editor_write
    page.execute_script("jQuery.each(tinymce.editors, function(_index, editor){ editor.fire('blur'); });")
  end

  before do
    block = grid_block_markup('<p><b>kept</b></p><script>window.__cama_widget_loaded = true;</script>',
                              kind: 'editor')
    grid = grid_body_markup(grid_column_markup(block), attributes: 'style="background-color: rgb(255, 204, 0);"')
    store_post_content(@post, grid_post_content(grid))
    open_post_in_editor(@post)
    find('.panel_grid_editor .panel_grid_body .drg_item')
  end

  it 'holds nothing until the grid exports' do
    expect(saved_grid_content).to be_nil
  end

  it 'holds the export, whatever the text editor writes over it in the textarea' do
    trigger_grid_auto_save
    let_the_text_editor_write

    expect(post_textarea).to include('background-color: #ffcc00', '<strong>kept</strong>')
    expect(saved_grid_content).to include('background-color: rgb(255, 204, 0)', '<b>kept</b>',
                                          '<script>window.__cama_widget_loaded = true;</script>')
  end

  # A rebuild that fails never puts its editor in the page: an export made on the way has to show
  # in the record all the same, or the examples that expect none could not fail.
  it 'holds an export made while the editor is not in the page' do
    page.execute_script("jQuery('.panel_grid_editor').detach().trigger('auto_save');")

    expect(saved_grid_content).to include('<b>kept</b>')
  end

  # A block form loads a text editor of its own through jQuery's tinymce(), and from then on
  # val() hands a value to the text editor of a field that has one and leaves the field alone: the
  # grid's write no longer reaches the post's textarea, and the record cannot be read off it.
  it 'holds the export once a block form has loaded a text editor of its own' do
    page.execute_script(<<~JS)
      jQuery('<textarea></textarea>').appendTo('#form-post').tinymce(cama_get_tinymce_settings({height: '120px'}));
      jQuery('.panel_grid_body .drg_item b').text('changed');
    JS
    trigger_grid_auto_save

    expect(saved_grid_content).to include('<b>changed</b>',
                                          '<script>window.__cama_widget_loaded = true;</script>')
  end
end
