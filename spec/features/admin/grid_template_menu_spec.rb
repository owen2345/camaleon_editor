# frozen_string_literal: true

# Saving a template needs the template-management permission, which the server enforces with a
# redirect; offered to a user without it, the entry's modal would show the dashboard page. The
# editor's menu is built in the browser from what the post form tells it about the user.
RSpec.describe 'the grid editor templates menu', :js do
  init_site

  def open_templates_menu
    accept_confirm { find('.mce-btn', text: 'Grid Editor').click }
    find('.grid_editor_menu a.dropdown-toggle', text: 'Templates').click
  end

  it 'offers Save as template to an administrator' do
    install_plugin_and_open_post_editor
    open_templates_menu

    expect(page).to have_css('.grid_editor_menu .list_templates')
    expect(page).to have_css('.grid_editor_menu .new_template')
  end

  it 'offers only the list to a user who may use the editor but not manage templates' do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    post_type = @site.post_types.first
    author = user_with_manager_grants({ Plugins::CamaleonEditor::MainHelper::PERMISSION_USE => 1 },
                                      'grid-author', post_type_meta: { edit: [post_type.id.to_s] })
    admin_sign_in(author.username, '12345678')
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/new"
    open_templates_menu

    expect(page).to have_css('.grid_editor_menu .list_templates')
    expect(page).to have_no_css('.grid_editor_menu .new_template')
  end
end
