# frozen_string_literal: true

# The labels, prompts and tooltips of the grid editor come from the locale files, the plugin's and
# core's, by way of core's I18n() script helper. Where the page holds no string for a key, the helper
# answers with the default the script passes, the English string, and without one with the titleized key.
RSpec.describe 'the grid editor labels', :js do
  init_site

  context 'with a new post' do
    before do
      install_plugin_and_open_post_editor
      open_grid_editor
    end

    it 'shows the strings of the locale file, not the titleized keys' do
      within '.grid_editor_menu' do
        expect(page).to have_link('Blocks')
        expect(page).to have_link('Content Elements')
        expect(page).to have_link('Clear')
        expect(page).to have_link('Text Editor')
        expect(page).to have_field('Preview', type: 'checkbox')
        expect(page).to have_field('Fullscreen', type: 'checkbox')
        expect(page).to have_css('.text-info', text: 'Drag and drop these blocks (Column Blocks) into the area below.')
        expect(page).to have_css('.clearfix[data-col="12"] > .header_box', text: 'Break Line')

        open_templates_menu
        expect(page).to have_link_with_tooltip('List of templates', 'Grid templates')
        expect(page).to have_link_with_tooltip('Save as template', 'New template')
      end
    end

    it 'asks before clearing the grid or leaving the editor, in a sentence' do
      message = dismiss_confirm { find('.grid_editor_menu a.clear').click }
      expect(message).to eq('Are you sure to clear the editor?')

      message = dismiss_confirm { find('.grid_editor_menu a.toggle_panel_grid').click }
      expect(message).to eq('Are you sure to leave this editor?')
    end

    # A second after the page loads, core gives every link of the admin a Bootstrap tooltip, which
    # takes the title out of the attribute: the modal keeps the heading its entry was built with.
    it 'heads the templates list by its entry, a link core has given a tooltip by then' do
      page.execute_script("jQuery('.grid_editor_menu a.list_templates').tooltip()")
      expect(page).to have_css('.grid_editor_menu a.list_templates[data-original-title]', visible: :all)

      open_templates_list
      expect(page).to have_css('#ow_inline_modal .modal-title', text: 'Grid templates')
    end
  end

  # The English strings are the script's defaults as well: only a translation shows that the page
  # holds the strings of the locale file.
  context 'with an admin language the plugin ships a translation for' do
    before do
      @site.set_admin_language('es')
      install_plugin_and_open_post_editor
      open_grid_editor
    end

    it 'shows and asks in that language' do
      within '.grid_editor_menu' do
        expect(page).to have_link('Contenidos')
        # the hint of each palette; the second one's tab is closed
        blocks_hint = 'Arrastre y suelte estos bloques (bloques de columna) en el área inferior.'
        contents_hint = 'Arrastre y suelte estos bloques (bloques de contenido) en cualquier bloque de columna.'
        expect(page).to have_css('.text-info', text: blocks_hint)
        expect(page).to have_css('.text-info', text: contents_hint, visible: :all)
        # the column blocks are labelled by their width, the break line by its name
        expect(page).to have_css('.clearfix[data-col="12"] > .header_box', text: 'Salto de línea')

        open_templates_menu(label: 'Plantillas')
        expect(page).to have_link_with_tooltip('Lista de plantillas', 'Plantillas de rejilla')
      end

      # The palette's tooltips are Bootstrap's, which shows the title on hover
      find('.grid_editor_menu .tab-pane.active .clearfix[data-col="12"]').hover
      expect(page).to have_css('.tooltip', text: 'Inserta un salto de línea para ordenar los bloques de columna.')
      # The tooltip of a column block names its width, a value the script hands to the translation.
      # It is read off the block, which lies under the open templates menu.
      column_block = find('.grid_editor_menu .tab-pane.active [data-col="6"]')
      expect(tooltip_of(column_block)).to eq('Inserta un bloque de columna con el 50% del ancho.')

      message = dismiss_confirm { find('.grid_editor_menu a.clear').click }
      expect(message).to eq('¿Está seguro de limpiar el editor?')
    end

    # The palette of content blocks shows each block by its name, with what it is for as its tooltip
    it 'names and describes the content blocks in that language' do
      find('.grid_editor_menu .nav-tabs a', text: 'Contenidos').click

      tabs_block = find('.grid_editor_menu .tab-pane.active [data-kind="tab"]')
      expect(tabs_block).to have_css('.header_box', text: 'Pestañas')
      expect(tooltip_of(tabs_block)).to eq('Permite incluir un contenedor de pestañas en cualquier columna.')
    end

    # The list opens in a modal headed by its entry's title
    it 'opens the templates list under a heading in that language' do
      open_templates_list(label: 'Plantillas')
      expect(page).to have_css('#ow_inline_modal .modal-title', text: 'Plantillas de rejilla')
    end

    # The modal is headed by the script, its form rendered by the server, and a width below zero
    # refused by the script again
    it 'opens the style settings in that language' do
      open_grid_style_settings(label: 'Plantillas')

      within '#cama_editor_style_modal' do
        expect(page).to have_css('.modal-title', text: 'Ajustes de estilo')
        expect(page).to have_css('legend', text: 'Imagen de fondo')
        expect(page).to have_select('Posición', with_options: ['Izquierda arriba'])

        fill_in 'Ancho:', with: '-1'
        find('.modal_submit').click
        expect(page).to have_css('.border_width_error', text: 'El ancho debe ser cero o mayor')
      end
    end
  end

  # The text editor's toolbar button carries the editor's name, "Grid Editor" in every language, as
  # the roles form does; the prompt it asks before the switch is a sentence, and is translated.
  context 'with the text editor still open, in an admin language the plugin ships a translation for' do
    before do
      @site.set_admin_language('es')
      install_plugin_and_open_post_editor
    end

    it 'asks before switching to the grid editor in that language' do
      expect(open_grid_editor).to eq('¿Está seguro de cambiar de editor?')
      expect(page).to have_css('.panel_grid_editor')
    end
  end

  # The browser gets the strings of the admin language alone, and the plugin ships three languages.
  context 'with an admin language the plugin does not ship' do
    before do
      @site.set_admin_language('fr')
      install_plugin_and_open_post_editor
      open_grid_editor
    end

    it 'shows and asks in English, not in titleized keys' do
      within '.grid_editor_menu' do
        expect(page).to have_link('Content Elements')
        expect(page).to have_css('.text-info', text: 'Drag and drop these blocks (Column Blocks) into the area below.')

        open_templates_menu
        expect(page).to have_link_with_tooltip('List of templates', 'Grid templates')
      end

      message = dismiss_confirm { find('.grid_editor_menu a.clear').click }
      expect(message).to eq('Are you sure to clear the editor?')
    end

    it 'opens the style settings in English' do
      open_grid_style_settings

      within '#cama_editor_style_modal' do
        expect(page).to have_css('.modal-title', text: 'Style settings')
        expect(page).to have_css('legend', text: 'Background Image')
      end
    end
  end

  # A tooltip is a title attribute the script writes into a markup string: a translation holding a
  # double quote would end the attribute there, and the tooltip would stop at the quote.
  context 'with translations that hold a double quote' do
    let(:quoted) { { break_line_title: 'Insert a "break" line.', block_tab_hint: 'Holds "tabs" & more.' } }

    def store_editor_strings(strings)
      I18n.backend.store_translations(:en, camaleon_cms: { admin: { js: { grid_editor: strings } } })
    end

    around do |example|
      shipped = quoted.keys.index_with { |key| I18n.t("camaleon_cms.admin.js.grid_editor.#{key}", locale: :en) }
      store_editor_strings(quoted)
      example.run
    ensure
      store_editor_strings(shipped)
    end

    it 'shows the whole string as the tooltip of a column block and of a content block' do
      install_plugin_and_open_post_editor
      open_grid_editor

      break_line = find('.grid_editor_menu .clearfix[data-col="12"]')
      expect(tooltip_of(break_line)).to eq(quoted[:break_line_title])
      tabs_block = find('.grid_editor_menu [data-kind="tab"]', visible: :all)
      expect(tooltip_of(tabs_block)).to eq(quoted[:block_tab_hint])
    end
  end

  context 'with a post whose grid holds a block with a content element' do
    before do
      store_post_content(@post, grid_post_content(grid_with_block('<p>kept</p>')))
      open_post_in_editor(@post)
    end

    it 'asks before deleting, naming what goes: the content element or the block' do
      find('.drg_item > .header_box .dropdown-toggle').click
      # The action's label says it all: no tooltip repeats it
      expect(tooltip_of(find('.drg_item > .header_box .grid_content_remove'))).to be_nil
      message = dismiss_confirm { find('.drg_item > .header_box .grid_content_remove').click }
      expect(message).to eq('Are you sure to delete this content?')

      find('.drg_column > .header_box .dropdown-toggle').click
      message = dismiss_confirm { find('.drg_column > .header_box .grid_col_remove').click }
      expect(message).to eq('Are you sure to delete this block?')
    end
  end

  # A column is headed by the title saved with it, its width; a break line's saved title is its
  # English name, whatever the language it was added in. A block of a kind no script registers - its
  # plugin gone - has no name at all. The editor heads both in the admin language, and saves the
  # break line with the title it came with.
  context 'with a post whose grid holds a break line and a block of a kind nobody registers' do
    before do
      @site.set_admin_language('es')
      columns = grid_column_markup(grid_block_markup('', kind: 'gone')) +
                grid_column_markup('', col: 12, title: 'Break Line')
      store_post_content(@post, grid_post_content(grid_body_markup(columns)))
      open_post_in_editor(@post)
    end

    it 'heads them in the admin language and saves the break line under its own title' do
      expect(page).to have_css('.panel_grid_body .drg_column > .header_box', text: 'Salto de línea')
      expect(page).to have_css('.panel_grid_body .drg_item > .header_box', text: 'desconocido')

      trigger_grid_auto_save
      expect(saved_grid_content).to include('data-col_title="Break Line"')
    end
  end
end
