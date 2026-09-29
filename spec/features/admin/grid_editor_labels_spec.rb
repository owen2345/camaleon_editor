# frozen_string_literal: true

# The labels and prompts of the grid editor come from the plugin's locale file by way of core's
# I18n() script helper, which answers with the titleized key when it finds no string.
RSpec.describe 'the grid editor labels', :js do
  init_site

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
      expect(page).to have_link('List of templates')
      expect(page).to have_link('Save as template')
    end
  end

  it 'asks before clearing the grid or leaving the editor, in a sentence' do
    message = dismiss_confirm { find('.grid_editor_menu a.clear').click }
    expect(message).to eq('Are you sure to clear the editor?')

    message = dismiss_confirm { find('.grid_editor_menu a.toggle_panel_grid').click }
    expect(message).to eq('Are you sure to leave this editor?')
  end
end
