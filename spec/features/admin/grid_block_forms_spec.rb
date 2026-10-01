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
    find('.panel_grid_body .drg_item') # the grid is rebuilt
    page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
  end

  # The list of a block's items opens the form of one in a second modal
  def add_block_item(label)
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
end
