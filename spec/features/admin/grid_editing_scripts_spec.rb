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

  it 'does not run a block script when the block is edited and saved' do
    store_post_content(@post, grid_post_content(grid_with_block("<p>widget</p>#{script}")))
    open_post_in_editor(@post)
    find('.panel_grid_body .drg_item') # the grid is rebuilt

    page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
    find('#ow_inline_modal .modal_submit').click

    expect(page).to have_no_css('#ow_inline_modal')
    expect(saved_grid_content).to include(script)
    expect(script_ran).to be_nil
  end

  # The Tabs, Accordion and Slider forms list the block's items by label (or image url), read back
  # from the stored block. A label is text: shown as markup, an escaped payload would run here, in
  # the session of whoever edits the block, after passing every gate as the harmless text it is.
  context 'when a block lists its items by a label read from stored content' do
    let(:payload) { '&lt;img src=x onerror="window.__cama_script_ran = true"&gt;Label' }
    let(:blocks) do
      {
        'tab' => <<~HTML.delete("\n"),
          <ul class="nav nav-tabs" role="tablist"><li role="presentation" class="active">
          <a href="#t0" role="tab" data-toggle="tab">#{payload}</a></li></ul>
          <div class="tab-content"> <div role="tabpanel" class="tab-pane active" id="t0">body</div> </div>
        HTML
        'accordion' => <<~HTML.delete("\n")
          <div class="panel panel-default"><div class="panel-heading" role="tab"><h4 class="panel-title">
          <a role="button" data-toggle="collapse" href="#a0">#{payload}</a></h4></div>
          <div class="panel-collapse collapse" id="a0"><div class="panel-body">body</div></div></div>
        HTML
      }
    end

    %w[tab accordion].each do |kind|
      it "lists a #{kind} label as text and saves it back as text" do
        store_post_content(@post, grid_post_content(grid_with_block(blocks[kind], kind: kind)))
        open_post_in_editor(@post)
        find('.panel_grid_body .drg_item') # the grid is rebuilt

        page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")

        expect(page).to have_css('#ow_inline_modal td.name', text: '<img src=x onerror=')
        expect(page).to have_no_css('#ow_inline_modal td.name img')
        find('#ow_inline_modal .modal_submit').click
        expect(page).to have_no_css('#ow_inline_modal')
        expect(saved_grid_content).to include('&lt;img src=x onerror=')
        expect(saved_grid_content).not_to include('<img src=x')
        expect(script_ran).to be_nil
      end
    end
  end
end
