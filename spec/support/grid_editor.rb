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
def grid_with_block(inner, kind: 'text', attributes: '')
  grid_body_markup(grid_column_markup(grid_block_markup(inner, kind: kind)), attributes: attributes)
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

# The content that the post stores now.
def post_content
  CamaleonCms::Post.find(@post.id).content
end

# Same for a template: with no signed-in author behind the write, the model's markup gate would
# refuse what these specs need stored (scripts, handlers).
def store_template_markup(template, markup)
  # rubocop:disable-next Rails/SkipsModelValidations
  Plugins::CamaleonEditor::GridTemplate.where(id: template.id).update_all(description: markup)
end

def open_post_in_editor(post, as: nil)
  install_plugin_and_open_post_editor(as: as, post: post)
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

# Accepts each confirm prompt of the page from now on. Use it when one script clicks through more
# than one prompt: accept_confirm accepts only the prompt of the step that it wraps.
def confirm_every_prompt
  page.execute_script('window.confirm = function(){ return true; };')
end

# Opens the form of the first block, after the grid is rebuilt from the stored content.
def open_first_block_form
  find('.panel_grid_body .drg_item')
  page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
end

# Stores a grid with one block of the given kind that contains `inner` (empty by default). Then
# opens the post in the editor and opens the form of that block.
def open_block_form(inner = '', kind: 'text')
  store_post_content(@post, grid_post_content(grid_with_block(inner, kind: kind)))
  open_post_in_editor(@post)
  open_first_block_form
end

# A drag that moves nothing lets an example pass when it tests what a drag must not do. Watch the
# page for the start of a sort, and let the example assert that it saw one.
def watch_for_a_sort
  page.execute_script("jQuery(document).on('sortstart', function(){ window.__cama_sort_started = true; });")
end

def sort_started
  page.evaluate_script('window.__cama_sort_started')
end

# Drags the first block by its header, slowly enough to start a sort, and releases it: two steps
# down, or onto the element `to` and one step more.
def drag_the_first_block(to: nil)
  drag = hold_the_first_block
  to ? drag.move_to(to).pause(duration: 0.2).move_by(0, 3) : drag.move_by(0, 25).pause(duration: 0.2).move_by(0, 25)
  drag.pause(duration: 0.2).release.perform
end

# Holds the first block by its header until jQuery UI reads the hold as a drag.
def hold_the_first_block
  handle = first('.panel_grid_body .drg_item .header_box').native
  page.driver.browser.action.click_and_hold(handle).pause(duration: 0.4)
end

# The two sortables: the grid root, as the grid editor finds it, and the area of the first column.
GRID_ROOT = "jQuery('.panel_grid_editor > .panel_grid_body_w > .panel_grid_body')"
FIRST_COLUMN_AREA = "#{GRID_ROOT}.children('.drg_column').first().children('.grid_sortable_items')".freeze

# Runs the handler of a grid sortable for the end of a sort on its first item. `sortable` is the
# script that returns the sortable, and `items` is the selector of its items.
def end_a_sort(sortable, items)
  page.execute_script(<<~JS, items)
    var sortable = #{sortable};
    sortable.sortable('option', 'stop').call(sortable[0], {}, {item: sortable.children(arguments[0]).first()});
  JS
end

# Leaves the grid editor for the text editor, and accepts the prompt of the link.
def leave_for_the_text_editor
  accept_confirm { find('.grid_editor_menu .toggle_panel_grid').click }
  find('.mce-tinymce')
end

# The fragment of the page URL. A followed link to "#" leaves an empty fragment, which location.hash
# does not show.
def current_url_fragment
  URI(page.current_url).fragment
end

# Records the errors that the page reports from now on, for page_errors to return. A listener that
# throws an error at a real click reports one. A second call clears the record.
def watch_the_page_errors
  page.execute_script(<<~JS)
    if(!window.__cama_errors){
      window.addEventListener('error', function(event){ window.__cama_errors.push(event.message); });
    }
    window.__cama_errors = [];
  JS
end

def page_errors
  page.evaluate_script('window.__cama_errors')
end

# The field of the post's text editor. In a post in more than one language, each language has its
# own field and text editor. This is the field of the first language. The field that holds the
# composed content has no editor.
POST_TEXT_EDITOR_FIELD = "jQuery('#form-post textarea.tinymce_textarea:not(.translated-item)').first()"
# The text editor of that field.
POST_TEXT_EDITOR = "tinymce.get(#{POST_TEXT_EDITOR_FIELD}.attr('id'))".freeze

# Waits until a text editor is ready: it has its content, and its init hooks ran. `editor` is the
# script that returns the editor, or nothing while there is no editor.
def wait_for_text_editor(editor)
  wait_until { page.evaluate_script("!!(#{editor} || {}).initialized") }
end

