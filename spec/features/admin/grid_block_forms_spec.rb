# frozen_string_literal: true

# The forms a grid's blocks are edited in are built by the block scripts. Their headings, labels,
# buttons and tooltips come from the locale file by way of core's I18n() script helper, like the
# editor's own (grid_editor_labels_spec): the English strings are the scripts' defaults as well, so
# only a translation shows that the page holds the strings of the locale file.
RSpec.describe 'the grid editor block forms', :js do
  init_site

  # The item list of a block opens the form of an item in a second modal. Capybara can find the link
  # while the list still slides into position. Wait first, or the click can miss the link.
  def add_block_item(label)
    wait_for_modal_at_rest('#ow_inline_modal')
    find('#ow_inline_modal a.add_item', text: label).click
  end

  context 'with an admin language the plugin ships a translation for' do
    before { @site.set_admin_language('es') }

    it 'heads and labels the form of a media block in that language' do
      open_block_form(kind: 'audio')

      within '#ow_inline_modal' do
        expect(page).to have_css('.modal-title', text: 'Formulario de audio')
        expect(page).to have_css('label', text: 'Archivo multimedia')
      end
    end

    it 'lists the tabs of a tabs block, and edits one, in that language' do
      open_block_form(kind: 'tab')

      within '#ow_inline_modal' do
        expect(page).to have_css('.modal-title', text: 'Panel de pestañas')
        expect(page).to have_css('th', text: 'Título')
      end

      add_block_item('Añadir elemento')
      within '#cama_editor_modal2' do
        expect(page).to have_css('.modal-title', text: 'Formulario de pestaña')
        expect(page).to have_css('label', text: 'Título')
        expect(page).to have_css('label', text: 'Contenido')
        # the new tab is named, for the author to rename
        expect(find('input.name').value).to eq('Título de ejemplo')
      end
      expect(page).to have_css('#ow_inline_modal a.edit_item[title="Editar"]', visible: :all)
      expect(page).to have_css('#ow_inline_modal a.del_item[title="Eliminar"]', visible: :all)
    end

    it 'edits a slide of a slider block in that language' do
      open_block_form(kind: 'slider')
      expect(page).to have_css('#ow_inline_modal .modal-title', text: 'Panel de diapositivas')

      add_block_item('Añadir elemento')
      within '#cama_editor_modal2' do
        expect(page).to have_css('.modal-title', text: 'Formulario de diapositiva')
        expect(page).to have_css('label', text: 'Imagen')
        expect(page).to have_css('input.url_file[placeholder="Suba su imagen o pegue una URL"]')
        expect(page).to have_css('label', text: 'Leyenda')
      end
    end

    it 'offers the styles of an accordion block in that language' do
      open_block_form(kind: 'accordion')

      within '#ow_inline_modal' do
        expect(page).to have_css('.modal-title', text: 'Panel de acordeón')
        expect(page).to have_css('.input-group-addon', text: 'Estilo')
        expect(page).to have_css('select.style-accordion option', text: 'Predeterminado')
        expect(page).to have_css('select.style-accordion option[value="primary"]', text: 'Azul')
      end
    end
  end

  # The Edit link of a listed item (a tab, a slide, an accordion panel) is a link to "#". It opens
  # the form of the item in a modal. After a real click, the browser does not follow the link when
  # the modal cannot open. The page error proves that the modal threw an error at the click.
  context 'when the form of a listed item cannot be opened' do
    # An image that needs no request: the dummy app raises an error in the example for a missing file.
    image = 'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=='
    {
      'tab' => '<ul class="nav nav-tabs"><li><a href="#t0">Tab</a></li></ul>' \
               '<div class="tab-content"><div class="tab-pane" id="t0">Pane</div></div>',
      'slider' => %(<div class="carousel-inner"><div class="item"><img src="#{image}" alt=""></div></div>),
      'accordion' => '<div class="panel"><div class="panel-heading"><h4 class="panel-title"><a>Panel</a></h4></div>' \
                     '<div><div class="panel-body">Body</div></div></div>'
    }.each do |kind, block|
      it "leaves the page where it was at the Edit link of a #{kind} item" do
        open_block_form(block, kind: kind)
        wait_for_modal_at_rest('#ow_inline_modal')
        page.execute_script("window.open_modal = function(){ throw new Error('modal broke'); };")
        watch_the_page_errors
        find('#ow_inline_modal tbody tr a.edit_item').click

        expect(current_url_fragment).to be_nil
        expect(page_errors.length).to eq(1)
      end
    end
  end

  # A block of a kind no script registers - its plugin gone - has no form to be edited in. Its menu
  # offers what needs none; an Edit entry could only fail.
  context 'with a block of a kind no script registers' do
    before do
      store_post_content(@post, grid_post_content(grid_with_block('<p>kept</p>', kind: 'gone')))
      open_post_in_editor(@post)
    end

    it 'offers to delete, clone and style the block, not to edit it' do
      open_the_menu_of('.drg_item')

      within '.drg_item > .header_box .dropdown-menu' do
        expect(page).to have_css('a.grid_content_remove')
        expect(page).to have_css('a.grid_content_clone')
        expect(page).to have_css('a.grid_style_settings')
        expect(page).to have_no_css('a.grid_content_edit')
      end
    end

    # A script may register a kind after the grid is rebuilt: the menu follows the registry as it opens
    it 'offers to edit the block once a script registers its kind' do
      toggle = open_the_menu_of('.drg_item')
      expect(page).to have_css('.drg_item > .header_box a.grid_content_remove')
      expect(page).to have_no_css('.drg_item > .header_box a.grid_content_edit')

      toggle.click # closes the menu
      expect(page).to have_no_css('.drg_item > .header_box a.grid_content_remove')
      page.execute_script("jQuery.fn.gridEditor_options.gone = {title: 'Back', callback: function(){}};")
      toggle.click
      expect(page).to have_css('.drg_item > .header_box a.grid_content_edit')
    end

    # The entry is still in the page, hidden: a click that reaches it all the same breaks nothing
    it 'opens nothing and goes nowhere when the Edit entry is clicked all the same' do
      watch_the_page_errors
      page.execute_script("document.querySelector('.panel_grid_body .drg_item .grid_content_edit').click();")

      expect(page_errors).to eq([])
      expect(current_url_fragment).to be_nil
      expect(page).to have_no_css('.modal')
    end
  end
end
