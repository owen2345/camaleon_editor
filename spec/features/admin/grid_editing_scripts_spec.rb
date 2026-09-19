# frozen_string_literal: true

# A grid keeps the scripts of its embed blocks as content for the public page. Working on the grid
# in the admin - rebuilding its headers, dragging, editing a block - must never run them.
RSpec.describe 'working on a grid that holds scripts', :js do
  init_site

  def script_ran
    page.evaluate_script('window.__cama_script_ran')
  end

  let(:script) { '<script>window.__cama_script_ran = true;</script>' }

  it 'shows a column title as text, whatever it holds' do
    title = '&lt;script&gt;window.__cama_script_ran = true;&lt;/script&gt;Half'
    store_post_content(@post, grid_post_content(grid_body_markup(grid_column_markup(title: title))))
    open_post_in_editor(@post)

    expect(page).to have_css('.panel_grid_body .drg_column .header_box',
                             text: '<script>window.__cama_script_ran = true;</script>Half')
    expect(script_ran).to be_nil
  end

  it 'does not run a block script while the block is dragged' do
    store_post_content(@post, grid_post_content(grid_with_block("<p>widget</p>#{script}")))
    open_post_in_editor(@post)
    page.execute_script("jQuery(document).on('sortstart', function(){ window.__cama_sort_started = true; });")

    handle = first('.panel_grid_body .drg_item .header_box').native
    page.driver.browser.action.click_and_hold(handle).pause(duration: 0.4).move_by(0, 25).pause(duration: 0.2)
        .move_by(0, 25).pause(duration: 0.2).release.perform

    expect(page.evaluate_script('window.__cama_sort_started')).to be(true)
    expect(script_ran).to be_nil
  end
end
