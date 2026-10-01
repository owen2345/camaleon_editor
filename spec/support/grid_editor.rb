# frozen_string_literal: true

# Grid markup the way the editor exports it, and the steps the grid editor feature specs share.

def grid_block_markup(inner, kind: 'text')
  %(<div class="" data-kind="#{kind}"><div class="grid_item_content grid_item_#{kind}">#{inner}</div></div>)
end

def grid_column_markup(inner = '', col: 6, title: '50%')
  %(<div class="col-md-#{col}" data-col="#{col}" data-col_title="#{title}">) +
    %(<div class="grid_sortable_items">#{inner}</div></div>)
end

def grid_body_markup(inner = grid_column_markup, attributes: '')
  %(<div class="panel_grid_body row"#{" #{attributes}" unless attributes.empty?}>#{inner}</div>)
end

# A grid of one column holding one block.
def grid_with_block(inner, kind: 'text')
  grid_body_markup(grid_column_markup(grid_block_markup(inner, kind: kind)))
end

# Post content is the grid behind the marker that names the libraries its blocks need.
def grid_post_content(body)
  "<div>[grid_editor data='']</div>#{body}"
end

# Written past the model: these specs are about what the editor does with content already stored.
def store_post_content(post, content)
  # rubocop:disable-next Rails/SkipsModelValidations
  CamaleonCms::Post.where(id: post.id).update_all(content: content)
end

# Same for a template: with no signed-in author behind the write, the model's markup gate would
# refuse what these specs need stored (scripts, handlers).
def store_template_markup(template, markup)
  # rubocop:disable-next Rails/SkipsModelValidations
  Plugins::CamaleonEditor::GridTemplate.where(id: template.id).update_all(description: markup)
end

def open_post_in_editor(post)
  install_plugin_and_open_post_editor(post: post)
end

# The session ends while the page stays open: what the page sends next is redirected to the login page.
def sign_out_behind_the_page
  page.driver.browser.manage.delete_cookie('auth_token')
end

# Counts the requests the page sends for a template's markup, and keeps the last answer.
def watch_template_requests
  page.execute_script(<<~'JS')
    window.__cama_template_requests = {sent: 0, response: null};
    jQuery(document).ajaxSend(function(_event, _xhr, options){
      if(/grid_editor\/\d+$/.test(options.url)) window.__cama_template_requests.sent++;
    }).ajaxComplete(function(_event, xhr, options){
      if(/grid_editor\/\d+$/.test(options.url)) window.__cama_template_requests.response = xhr.responseText;
    });
  JS
end

def template_requests_sent
  page.evaluate_script('window.__cama_template_requests.sent')
end

def template_response
  page.evaluate_script('window.__cama_template_requests.response')
end

# The dummy app re-raises server errors into the example, so a failed request for a template's
# markup is produced in the browser: aborted as it leaves.
def abort_template_requests
  page.execute_script(<<~'JS')
    jQuery.ajaxPrefilter(function(options, _original, xhr){
      if(/grid_editor\/\d+$/.test(options.url)) xhr.abort();
    });
  JS
end

def open_grid_editor
  accept_confirm { find('.mce-btn', text: 'Grid Editor').click }
end

# The menu's label is the admin language's; the default is the English one.
def open_templates_menu(label: 'Templates')
  find('.grid_editor_menu a.dropdown-toggle', text: label).click
end

def open_templates_list(label: 'Templates')
  open_templates_menu(label: label)
  find('.grid_editor_menu .list_templates').click
end

# The style settings of the whole grid, an entry of the same menu.
def open_grid_style_settings(label: 'Templates')
  open_templates_menu(label: label)
  find('.grid_editor_menu .grid_style_settings').click
end

# The tooltip a link of the admin carries, or nil. A second after the page loads, core gives every
# link a Bootstrap tooltip, which moves a title into data-original-title and leaves the attribute
# empty: which of the two holds the text depends on when the example looks.
def tooltip_of(link)
  link['data-original-title'].presence || link[:title].presence
end

def have_link_with_tooltip(label, tooltip)
  have_link(label) { |link| tooltip_of(link) == tooltip }
end

def apply_listed_template
  accept_confirm { find('#grid_table_list .import_item').click }
end

# The yellow background the specs give a grid, as saved content may carry it: rgb() the way the
# grid exports it, or #rrggbb once the text editor, which saves when it loses focus, has written
# the same content again. Which of the two the textarea holds depends on when that happens.
GRID_YELLOW_BACKGROUND = /background-color: (?:rgb\(255, 204, 0\)|#ffcc00)/

# What the textarea behind the editor holds right now: the grid as the last auto_save exported it,
# or that content written again by the text editor, which saves when it loses focus.
def saved_grid_content
  page.evaluate_script("jQuery('.panel_grid_editor').next('textarea').val()")
end

def trigger_grid_auto_save
  page.execute_script("jQuery('.panel_grid_editor').trigger('auto_save');")
end
