# frozen_string_literal: true

# The forms a grid's blocks are edited in are built by the block scripts. Their headings, labels,
# buttons and tooltips come from the locale file by way of core's I18n() script helper, like the
# editor's own (grid_editor_labels_spec): the English strings are the scripts' defaults as well, so
# only a translation shows that the page holds the strings of the locale file.
RSpec.describe 'the grid editor block forms', :js do
  init_site

  def open_block_form(kind)
    store_post_content(@post, grid_post_content(grid_with_block('', kind: kind)))
    open_post_in_editor(@post)
    open_first_block_form
  end

  # The list of a block's items opens the form of one in a second modal. The list is still sliding
  # into place when its link can be found: the click waits, or it may land beside the link.
  def add_block_item(label)
    wait_for_modal_at_rest('#ow_inline_modal')
    find('#ow_inline_modal a.add_item', text: label).click
  end

  context 'with an admin language the plugin ships a translation for' do
    before { @site.set_admin_language('es') }

    it 'heads and labels the form of a media block in that language' do
      open_block_form('audio')

      within '#ow_inline_modal' do
        expect(page).to have_css('.modal-title', text: 'Formulario de audio')
        expect(page).to have_css('label', text: 'Archivo multimedia')
      end
    end

    it 'lists the tabs of a tabs block, and edits one, in that language' do
      open_block_form('tab')

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
      open_block_form('slider')
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
      open_block_form('accordion')

      within '#ow_inline_modal' do
        expect(page).to have_css('.modal-title', text: 'Panel de acordeón')
        expect(page).to have_css('.input-group-addon', text: 'Estilo')
        expect(page).to have_css('select.style-accordion option', text: 'Predeterminado')
        expect(page).to have_css('select.style-accordion option[value="primary"]', text: 'Azul')
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
      find('.drg_item > .header_box .dropdown-toggle').click

      within '.drg_item > .header_box .dropdown-menu' do
        expect(page).to have_css('a.grid_content_remove')
        expect(page).to have_css('a.grid_content_clone')
        expect(page).to have_css('a.grid_style_settings')
        expect(page).to have_no_css('a.grid_content_edit')
      end
    end

    # A script may register a kind after the grid is rebuilt: the menu follows the registry as it opens
    it 'offers to edit the block once a script registers its kind' do
      toggle = find('.drg_item > .header_box .dropdown-toggle')
      toggle.click
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
      find('.panel_grid_body .drg_item') # the grid is rebuilt
      page.execute_script(<<~JS)
        window.__cama_errors = [];
        window.addEventListener('error', function(event){ window.__cama_errors.push(event.message); });
        document.querySelector('.panel_grid_body .drg_item .grid_content_edit').click();
      JS

      expect(page.evaluate_script('window.__cama_errors')).to eq([])
      expect(URI(page.current_url).fragment).to be_nil
      expect(page).to have_no_css('.modal')
    end
  end
end
