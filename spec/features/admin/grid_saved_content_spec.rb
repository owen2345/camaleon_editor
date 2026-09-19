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
end
