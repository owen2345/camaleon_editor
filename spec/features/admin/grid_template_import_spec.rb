# frozen_string_literal: true

# The Import link in the templates list points at the template's own URL, which the click handler
# fetches over XHR. Declining the confirm must leave the editor as it was: a handler that returns
# without cancelling the click lets the browser follow the link to the raw template markup, and
# the unsaved post is lost.
RSpec.describe 'importing a grid template', :js do
  init_site

  before do
    install_plugin_and_open_post_editor
    column = '<div class="col-md-6" data-col="6" data-col_title="50%"><div class="grid_sortable_items"></div></div>'
    @site.grid_templates.create!(name: 'Half column', slug: 'half-column',
                                 description: %(<div class="panel_grid_body row">#{column}</div>))
    accept_confirm { find('.mce-btn', text: 'Grid Editor').click }
    find('.grid_editor_menu a.dropdown-toggle', text: 'Templates').click
    find('.grid_editor_menu .list_templates').click
  end

  # Whatever becomes of the click handler (a script error before it cancels the click, a modified
  # click opening a new tab), the link itself must have nowhere to go.
  it 'keeps the template URL out of the link target' do
    link = find('#grid_table_list .import_item')

    expect(link[:href]).to end_with('#')
    expect(link['data-url']).to match(%r{/grid_editor/\d+\z})
  end

  it 'stays on the post editor when the confirm is declined' do
    editor_url = page.current_url

    dismiss_confirm { find('#grid_table_list .import_item').click }

    expect(page).to have_current_path(URI(editor_url).path)
    expect(page).to have_css('#grid_table_list .import_item')
    expect(page).to have_no_css('.panel_grid_body .drg_column')
  end

  it 'loads the template into the grid when the confirm is accepted' do
    accept_confirm { find('#grid_table_list .import_item').click }

    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')
    expect(page).to have_no_css('#grid_table_list')
  end

  # The request can fail - the template deleted by another manager meanwhile, an expired session, a
  # dropped connection - and the editor must come back usable. The dummy app re-raises server errors
  # into the example, so the failure is produced in the browser: the request is aborted as it leaves.
  it 'reports a failed import and releases the editor' do
    page.execute_script(<<~'JS')
      jQuery.ajaxPrefilter(function(options, _original, xhr){
        if(/grid_editor\/\d+$/.test(options.url)) xhr.abort();
      });
    JS

    accept_confirm { find('#grid_table_list .import_item').click }

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('#grid_table_list .import_item')
  end
end
