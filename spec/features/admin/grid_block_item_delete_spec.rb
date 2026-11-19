# frozen_string_literal: true

# The form of a tabs, slider, accordion or gallery block lists the items of the block: its tabs,
# slides, panels or media. A deleted item fades out, and its row stays in the list until the fade
# ends. A click on Save during the fade builds the block without the deleted item.
RSpec.describe 'deleting an item in a grid block form', :js do
  init_site

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
      <div class="carousel-inner" role="listbox"> <div class="item active"><img src="#{ONE_PIXEL_IMAGE}" alt="">
      <div class="carousel-caption">Deleted caption</div></div>
      <div class="item "><img src="#{ONE_PIXEL_IMAGE}" alt=""><div class="carousel-caption">Kept caption</div></div> </div>
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
  # deleted row starts at the click on Delete but does not end in the script. Thus the row is still in
  # the list at the click on Save. While the row fades out, it gets no mouse clicks, and its Edit
  # link cannot get the keyboard focus.
  def delete_the_first_item_and_save
    expect(page).to have_css('#ow_inline_modal tbody tr', count: 2)
    confirm_every_prompt
    row_state_at_save = page.evaluate_script(<<~JS)
      (function(){
        var deleted_row = jQuery('#ow_inline_modal tbody tr').first();
        deleted_row.find('a.del_item').click();
        var rows = jQuery('#ow_inline_modal tbody tr').length;
        var pointer_events = deleted_row.css('pointer-events');
        var edit_link = deleted_row.find('a.edit_item')[0];
        edit_link.focus();
        var edit_link_focused = document.activeElement === edit_link;
        jQuery('#ow_inline_modal .modal_submit').click();
        return [rows, pointer_events, edit_link_focused];
      })()
    JS
    expect(row_state_at_save).to eq([2, 'none', false])
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

  # No block kind on offer opens the gallery form, but a host can register the gallery kind.
  it 'exports a gallery block without an item deleted just before Save' do
    items = %w[Deleted Kept].map do |title|
      %(<div class="gallery-item" data-url="#{ONE_PIXEL_IMAGE}"><div class="g-title">#{title} item</div></div>)
    end
    store_post_content(@post, grid_post_content(grid_with_block(items.join, kind: 'gallery')))
    open_post_in_editor(@post)
    page.execute_script("jQuery.fn.gridEditor_options.gallery = {title: 'Gallery', callback: grid_gallery_builder};")
    open_first_block_form
    delete_the_first_item_and_save

    expect(saved_grid_content).to include('Kept item')
    expect(saved_grid_content).not_to include('Deleted')
    expect(saved_grid_content.scan('class="gallery-item"').size).to eq(1)
  end
end
