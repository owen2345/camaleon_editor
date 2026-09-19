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
    accept_confirm { find('.mce-btn', text: 'Grid Editor').click }
    find('.grid_editor_menu a.dropdown-toggle', text: 'Templates').click
    find('.grid_editor_menu .list_templates').click
    find('#grid_table_list .destroy_item') # waits for the list
  end

  def sign_out_behind_the_page
    page.driver.browser.manage.delete_cookie('auth_token')
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

  it 'still swaps in the form and the list for a signed-in manager' do
    find('#grid_table_list .edit_item').click
    fill_in 'grid_template[name]', with: 'Renamed'
    within('#grid_template_form') { click_button 'Submit' }

    expect(page).to have_css('#grid_table_list td', text: 'Renamed')
    expect(page).to have_no_css('#cama_alert_modal')
  end
end
