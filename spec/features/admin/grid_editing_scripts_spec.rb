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

  # The Gallery block is not on offer, but its builder ships and a host can register it. It reads an
  # item's url back from an attribute, decoded, and writes it into quoted attributes again.
  it 'keeps a gallery url inside its attribute' do
    url = %(x' onerror='window["__cama_script_ran"]=true' data-x='.png)
    item = %(<div class="gallery-item" data-url="#{CGI.escapeHTML(url)}"><div class="g-title">One</div></div>)
    store_post_content(@post, grid_post_content(grid_with_block(item, kind: 'gallery')))
    open_post_in_editor(@post)
    find('.panel_grid_body .drg_item') # the grid is rebuilt

    page.execute_script(<<~JS)
      jQuery.fn.gridEditor_options.gallery = {title: 'Gallery', callback: grid_gallery_builder};
      jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();
    JS
    find('#ow_inline_modal .modal_submit').click

    expect(page).to have_no_css('#ow_inline_modal')
    expect(page).to have_css('.panel_grid_body .gallery-item img', visible: :all)
    expect(page).to have_no_css('.panel_grid_body .gallery-item img[onerror]', visible: :all)
    expect(script_ran).to be_nil
  end

  # html() parsed a table row or a cell as one wherever it went; set as innerHTML of a div, the same
  # markup loses its row and cells and keeps only their text.
  it 'keeps table rows written into a text block' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>widget</p>')))
    open_post_in_editor(@post)
    find('.panel_grid_body .drg_item') # the grid is rebuilt

    page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
    find('#ow_inline_modal textarea').set('<tr><td>Q1</td><td>120</td></tr>')
    find('#ow_inline_modal .modal_submit').click

    expect(page).to have_no_css('#ow_inline_modal')
    expect(saved_grid_content).to include('<tr><td>Q1</td><td>120</td></tr>')
  end

  # The Tabs and Accordion forms list the block's items by label, read back from the stored block. A
  # label is markup its author wrote: the form shows its source as text, where nothing runs, and
  # writes it back as it was, so the saved block - and the public page - keep it unchanged.
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

    it 'reads an empty tab label as empty, not as the markup around it' do
      store_post_content(@post, grid_post_content(grid_with_block(blocks['tab'].sub(payload, ''), kind: 'tab')))
      open_post_in_editor(@post)
      find('.panel_grid_body .drg_item') # the grid is rebuilt

      page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
      expect(page).to have_css('#ow_inline_modal td.name', exact_text: '')
      find('#ow_inline_modal .modal_submit').click

      expect(page).to have_no_css('#ow_inline_modal')
      expect(page).to have_no_css('.panel_grid_body .nav-tabs a a', visible: :all)
    end

    # A label of plain text is listed as the text it is, and saved as it was.
    %w[tab accordion].each do |kind|
      it "lists a plain #{kind} label as its text, ampersand and all" do
        block = blocks[kind].sub(payload, 'Q &amp; A')
        store_post_content(@post, grid_post_content(grid_with_block(block, kind: kind)))
        open_post_in_editor(@post)
        find('.panel_grid_body .drg_item') # the grid is rebuilt

        page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")

        expect(page).to have_css('#ow_inline_modal td.name', exact_text: 'Q & A')
        find('#ow_inline_modal .modal_submit').click
        expect(page).to have_no_css('#ow_inline_modal')
        expect(saved_grid_content).to include('Q &amp; A')
        expect(saved_grid_content).not_to include('&amp;amp;')
      end

      # Text that spells a character reference is source as well: read as its text and written back as
      # that text reads, "&amp;amp;" would lose a level of escaping at every save of the block, and the
      # public page would show another label each time.
      it "saves a #{kind} label whose text spells a character reference as it was stored" do
        block = blocks[kind].sub(payload, 'Use &amp;amp; here')
        store_post_content(@post, grid_post_content(grid_with_block(block, kind: kind)))
        open_post_in_editor(@post)
        find('.panel_grid_body .drg_item') # the grid is rebuilt

        page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")

        expect(page).to have_css('#ow_inline_modal td.name', exact_text: 'Use &amp;amp; here')
        find('#ow_inline_modal .modal_submit').click
        expect(page).to have_no_css('#ow_inline_modal')
        expect(saved_grid_content).to include('Use &amp;amp; here')
      end
    end

    # A "<" that opens no tag of the label's own is text the author typed. Written as it is, "x<y"
    # would open a tag that runs on over the markup of the block behind it, and the next edit would
    # find one tab where there were two.
    it 'writes a typed label with a stray "<" as text, and lists it as it was typed' do
      second = '<li role="presentation"><a href="#t1" role="tab" data-toggle="tab">Two</a></li>'
      two_tabs = blocks['tab'].sub(payload, 'One').sub('</li></ul>', "</li>#{second}</ul>")
      store_post_content(@post, grid_post_content(grid_with_block(two_tabs, kind: 'tab')))
      open_post_in_editor(@post)
      find('.panel_grid_body .drg_item') # the grid is rebuilt

      page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
      first('#ow_inline_modal a.edit_item').click
      find('#cama_editor_modal2 input.name').set('x<y')
      find('#cama_editor_modal2 .modal_submit').click
      expect(page).to have_no_css('#cama_editor_modal2')
      find('#ow_inline_modal .modal_submit').click
      expect(page).to have_no_css('#ow_inline_modal', visible: :all) # gone, not just hidden: it is opened again

      expect(saved_grid_content).to include('data-toggle="tab">x&lt;y</a>')
      expect(page).to have_css('.panel_grid_body .nav-tabs > li', count: 2, visible: :all)

      page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
      expect(page).to have_css('#ow_inline_modal td.name', exact_text: 'x<y')
    end

    it 'lists a label with a "<" that opens no tag as its text' do
      block = blocks['tab'].sub(payload, 'a &lt; b')
      store_post_content(@post, grid_post_content(grid_with_block(block, kind: 'tab')))
      open_post_in_editor(@post)
      find('.panel_grid_body .drg_item') # the grid is rebuilt

      page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")

      expect(page).to have_css('#ow_inline_modal td.name', exact_text: 'a < b')
      find('#ow_inline_modal .modal_submit').click
      expect(page).to have_no_css('#ow_inline_modal')
      expect(saved_grid_content).to include('data-toggle="tab">a &lt; b</a>')
    end

    it 'keeps the markup of a label through an edit' do
      store_post_content(@post, grid_post_content(grid_with_block(blocks['tab'], kind: 'tab')))
      @post.reload.update_column(:content, @post.content.sub(payload, '<b>Bold</b> tab')) # rubocop:disable Rails/SkipsModelValidations
      open_post_in_editor(@post)
      find('.panel_grid_body .drg_item') # the grid is rebuilt

      page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")

      expect(page).to have_css('#ow_inline_modal td.name', text: '<b>Bold</b> tab')
      expect(page).to have_no_css('#ow_inline_modal td.name b')
      find('#ow_inline_modal .modal_submit').click
      expect(page).to have_no_css('#ow_inline_modal')
      expect(saved_grid_content).to include('data-toggle="tab"><b>Bold</b> tab')
    end

    %w[tab accordion].each do |kind|
      it "lists a #{kind} label's source as text and saves it back unchanged" do
        store_post_content(@post, grid_post_content(grid_with_block(blocks[kind], kind: kind)))
        open_post_in_editor(@post)
        find('.panel_grid_body .drg_item') # the grid is rebuilt

        page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")

        expect(page).to have_css('#ow_inline_modal td.name', text: '&lt;img src=x onerror=')
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
