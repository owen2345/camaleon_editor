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
    @template = @site.grid_templates.create!(name: 'Half column', slug: 'half-column',
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

  # Polling the page right after the dialog closes could pass before a regressed handler's effects
  # land. The script evaluated below is queued behind the click handler's own task, so by then the
  # handler has either sent its request or not, and a reloaded page would have lost the marker.
  it 'leaves the editor untouched when the confirm is declined' do
    editor_url = page.current_url
    page.execute_script(<<~'JS')
      window.__cama_same_page = true;
      window.__cama_import_requests = 0;
      jQuery(document).ajaxSend(function(_event, _xhr, options){
        if(/grid_editor\/\d+$/.test(options.url)) window.__cama_import_requests++;
      });
    JS

    dismiss_confirm { find('#grid_table_list .import_item').click }

    expect(page.evaluate_script('[window.__cama_same_page, window.__cama_import_requests]')).to eq([true, 0])
    expect(page).to have_current_path(URI(editor_url).path)
    expect(page).to have_css('#grid_table_list .import_item')
    expect(page).to have_no_css('.panel_grid_body .drg_column')
  end

  # Applying a template overwrites the grid and auto-saves, so the action has to look like an apply
  # and its prompt has to say what is about to be lost.
  it 'presents the action as applying a template and warns that the grid is replaced' do
    expect(page).to have_css("#grid_table_list .import_item[title='Apply template'] .fa-check-circle.text-success")

    message = dismiss_confirm { find('#grid_table_list .import_item').click }

    expect(message).to eq('Apply this template? It replaces the current content of the grid.')
  end

  # What the editor would save for the post right now: the grid as the auto_save export wrote it.
  def saved_grid_content
    page.evaluate_script("jQuery('.panel_grid_editor').next('textarea').val()")
  end

  # A template the way the editor stores a real one: a column holding an Editor content block whose
  # markup carries an embed script.
  def store_template_with_embed
    block = '<div class="" data-kind="editor"><div class="grid_item_content grid_item_editor">' \
            '<p>embedded widget</p><script>window.__cama_widget_loaded = true;</script></div></div>'
    column = '<div class="col-md-6" data-col="6" data-col_title="50%">' \
             "<div class=\"grid_sortable_items\">#{block}</div></div>"
    @template.update!(description: %(<div class="panel_grid_body row">#{column}</div>))
  end

  it 'applies a template complete with the scripts of its content blocks' do
    store_template_with_embed

    accept_confirm { find('#grid_table_list .import_item').click }

    expect(page).to have_css('.panel_grid_body .drg_column .drg_item')
    expect(saved_grid_content).to include('<p>embedded widget</p>')
    expect(saved_grid_content).to include('<script>window.__cama_widget_loaded = true;</script>')
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
    # the message is the delivered translation, not the script's built-in English default
    expect(page.evaluate_script('I18n_data.grid_editor.import_failed')).to eq('The template could not be loaded.')
  end

  # A refused or signed-out request is not a failed one: the server redirects it, the browser follows
  # the redirect, and the request succeeds with the login or dashboard page as its body.
  it 'refuses a redirected response instead of writing that page into the grid' do
    page.driver.browser.manage.delete_cookie('auth_token')

    accept_confirm { find('#grid_table_list .import_item').click }

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page.evaluate_script("jQuery('.panel_grid_body').children().length")).to eq(0)
  end

  it 'refuses a stored template that is not a grid body' do
    @template.update!(description: 'plain text, not a grid')

    accept_confirm { find('#grid_table_list .import_item').click }

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('#grid_table_list .import_item')
  end

  # Rebuilding the grid runs the column and content parsers and every auto_save listener, any of
  # which can throw on markup it does not expect; the list is closed by then, so a lingering
  # overlay would leave no way back to the post.
  it 'lifts the loading overlay even when rebuilding the grid throws' do
    page.execute_script(<<~JS)
      jQuery('.panel_grid_editor').on('auto_save', function(){ throw new Error('listener broke'); });
    JS

    accept_confirm { find('#grid_table_list .import_item').click }

    expect(page).to have_css('.panel_grid_body .drg_column')
    expect(page).to have_no_css('#cama_custom_loading')
  end
end
