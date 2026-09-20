# frozen_string_literal: true

# A Slider block lists its slides from the stored block: each slide's image, and the caption that
# goes with it. A caption read from anywhere but its own slide would be lost at the next save.
RSpec.describe 'editing a slider block', :js do
  init_site

  # an image that needs no request: the dummy app raises a missing file into the example
  let(:image) { 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==' }
  let(:slider) do
    <<~HTML.delete("\n")
      <ol class="carousel-indicators"><li data-target="#s1" data-slide-to="0" class="active"></li>
      <li data-target="#s1" data-slide-to="1" class=""></li></ol>
      <div class="carousel-inner" role="listbox"> <div class="item active"><img src="#{image}" alt="">
      <div class="carousel-caption">First <b>caption</b></div></div>
      <div class="item "><img src="#{image}" alt=""><div class="carousel-caption">Second caption</div></div> </div>
    HTML
  end

  it 'keeps each slide with its own caption through an edit' do
    store_post_content(@post, grid_post_content(grid_with_block(slider, kind: 'slider')))
    open_post_in_editor(@post)
    find('.panel_grid_body .drg_item') # the grid is rebuilt

    page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
    expect(page).to have_css('#ow_inline_modal td.name', count: 2)
    find('#ow_inline_modal .modal_submit').click

    expect(page).to have_no_css('#ow_inline_modal')
    expect(saved_grid_content).to include('<div class="carousel-caption">First <b>caption</b></div>',
                                          '<div class="carousel-caption">Second caption</div>')
  end
end
