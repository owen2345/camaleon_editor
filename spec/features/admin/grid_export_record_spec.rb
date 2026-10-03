# frozen_string_literal: true

# The specs read what the grid exported from a record of their own, not from the post's textarea:
# a text editor the author went back to writes there in its own serialization. This is the record
# held to that, and to the grid's export once a block form has loaded a text editor, from which
# jQuery's val() no longer reads or writes the field.
RSpec.describe 'the record of what the grid exports', :js do
  init_site

  before do
    grid = grid_with_block('<p><b>kept</b></p><script>window.__cama_widget_loaded = true;</script>',
                           kind: 'editor', attributes: 'style="background-color: rgb(255, 204, 0);"')
    store_post_content(@post, grid_post_content(grid))
    open_post_in_editor(@post)
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

  # A rebuild that fails never puts its editor in the page: an export made on the way has to show
  # in the record all the same, or the examples that expect none could not fail.
  it 'holds an export made while the editor is not in the page' do
    page.execute_script("jQuery('.panel_grid_editor').detach().trigger('auto_save');")

    expect(saved_grid_content).to include('<b>kept</b>')
  end

  # A block form loads a text editor of its own through jQuery's tinymce(), and from then on
  # val() hands a value to the text editor of a field that has one and leaves the field alone.
  # The grid still hands its export to the text editor first, which is what the record holds.
  it 'holds the export once a block form has loaded a text editor of its own' do
    load_a_block_form_text_editor
    page.execute_script("jQuery('.panel_grid_body .drg_item b').text('changed');")
    trigger_grid_auto_save

    expect(saved_grid_content).to include('<b>changed</b>',
                                          '<script>window.__cama_widget_loaded = true;</script>')
  end
end
