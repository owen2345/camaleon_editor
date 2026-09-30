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

        open_templates_menu
        expect(page).to have_link('List of templates', title: 'Grid templates')
        expect(page).to have_link('Save as template', title: 'New template')
      end
    end

    it 'asks before clearing the grid or leaving the editor, in a sentence' do
      message = dismiss_confirm { find('.grid_editor_menu a.clear').click }
      expect(message).to eq('Are you sure to clear the editor?')

      message = dismiss_confirm { find('.grid_editor_menu a.toggle_panel_grid').click }
      expect(message).to eq('Are you sure to leave this editor?')
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

        open_templates_menu(label: 'Plantillas')
        expect(page).to have_link('Lista de plantillas', title: 'Plantillas de rejilla')
      end

      # The palette's tooltips are Bootstrap's, which shows the title on hover
      find('.grid_editor_menu .tab-pane.active .clearfix[data-col="12"]').hover
      expect(page).to have_css('.tooltip', text: 'Inserta un salto de línea para ordenar los bloques de columna.')

      message = dismiss_confirm { find('.grid_editor_menu a.clear').click }
      expect(message).to eq('¿Está seguro de limpiar el editor?')
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

        open_templates_menu
        expect(page).to have_link('List of templates', title: 'Grid templates')
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
      # The action's tooltip is core's string, the one its label shows
      expect(find('.drg_item > .header_box .grid_content_remove')['title']).to eq('Delete')
      message = dismiss_confirm { find('.drg_item > .header_box .grid_content_remove').click }
      expect(message).to eq('Are you sure to delete this content?')

      find('.drg_column > .header_box .dropdown-toggle').click
      message = dismiss_confirm { find('.drg_column > .header_box .grid_col_remove').click }
      expect(message).to eq('Are you sure to delete this block?')
    end
  end
end
