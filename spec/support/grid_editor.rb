# frozen_string_literal: true

# Grid markup the way the editor exports it, and the steps the grid editor feature specs share.

def grid_block_markup(inner, kind: 'text')
  %(<div class="" data-kind="#{kind}"><div class="grid_item_content grid_item_#{kind}">#{inner}</div></div>)
end

def grid_column_markup(inner = '', col: 6, title: '50%')
  %(<div class="col-md-#{col}" data-col="#{col}" data-col_title="#{title}">) +
    %(<div class="grid_sortable_items">#{inner}</div></div>)
end

# A break line: a full-width column with no area for blocks, saved under its English title.
def grid_break_line_markup
  %(<div class="clearfix col-md-12" data-col_title="Break Line" data-col="12"></div>)
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

# Switches the text editor to the grid editor, and answers with the prompt its button asked.
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

# The tooltip an element of the admin carries, or nil. A Bootstrap tooltip moves a title into
# data-original-title and leaves the attribute empty. The editor gives its palette blocks one as it
# opens; core gives every link one a second after the page loads, so for a link, which of the two
# attributes holds the text depends on when the example looks.
def tooltip_of(element)
  element['data-original-title'].presence || element[:title].presence
end

def have_link_with_tooltip(label, tooltip)
  have_link(label) { |link| tooltip_of(link) == tooltip }
end

def apply_listed_template
  accept_confirm { find('#grid_table_list .import_item').click }
end

# A modal slides into place for a moment after it opens, and a click aimed at one of several rows
# while it moves can land on the row beside it. This waits until no transition runs in the modal.
def wait_for_modal_at_rest(selector)
  find("#{selector}.in")
  Timeout.timeout(Capybara.default_max_wait_time) do
    sleep 0.05 while page.evaluate_script(<<~JS, selector)
      document.querySelector(arguments[0]).getAnimations({subtree: true}).some(function(animation){
        return animation instanceof CSSTransition;
      })
    JS
  end
end

# The post's textarea has more than one writer. The grid writes its export there at every
# auto_save. The text editor writes its content there when it loses focus, with every draft and as
# the form is sent: the grid's export while the grid editor is shown, and its own serialization (a
# newline between tags, #rrggbb for rgb(), <strong> for <b>, no script) once the author went back
# to it. And once a block form has loaded a text editor of its own through jQuery's tinymce(),
# val() hands the grid's export to the text editor alone: the field keeps what it held until the
# text editor next writes.
#
# So the export is not read off the field. The grid hands it to the text editor right before the
# change_in its auto_save triggers, and what a text editor was last handed at that moment goes on
# record. Nothing else triggers a change_in on a textarea, and the record does not look for the
# editor beside the field: a rebuild that fails never puts its editor in the page.
def record_grid_exports
  page.execute_script(<<~JS)
    if(window.jQuery && !window.__cama_grid_exports){
      var record = window.__cama_grid_exports = {handed: null, last: null};
      var watch = function(editor){
        editor.on('BeforeSetContent', function(event){ record.handed = event.content; });
      };
      if(window.tinymce){
        jQuery.each(tinymce.editors, function(_index, editor){ watch(editor); });
        tinymce.on('AddEditor', function(event){ watch(event.editor); });
      }
      jQuery(document).on('change_in', 'textarea', function(){ record.last = record.handed; });
    }
  JS
end

# The grid as the last auto_save exported it, nil when none did since the editor page was opened.
# Saving the post while the grid editor is shown stores it as it is.
def saved_grid_content
  page.evaluate_script('window.__cama_grid_exports.last')
end

# What saving the post would store of content the grid editor left to the text editor: the text
# editor writes its content into the field before the form goes, as it does here. It puts a
# newline between tags; the content these specs store has none of its own, so they are taken off.
def text_editor_content
  page.evaluate_script(<<~JS).delete("\n")
    (function(){
      tinymce.triggerSave();
      return jQuery('#form-post textarea.tinymce_textarea').first().val();
    })()
  JS
end

def trigger_grid_auto_save
  page.execute_script("jQuery('.panel_grid_editor').trigger('auto_save');")
end

# Sends the post form with its own button, and waits for the page the server answers with. The
# form asks before a page with unsaved changes is left; nobody is there to answer.
def submit_post_form
  page.execute_script(<<~JS)
    window.onbeforeunload = null;
    document.documentElement.setAttribute('data-cama-form-sent', '');
  JS
  find('#form-post .input-submit input[type=submit]').click
  expect(page).to have_no_css('html[data-cama-form-sent]')
  find_by_id('admin_content')
end