# Makes a new field with a text editor for each id, and waits until each editor is ready. `settings`
# is the script of the editor settings. `selector` in that script finds the fields.
def set_up_text_editors(ids, settings)
  page.execute_script(<<~JS, ids)
    var selector = jQuery.map(arguments[0], function(id){
      jQuery('<textarea>').attr('id', id).appendTo('body');
      return '#' + id;
    }).join(', ');
    tinymce.init(#{settings});
  JS
  ids.each { |id| wait_for_text_editor("tinymce.get('#{id}')") }
end

# Sets the content of the post's text editor, as an author who writes there does.
def text_editor_holds(markup)
  page.execute_script("#{POST_TEXT_EDITOR}.setContent(arguments[0]);", markup)
end

# Does what a block form does when it opens: it loads its own text editor through jQuery's
# tinymce(). After that, jQuery uses the text editors of the page: val() reads and writes the text
# editor of a field and not the field, and remove() also removes the text editor of an element.
def load_a_block_form_text_editor
  page.execute_script(
    "jQuery('<textarea></textarea>').appendTo('body').tinymce(cama_get_tinymce_settings({height: '120px'}));"
  )
end

# The value that a content script sets under `name` when it runs, or nil if it did not run. A text
# editor has its own window, and a script that runs there sets the value there. The step reads the
# window of the page and the window of each text editor.
def script_flag(name)
  page.evaluate_script(<<~JS, name)
    (function(name){
      var editors = window.tinymce ? tinymce.editors : [];
      var windows = [window].concat(jQuery.map(editors, function(editor){ return editor.getWin(); }));
      return jQuery.map(windows, function(win){ return win[name]; })[0];
    })(arguments[0])
  JS
end

# The content that a post in more than one language sends. Core composes it from the language fields
# when one of them triggers a change, which occurs when a text editor loses focus.
def composed_content
  page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea.translated-item')[0].value")
end

# Closes the alert of core and waits until it is gone: an open alert gets the clicks for the page.
def close_alert
  page.execute_script("jQuery('#cama_alert_modal').modal('hide');")
  expect(page).to have_no_css('#cama_alert_modal')
end

# The menu's label is the admin language's; the default is the English one.
def open_templates_menu(label: 'Templates')
  find('.grid_editor_menu a.dropdown-toggle', text: label).click
end

# Opens the options menu of the first column ('.drg_column') or block ('.drg_item') and returns its
# toggle. Capybara finds the toggle again if the page replaces it (allow_reload, a beta option).
# find(…, match: :first) also reloads, but the FindAllFirst cop rewrites it.
def open_the_menu_of(part)
  toggle = first(".panel_grid_body #{part} > .header_box .dropdown-toggle", allow_reload: true)
  toggle.click
  toggle
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

# The link that applies the listed template, after the list stops. The modal of the list slides into
# position after it opens, and the link moves by two times its height. A click during that time can
# land above the link, and then no prompt shows.
def listed_template_link
  wait_for_modal_at_rest('#ow_inline_modal')
  find('#grid_table_list .import_item')
end

def apply_listed_template
  accept_confirm { listed_template_link.click }
end

# A modal slides into place for a moment after it opens, and a click aimed at one of several rows
# while it moves can land on the row beside it. This waits until no transition runs in the modal.
def wait_for_modal_at_rest(selector)
  find("#{selector}.in")
  wait_until do
    page.evaluate_script(<<~JS, selector)
      !document.querySelector(arguments[0]).getAnimations({subtree: true}).some(function(animation){
        return animation instanceof CSSTransition;
      })
    JS
  end
end

# The post's field has more than one writer. The grid editor writes its export there at each
# auto_save. The text editor writes its content there when it loses focus, with each draft and at
# submit. That content is the grid export while the grid editor is visible. After the author goes
# back to the text editor, it is the text editor's own serialization (a newline between tags,
# #rrggbb for rgb(), <strong> for <b>).
#
# For this reason, the specs do not read the export from the field. At each auto_save, the grid
# editor gives the export to the text editor and then triggers change_in on the field. The record:
# - Keeps the last content that a text editor got, and the field of that editor.
# - Stores that content as the export when the same field triggers change_in. Core also triggers
#   change_in on a field that has no editor (the draft save of core master does, for the summary of
#   the first language).
# - Does not look for the grid editor near the field: a rebuild that fails does not put its grid
#   editor into the page.
# - Listens before the listeners of the editor, which can change the content that the editor got.
def record_grid_exports
  page.execute_script(<<~JS)
    if(window.jQuery && !window.__cama_grid_exports){
      var record = window.__cama_grid_exports = {handed: null, field: null, last: null};
      var watch = function(editor){
        editor.on('BeforeSetContent', function(event){
          record.handed = event.content;
          record.field = editor.getElement();
        }, true);
      };
      if(window.tinymce){
        jQuery.each(tinymce.editors, function(_index, editor){ watch(editor); });
        tinymce.on('AddEditor', function(event){ watch(event.editor); });
      }
      jQuery(document).on('change_in', 'textarea', function(){
        if(this === record.field) record.last = record.handed;
      });
    }
  JS
end

# The value of the field behind the grid editor, read from the field itself. After a block form
# loads a text editor, jQuery's val() returns the content of the field's text editor.
def grid_field
  page.evaluate_script("jQuery('.panel_grid_editor').next('textarea')[0].value")
end

# The grid as the last auto_save exported it, or nil if there was no auto_save since the editor page
# opened. A save while the grid editor is visible stores this export unchanged.
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
      return #{POST_TEXT_EDITOR_FIELD}[0].value;
    })()
  JS
end

def trigger_grid_auto_save
  page.execute_script("jQuery('.panel_grid_editor').trigger('auto_save');")
end

# Adds an export listener that throws an error from now on, as the listener of a block plugin can.
def make_the_grid_export_throw
  page.execute_script("jQuery('.panel_grid_editor').on('auto_save', function(){ throw new Error('listener broke'); });")
end

# Changes the text of the first block, as a block form does, and makes the grid editor export.
def change_the_grid
  page.execute_script("jQuery('.panel_grid_body .drg_item b').text('changed');")
  trigger_grid_auto_save
end

# Submits the post form with its own button and waits for the response page. It removes the unload
# prompt of the form: nobody can answer a prompt about unsaved changes here.
def submit_post_form
  page.execute_script(<<~JS)
    window.onbeforeunload = null;
    document.documentElement.setAttribute('data-cama-form-sent', '');
  JS
  find('#form-post .input-submit input[type=submit]').click
  expect(page).to have_no_css('html[data-cama-form-sent]')
  find_by_id('admin_content')
end
