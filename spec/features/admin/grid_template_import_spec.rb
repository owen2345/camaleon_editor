# frozen_string_literal: true

# Applying a template from the templates list fetches its markup and rebuilds the grid from it. The
# unsaved post is at stake at every step: a click that navigates away, a response that is not a
# template, a rebuild that fails half-way.
RSpec.describe 'importing a grid template', :js do
  init_site

  before do
    install_plugin_and_open_post_editor
    @template = @site.grid_templates.create!(name: 'Half column', slug: 'half-column',
                                             description: grid_body_markup)
    open_grid_editor
    open_templates_list
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

  # A template the way the editor stores a real one: a column holding an Editor content block whose
  # markup carries an embed script.
  def store_template_with_embed(script: 'window.__cama_widget_loaded = true;')
    block = "<p>embedded widget</p><script>#{script}</script>"
    store_template_markup(@template, grid_with_block(block, kind: 'editor'))
  end

  # An embed script is content for the public page, where the theme has loaded what it calls. The
  # editor keeps it in the grid and does not run it.
  it 'applies a template complete with its scripts, without running them' do
    store_template_with_embed

    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column .drg_item')
    expect(saved_grid_content).to include('<p>embedded widget</p>')
    expect(saved_grid_content).to include('<script>window.__cama_widget_loaded = true;</script>')
    expect(page.evaluate_script('window.__cama_widget_loaded')).to be_nil
  end

  it 'applies a template whose script could not run in the admin page' do
    store_template_with_embed(script: 'startTheThemeSlider();')

    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column .drg_item')
    expect(page).to have_no_css('#cama_alert_modal')
    expect(saved_grid_content).to include('<script>startTheThemeSlider();</script>')
  end

  # Templates > Settings styles the grid as a whole, and the editor keeps that on the grid's root
  # element: a template saved from a styled grid must bring the style along.
  it 'applies the style of the whole grid along with its columns' do
    root = %(<div class="panel_grid_body row" style="background-color: rgb(255, 204, 0);" ) +
           %(data-style='{"b-c":"#ffcc00"}'>)
    @template.update!(description: "#{root}#{grid_column_markup}</div>")

    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column')
    expect(saved_grid_content).to include('background-color: rgb(255, 204, 0)')
    expect(saved_grid_content).to include('data-style="{&quot;b-c&quot;:&quot;#ffcc00&quot;}"')
  end

  # A template saved from a grid nobody styled carries no style of its own: applying it replaces
  # the columns, not the style the current grid was given through Templates > Settings.
  it 'leaves the style of the current grid alone when the template carries none' do
    @template.update!(description: grid_body_markup(attributes: 'style="background-color: rgb(255, 204, 0);"'))
    apply_listed_template
    expect(page).to have_css('.panel_grid_body[style*="background-color"] .drg_column')

    @template.update!(description: grid_body_markup(grid_column_markup(col: 12, title: '100%')))
    open_templates_list
    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '100%')
    expect(saved_grid_content).to include('background-color: rgb(255, 204, 0)')
  end

  # The list stays open while the template is fetched, and the loading overlay stops the mouse, not
  # the keyboard: Enter on the focused link would start a second apply over the first.
  it 'ignores a second apply while one is under way' do
    find('#grid_table_list .import_item') # the list has arrived
    page.execute_script(<<~'JS')
      window.confirm = function(){ return true; };
      window.__cama_import_requests = 0;
      jQuery(document).ajaxSend(function(_event, _xhr, options){
        if(/grid_editor\/\d+$/.test(options.url)) window.__cama_import_requests++;
      });
      var link = jQuery('#grid_table_list .import_item').first();
      link.click();
      link.click();
    JS

    expect(page).to have_css('.panel_grid_body .drg_column')
    expect(page.evaluate_script('window.__cama_import_requests')).to eq(1)
  end

  it 'loads the template into the grid when the confirm is accepted' do
    apply_listed_template

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

    apply_listed_template

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('#grid_table_list .import_item')
    # the message is the delivered translation, not the script's built-in English default
    expect(page.evaluate_script('I18n_data.grid_editor.import_failed')).to eq('The template could not be loaded.')
  end

  # A refused or signed-out request is not a failed one: the server redirects it, the browser follows
  # the redirect, and the request succeeds with the login or dashboard page as its body.
  # An empty grid would stay empty whatever the handler did: the grid is filled first, so that
  # "nothing reached it" can fail. The page that came back is on record, so each example is about
  # the redirect it names.
  def fill_the_grid_and_reopen_the_list
    apply_listed_template
    expect(page).to have_css('.panel_grid_body .drg_column', count: 1)
    open_templates_list
    find('#grid_table_list .import_item')
    page.execute_script(<<~'JS')
      jQuery(document).ajaxComplete(function(_event, xhr, options){
        if(/grid_editor\/\d+$/.test(options.url)) window.__cama_import_response = xhr.responseText;
      });
    JS
  end

  def expect_the_grid_untouched
    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('.panel_grid_body > *', count: 1)
    expect(page).to have_css('.panel_grid_body > .drg_column .header_box', text: '50%')
  end

  it 'refuses a redirected response instead of writing that page into the grid' do
    fill_the_grid_and_reopen_the_list
    page.driver.browser.manage.delete_cookie('auth_token')

    apply_listed_template

    expect_the_grid_untouched
    expect(page.evaluate_script('window.__cama_import_response')).to include('type="password"')
  end

  # The other redirect core issues: a permission refused mid-session sends the request to the
  # dashboard, a full admin page, which must not reach the grid either.
  it 'refuses the dashboard page a refused request is redirected to' do
    fill_the_grid_and_reopen_the_list
    # the list was opened by the administrator; the session now becomes one the editor refuses
    refused = user_with_manager_grants({}, 'no-grants')
    page.driver.browser.manage.delete_cookie('auth_token')
    admin_sign_in(refused.username, refused.password)

    apply_listed_template

    expect_the_grid_untouched
    response = page.evaluate_script('window.__cama_import_response')
    expect(response).to include('id="admin_content"')
    expect(response).not_to include('type="password"')
  end

  # Templates seeded by a host app or copied from another site do not always carry the editor's own
  # root class; their columns sit in a plain wrapper.
  it 'applies a template whose columns sit in a plain wrapper' do
    @template.update!(description: "<div>#{grid_column_markup}</div>")

    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')
    expect(page).to have_no_css('#grid_table_list')
  end

  # The editor's own markup wraps the grid body in a panel_grid_body_w div; a template copied with
  # that wrapper holds its grid body one level down.
  it 'finds the grid body inside a wrapper, style and all' do
    body = grid_body_markup(attributes: 'style="background-color: rgb(255, 204, 0);"')
    @template.update!(description: %(<div class="panel_grid_body_w">#{body}</div>))

    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')
    expect(page).to have_css('.panel_grid_body', count: 1)
    expect(saved_grid_content).to include('background-color: rgb(255, 204, 0)')
  end

  it 'applies a plain-wrapper template that is followed by stray markup' do
    @template.update!(description: "<div>#{grid_column_markup}</div><p></p>")

    apply_listed_template

    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')
    expect(page).to have_no_css('#grid_table_list')
  end

  it 'refuses a stored template that is not a grid body' do
    @template.update!(description: 'plain text, not a grid')

    apply_listed_template

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('#grid_table_list .import_item')
  end

  # The replaced grid is kept as live nodes while the new one is built, in case it has to come
  # back. Once the apply has succeeded it has to be released, handlers and sortable widgets included.
  it 'releases the grid it replaced once the template is applied' do
    apply_listed_template
    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')
    page.execute_script("window.__cama_replaced = jQuery('.panel_grid_body .grid_sortable_items')[0];")
    expect(page.evaluate_script('jQuery.hasData(window.__cama_replaced)')).to be(true)

    open_templates_list
    apply_listed_template

    expect(page).to have_no_css('#grid_table_list')
    expect(page.evaluate_script('jQuery.hasData(window.__cama_replaced)')).to be(false)
  end

  # Reading the response is the first thing that can go wrong once it has arrived; the overlay and
  # the failure message must not depend on it going right.
  it 'reports a response it fails to read and lifts the overlay' do
    find('#grid_table_list .import_item') # the list has arrived
    page.execute_script("jQuery.fn.skipGridEditorLibraries = function(){ throw new Error('reader broke'); };")

    apply_listed_template

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('#grid_table_list .import_item')
  end

  # Rebuilding the grid runs the column and content parsers and every auto_save listener, any of
  # which can throw on markup it does not expect. The overlay has to lift, a half-built grid the post
  # content may not match has to give way to the previous one, and the list has to stay open like
  # on any other failure, so another template can be picked.
  it 'puts the previous grid back and says so when rebuilding the grid throws' do
    apply_listed_template
    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')

    full_width = '<div class="col-md-12" data-col="12" data-col_title="100%">' \
                 '<div class="grid_sortable_items"></div></div>'
    @template.update!(description: %(<div class="panel_grid_body row">#{full_width}</div>))
    page.execute_script(<<~JS)
      jQuery('.panel_grid_editor').on('auto_save', function(){ throw new Error('listener broke'); });
    JS
    open_templates_list
    apply_listed_template

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_no_css('#cama_custom_loading')
    expect(page).to have_css('.panel_grid_body .drg_column .header_box', text: '50%')
    expect(page).to have_no_css('.panel_grid_body .drg_column .header_box', text: '100%')
    expect(saved_grid_content).to include('data-col="6"')
    expect(saved_grid_content).not_to include('data-col="12"')
    expect(page).to have_css('#grid_table_list .import_item')
  end

  # The grid that goes back can hold embed scripts of its own, which must stay as inert on the way
  # back as they were on the way in.
  it 'puts a previous grid with a script back without running the script' do
    store_template_with_embed
    apply_listed_template
    expect(page).to have_css('.panel_grid_body .drg_column .drg_item')

    store_template_markup(@template, grid_body_markup(grid_column_markup(col: 12, title: '100%')))
    page.execute_script(<<~JS)
      jQuery('.panel_grid_editor').on('auto_save', function(){ throw new Error('listener broke'); });
    JS
    open_templates_list
    apply_listed_template

    expect(page).to have_css('#cama_alert_modal', text: 'The template could not be loaded')
    expect(page).to have_css('.panel_grid_body .drg_column .drg_item')
    expect(saved_grid_content).to include('<script>window.__cama_widget_loaded = true;</script>')
    expect(page.evaluate_script('window.__cama_widget_loaded')).to be_nil
  end
end
