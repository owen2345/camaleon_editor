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

        open_templates_menu(label: 'Plantillas')
        expect(page).to have_link_with_tooltip('Lista de plantillas', 'Plantillas de rejilla')
      end

      # The palette's tooltips are Bootstrap's, which shows the title on hover
      find('.grid_editor_menu .tab-pane.active .clearfix[data-col="12"]').hover
      expect(page).to have_css('.tooltip', text: 'Inserta un salto de línea para ordenar los bloques de columna.')

      message = dismiss_confirm { find('.grid_editor_menu a.clear').click }
      expect(message).to eq('¿Está seguro de limpiar el editor?')
    end

    # The list opens in a modal headed by its entry's title
    it 'opens the templates list under a heading in that language' do
      open_templates_list(label: 'Plantillas')
      expect(page).to have_css('#ow_inline_modal .modal-title', text: 'Plantillas de rejilla')
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
end
