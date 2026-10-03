# frozen_string_literal: true

# The specs read the grid export from their own record, not from the post's field: a text editor
# that the author went back to writes its own serialization there. These examples test that record.
# They also test it after a block form loads a text editor, when jQuery's val() does not read or
# write the field.
RSpec.describe 'the record of what the grid exports', :js do
  init_site

  before do
    grid = grid_with_block('<p><b>kept</b></p><script>window.__cama_widget_loaded = true;</script>',
                           kind: 'editor', attributes: 'style="background-color: rgb(255, 204, 0);"')
    store_post_content(@post, grid_post_content(grid))
    open_post_in_editor(@post)
    # Wait for the stored grid: with no grid, an empty record proves nothing.
    find('.panel_grid_editor .panel_grid_body .drg_item')
  end

  it 'holds nothing until the grid exports' do
    expect(saved_grid_content).to be_nil
  end

  it 'holds the export, whatever the text editor the author went back to writes in the textarea' do
    trigger_grid_auto_save
    leave_for_the_text_editor

    expect(grid_field).to include('background-color: #ffcc00', '<strong>kept</strong>')
    expect(saved_grid_content).to include('background-color: rgb(255, 204, 0)', '<b>kept</b>',
                                          '<script>window.__cama_widget_loaded = true;</script>')
  end

  # Core can trigger change_in on a field of its own. The draft save of core master does this for an
  # empty summary, when the last content that an editor got was empty. The record stores the content
  # that a text editor got only when the field of that editor triggers change_in.
  it 'holds the export when a field of no editor says it changed' do
    trigger_grid_auto_save
    text_editor_holds('')
    page.execute_script("jQuery('<textarea>').appendTo('body').trigger('change_in');")

    expect(saved_grid_content).to include('<b>kept</b>')
  end

  # A rebuild that fails never puts its editor in the page: an export made on the way has to show
  # in the record all the same, or the examples that expect none could not fail.
  it 'holds an export made while the editor is not in the page' do
    page.execute_script("jQuery('.panel_grid_editor').detach().trigger('auto_save');")

    expect(saved_grid_content).to include('<b>kept</b>')
  end

  # A block form loads its own text editor through jQuery's tinymce(). After that, val() gives a
  # value to the text editor of a field and does not change the field. The grid editor still gives
  # its export to the text editor first, and the record keeps that content.
  it 'holds the export once a block form has loaded a text editor of its own' do
    load_a_block_form_text_editor
    change_the_grid

    expect(saved_grid_content).to include('<b>changed</b>',
                                          '<script>window.__cama_widget_loaded = true;</script>')
  end
end
