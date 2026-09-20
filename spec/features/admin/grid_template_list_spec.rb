# frozen_string_literal: true

# The templates modal swaps its content for what its own requests return. A signed-out request is
# redirected and comes back as a 200 carrying the login page, which must not be shown as if it
# were the list or the template form.
RSpec.describe 'managing grid templates after the session is gone', :js do
  init_site

  before do
    install_plugin_and_open_post_editor
    @template = @site.grid_templates.create!(name: 'Half column', slug: 'half-column',
                                             description: '<div class="panel_grid_body row"></div>')
    open_grid_editor
    open_templates_list
    find('#grid_table_list .destroy_item') # waits for the list
  end

  def expect_the_request_to_be_reported
    expect(page).to have_css('#cama_alert_modal', text: 'The request was not completed')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_no_css('#ow_inline_modal input[type="password"]')
  end

  # A redirected DELETE is re-sent as a DELETE to the login path, which has no such route, so a
  # signed-out delete reaches the editor as a failed request rather than as a page. The dummy app
  # re-raises server errors into the example, so the failure is produced in the browser.
  it 'reports a delete that failed and keeps the list' do
    page.execute_script(<<~JS)
      jQuery.ajaxPrefilter(function(options, _original, xhr){
        if(options.type === 'DELETE' || options.type === 'delete') xhr.abort();
      });
    JS

    accept_confirm { find('#grid_table_list .destroy_item').click }

    expect_the_request_to_be_reported
    expect(page).to have_css('#grid_table_list .destroy_item')
    expect(@site.grid_templates.where(id: @template.id)).to exist
  end

  it 'reports an edit that came back as the login page and keeps the list' do
    sign_out_behind_the_page

    find('#grid_table_list .edit_item').click

    expect_the_request_to_be_reported
    expect(page).to have_css('#grid_table_list .edit_item')
  end

  it 'reports a save that came back as the login page and keeps the form' do
    find('#grid_table_list .edit_item').click
    expect(page).to have_css('#grid_template_form')
    sign_out_behind_the_page

    fill_in 'grid_template[name]', with: 'Renamed'
    within('#grid_template_form') { click_button 'Submit' }

    expect_the_request_to_be_reported
    expect(page).to have_css('#grid_template_form')
    expect(@template.reload.name).to eq('Half column')
  end

  # Core gives the admin's titled links a Bootstrap tooltip when the page loads; the list arrives later.
  it 'gives the actions of the list the tooltips the rest of the admin has' do
    expect(page).to have_css('#grid_table_list .import_item[data-original-title="Apply template"]')
    expect(page).to have_css('#grid_table_list .destroy_item[data-original-title]')
  end

  # The overlay stops the mouse, not Enter on the button that keeps the focus: a second submit while
  # the first is under way would store the template twice.
  it 'saves a new template once when the form is submitted twice' do
    find('#ow_inline_modal .close').click
    expect(page).to have_no_css('#ow_inline_modal')
    open_templates_menu
    find('.grid_editor_menu .new_template').click
    fill_in 'grid_template[name]', with: 'Saved once'

    page.execute_script("var form = jQuery('#grid_template_form'); form.submit(); form.submit();")

    expect(page).to have_css('#grid_table_list td', text: 'Saved once')
    wait_for_ajax
    expect(@site.grid_templates.where(name: 'Saved once').count).to eq(1)
  end

  it 'still swaps in the form and the list for a signed-in manager' do
    find('#grid_table_list .edit_item').click
    fill_in 'grid_template[name]', with: 'Renamed'
    within('#grid_template_form') { click_button 'Submit' }

    expect(page).to have_css('#grid_table_list td', text: 'Renamed')
    expect(page).to have_no_css('#cama_alert_modal')
  end

  context 'when a templates modal is opened' do
    before { find('#ow_inline_modal .close').click }

    it 'reports a list that came back as the login page instead of showing that page' do
      expect(page).to have_no_css('#ow_inline_modal')
      sign_out_behind_the_page

      open_templates_list

      expect_the_request_to_be_reported
      expect(page).to have_no_css('#ow_inline_modal')
    end

    # The menu is built from what the page knew about the user when it loaded; a permission taken
    # away since then sends the request to the dashboard.
    it 'reports a Save as template that is refused instead of showing the dashboard' do
      expect(page).to have_no_css('#ow_inline_modal')
      refused = user_with_manager_grants({ Plugins::CamaleonEditor::MainHelper::PERMISSION_USE => 1 }, 'use-only')
      sign_out_behind_the_page
      admin_sign_in(refused.username, refused.password)

      open_templates_menu
      find('.grid_editor_menu .new_template').click

      expect_the_request_to_be_reported
      expect(page).to have_no_css('#ow_inline_modal')
    end

    it 'still opens the template form for a manager, filled with the current grid' do
      open_templates_menu
      find('.grid_editor_menu .new_template').click

      expect(page).to have_css('#ow_inline_modal #grid_template_form')
      expect(find('#grid_template_form textarea', visible: :all).value).to include('panel_grid_body')
    end
  end
end
