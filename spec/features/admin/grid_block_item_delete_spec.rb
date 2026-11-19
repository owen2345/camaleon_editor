# frozen_string_literal: true

# The form of a tabs, slider or accordion block lists the items of the block: its tabs, slides or
# panels. A deleted item fades out, and its row stays in the list until the fade ends. A click on
# Save during the fade builds the block without the deleted item.
RSpec.describe 'deleting an item in a grid block form', :js do
  init_site

  # An image that needs no request: the dummy app raises an error in the example for a missing file.
  let(:image) { 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==' }
  let(:tabs) do
    <<~HTML.delete("\n")
      <ul class="nav nav-tabs" role="tablist">
      <li role="presentation" class="active"><a href="#t0" role="tab" data-toggle="tab">Deleted tab</a></li>
      <li role="presentation" class=""><a href="#t1" role="tab" data-toggle="tab">Kept tab</a></li></ul>
      <div class="tab-content"> <div role="tabpanel" class="tab-pane active" id="t0">Deleted pane</div>
      <div role="tabpanel" class="tab-pane " id="t1">Kept pane</div> </div>
    HTML
  end
  let(:slider) do
    <<~HTML.delete("\n")
      <ol class="carousel-indicators"><li data-target="#s1" data-slide-to="0" class="active"></li>
      <li data-target="#s1" data-slide-to="1" class=""></li></ol>
      <div class="carousel-inner" role="listbox"> <div class="item active"><img src="#{image}" alt="">
      <div class="carousel-caption">Deleted caption</div></div>
      <div class="item "><img src="#{image}" alt=""><div class="carousel-caption">Kept caption</div></div> </div>
    HTML
  end
  let(:accordion) do
    accordion_panel('a0', 'Deleted panel', 'Deleted body') + accordion_panel('a1', 'Kept panel', 'Kept body')
  end

  def accordion_panel(id, title, body)
    <<~HTML.delete("\n")
      <div class="panel panel-default"><div class="panel-heading" role="tab"><h4 class="panel-title">
      <a role="button" data-toggle="collapse" href="##{id}" class="collapsed">#{title}</a></h4></div>
      <div class="panel-collapse collapse" id="#{id}" role="tabpanel"><div class="panel-body">#{body}</div></div></div>
    HTML
  end

  # Deletes the first of the two listed items and clicks Save in the same script. The fade of the
  # deleted row did not start yet, so the row is still in the list at the click on Save.
  def delete_the_first_item_and_save
    expect(page).to have_css('#ow_inline_modal tbody tr', count: 2)
    confirm_every_prompt
    rows_at_save = page.evaluate_script(<<~JS)
      (function(){
        jQuery('#ow_inline_modal tbody tr').first().find('a.del_item').click();
        var rows = jQuery('#ow_inline_modal tbody tr').length;
        jQuery('#ow_inline_modal .modal_submit').click();
        return rows;
      })()
    JS
    expect(rows_at_save).to eq(2)
    expect(page).to have_no_css('#ow_inline_modal')
  end

  it 'exports a tabs block without a tab deleted just before Save' do
    open_block_form(tabs, kind: 'tab')
    delete_the_first_item_and_save

    expect(saved_grid_content).to include('Kept tab', 'Kept pane')
    expect(saved_grid_content).not_to include('Deleted')
    expect(saved_grid_content.scan('role="presentation"').size).to eq(1)
  end

  it 'exports a slider block without a slide deleted just before Save' do
    open_block_form(slider, kind: 'slider')
    delete_the_first_item_and_save

    expect(saved_grid_content).to include('Kept caption')
    expect(saved_grid_content).not_to include('Deleted')
    expect(saved_grid_content.scan('class="carousel-caption"').size).to eq(1)
  end

  it 'exports an accordion block without a panel deleted just before Save' do
    open_block_form(accordion, kind: 'accordion')
    delete_the_first_item_and_save

    expect(saved_grid_content).to include('Kept panel', 'Kept body')
    expect(saved_grid_content).not_to include('Deleted')
    expect(saved_grid_content.scan('class="panel-body"').size).to eq(1)
  end
end
