# frozen_string_literal: true

# Saving a template needs the template-management permission, which the server enforces with a
# redirect; offered to a user without it, the entry's modal would show the dashboard page. The
# editor's menu is built in the browser from what the post form tells it about the user.
RSpec.describe 'the grid editor templates menu', :js do
  init_site

  def open_editor_and_templates_menu
    open_grid_editor
    open_templates_menu
  end

  def use_only_author
    user_with_manager_grants({ Plugins::CamaleonEditor::MainHelper::PERMISSION_USE => 1 }, 'grid-author',
                             post_type_meta: { edit: [@site.post_types.first.id.to_s] })
  end

  it 'offers Save as template to an administrator' do
    install_plugin_and_open_post_editor
    open_editor_and_templates_menu

    expect(page).to have_css('.grid_editor_menu .list_templates')
    expect(page).to have_css('.grid_editor_menu .new_template')
  end

  it 'offers only the list to a user who may use the editor but not manage templates' do
    install_plugin_and_open_post_editor(as: use_only_author)
    open_editor_and_templates_menu

    expect(page).to have_css('.grid_editor_menu .list_templates')
    expect(page).to have_no_css('.grid_editor_menu .new_template')
  end

  # A host app or another plugin can load the editor's assets from a page of its own, which says
  # nothing about the user. The editor then asks the server, and offers the entry only on a yes.
  context 'when the page does not say who may manage templates' do
    # A page that loaded the editor without saying who the user is, or that said something else.
    def forget_the_declaration(value = 'undefined')
      page.execute_script("window.cama_grid_editor_can_manage_templates = #{value};")
      record_abilities_requests
    end

    # Records every abilities request the page sends, and every answer it gets.
    def record_abilities_requests
      page.execute_script(<<~JS)
        window.__cama_abilities = {urls: [], answers: []};
        jQuery(document).ajaxSend(function(_event, _xhr, options){
          if(/camaleon_editor\\/abilities/.test(options.url)) window.__cama_abilities.urls.push(options.url);
        }).ajaxComplete(function(_event, xhr, options){
          if(/camaleon_editor\\/abilities/.test(options.url)) window.__cama_abilities.answers.push(xhr.responseText);
        });
      JS
    end

    def abilities(what)
      page.evaluate_script("window.__cama_abilities.#{what}")
    end

    it 'offers Save as template to an administrator once the server confirms' do
      install_plugin_and_open_post_editor
      forget_the_declaration
      open_editor_and_templates_menu

      expect(page).to have_css('.grid_editor_menu .new_template')
    end

    it 'asks the server as well when the page declares something other than true or false' do
      install_plugin_and_open_post_editor
      forget_the_declaration('null')
      open_editor_and_templates_menu

      expect(page).to have_css('.grid_editor_menu .new_template')
    end

    # The entry starts hidden, so "still hidden" says nothing until the server has answered: the
    # example waits for the answer before it looks.
    it 'keeps Save as template from a user who may not manage templates' do
      install_plugin_and_open_post_editor(as: use_only_author)
      forget_the_declaration
      open_editor_and_templates_menu
      wait_for_ajax

      expect(abilities('answers')).to eq(['{"manage_templates":false}'])
      expect(page).to have_css('.grid_editor_menu .list_templates')
      expect(page).to have_no_css('.grid_editor_menu .new_template')
    end

    # The answer only matters once the menu is looked at, and the request is a whole admin page
    # request - sidebar menus and all - unless it says it is an ajax one.
    it 'asks when the Templates menu is first opened, as an ajax request' do
      install_plugin_and_open_post_editor
      forget_the_declaration
      open_grid_editor
      find('.grid_editor_menu')
      expect(abilities('urls')).to be_empty

      open_templates_menu

      expect(page).to have_css('.grid_editor_menu .new_template')
      expect(abilities('urls')).to contain_exactly(a_string_including('cama_ajax_request=true'))
    end

    # A post in several languages has one editor field per language, each able to switch to the grid.
    # Menus opened while a request is under way share it.
    it 'asks once for the editors of the page whose menus open together' do
      install_plugin_and_open_post_editor
      forget_the_declaration
      open_grid_editor
      find('.grid_editor_menu')
      page.execute_script(<<~JS)
        jQuery('<textarea></textarea>').appendTo('#form-post').gridEditor(tinymce.activeEditor);
        jQuery('.grid_editor_menu .dropdown-toggle').click();
      JS

      # the second editor is not on show, so its entry is matched by not being held back, not by sight
      expect(page).to have_css('.grid_editor_menu li:not(.hidden) > .new_template', count: 2, visible: :all)
      expect(abilities('urls').size).to eq(1)
    end

    # The answer is not kept for the life of the page: a permission taken away since the menu was
    # last opened takes the entry away the next time it is.
    it 'asks again each time the menu is opened, and hides the entry on a no' do
      install_plugin_and_open_post_editor
      forget_the_declaration
      open_editor_and_templates_menu
      expect(page).to have_css('.grid_editor_menu .new_template')
      open_templates_menu # closes the menu, which asks nothing
      wait_for_ajax
      expect(abilities('urls').size).to eq(1)

      page.driver.browser.manage.delete_cookie('auth_token')
      author = use_only_author
      admin_sign_in(author.username, author.password)
      open_templates_menu
      wait_for_ajax

      expect(abilities('answers').last).to eq('{"manage_templates":false}')
      expect(page).to have_no_css('.grid_editor_menu .new_template')
    end

    it 'asks again after a request that failed' do
      install_plugin_and_open_post_editor
      forget_the_declaration
      page.execute_script(<<~JS)
        jQuery.ajaxPrefilter(function(options, _original, xhr){
          if(/camaleon_editor\\/abilities/.test(options.url) && !window.__cama_abilities_failed_once){
            window.__cama_abilities_failed_once = true;
            xhr.abort();
          }
        });
      JS
      open_editor_and_templates_menu
      wait_for_ajax
      expect(page).to have_no_css('.grid_editor_menu .new_template')

      open_templates_menu # closes the menu
      open_templates_menu

      # the first request was aborted before it left, so the one on record is the second
      expect(page).to have_css('.grid_editor_menu .new_template')
      expect(abilities('urls').size).to eq(1)
    end
  end
end
