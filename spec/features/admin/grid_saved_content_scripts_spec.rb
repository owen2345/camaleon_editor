# frozen_string_literal: true

# Opening a post whose content is a grid rebuilds the grid editor from that content. An embed
# block's script is content for the public page; rebuilding the grid must keep it and not run it
# in the administrator's session.
RSpec.describe 'reopening a post whose grid holds a script', :js do
  init_site

  before do
    block = grid_block_markup('<p>embedded widget</p><script>window.__cama_widget_loaded = true;</script>',
                              kind: 'editor')
    grid = grid_body_markup(grid_column_markup(block), attributes: 'style="background-color: rgb(255, 204, 0);"')
    store_post_content(@post, grid_post_content(grid))
    open_post_in_editor(@post)
  end

  it 'rebuilds the grid with the script kept and not run' do
    expect(page).to have_css('.panel_grid_editor .panel_grid_body .drg_column .drg_item')

    trigger_grid_auto_save
    saved = saved_grid_content

    expect(saved).to include('<script>window.__cama_widget_loaded = true;</script>')
    expect(saved).to include('background-color: rgb(255, 204, 0)')
    expect(page.evaluate_script('window.__cama_widget_loaded')).to be_nil
  end
end
