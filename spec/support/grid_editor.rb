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

# What the post stores for its content by now.
def post_content(post = @post)
  CamaleonCms::Post.find(post.id).content
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

# Answers yes to every prompt the page asks from here on, for a script that clicks through several:
# accept_confirm answers the one prompt of the step it wraps.
def confirm_every_prompt
  page.execute_script('window.confirm = function(){ return true; };')
end

# Opens the form of the grid's first block, once the grid is rebuilt from what the post stores.
def open_first_block_form
  find('.panel_grid_body .drg_item')
  page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();")
end

# Stores a grid of one block holding `inner`, of the kind, opens the post in the editor and opens
# that block's form.
def open_block_form(inner, kind: 'text')
  store_post_content(@post, grid_post_content(grid_with_block(inner, kind: kind)))
  open_post_in_editor(@post)
  open_first_block_form
end

# A drag that moves nothing passes an example on what a drag must not do. So the page is watched
# for a sort that starts, and the example says it saw one.
def watch_for_a_sort
  page.execute_script("jQuery(document).on('sortstart', function(){ window.__cama_sort_started = true; });")
end

def sort_started
  page.evaluate_script('window.__cama_sort_started')
end

# Drags the grid's first block by its header, slowly enough for a sort to start, and lets it go:
# two steps down, or onto `to` (an element) and a step further.
def drag_the_first_block(to: nil)
  drag = hold_the_first_block
  to ? drag.move_to(to).pause(duration: 0.2).move_by(0, 3) : drag.move_by(0, 25).pause(duration: 0.2).move_by(0, 25)
  drag.pause(duration: 0.2).release.perform
end

# The first block held by its header, for long enough that jQuery UI takes the hold for a drag.
def hold_the_first_block
  handle = first('.panel_grid_body .drg_item .header_box').native
  page.driver.browser.action.click_and_hold(handle).pause(duration: 0.4)
end

# The way back: leaves the grid editor for the text editor, and answers the prompt its link asked.
def leave_for_the_text_editor
  accept_confirm { find('.grid_editor_menu .toggle_panel_grid').click }
  find('.mce-tinymce')
end

# The field of the post's text editor. In a post of several languages each language has a field
# and a text editor of its own, and this is the first language's: the field they are composed into
# has no editor.
POST_TEXT_EDITOR_FIELD = "jQuery('#form-post textarea.tinymce_textarea:not(.translated-item)').first()"
# The text editor of that field.
POST_TEXT_EDITOR = "tinymce.get(#{POST_TEXT_EDITOR_FIELD}.attr('id'))".freeze

# Waits until a text editor is set up: its content loaded, the hooks of its init run. `editor` is
# the script that answers with the editor, or with nothing while there is none yet.
def wait_for_text_editor(editor)
  wait_until { page.evaluate_script("!!(#{editor} || {}).initialized") }
end

# Sets a text editor up over a new field for each id, and waits until each is set up. `settings`
# is the script of the settings the page sets them up with; `selector` there finds the fields.
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

# Hands the post's text editor its content, as an author who writes there does.
def text_editor_holds(markup)
  page.execute_script("#{POST_TEXT_EDITOR}.setContent(arguments[0]);", markup)
end

# What a block's form does as it opens: it loads a text editor of its own through jQuery's
# tinymce(). From then on jQuery goes by the page's text editors: val() reads and writes the text
# editor of a field that has one and leaves the field alone, and remove() takes the text editor
# of an element along.
def load_a_block_form_text_editor
  page.execute_script(
    "jQuery('<textarea></textarea>').appendTo('body').tinymce(cama_get_tinymce_settings({height: '120px'}));"
  )
end

# What a script of the content left under `name`, had it run: nil when it did not. A text editor
# has a document of its own, and a script that ran there left its mark there, not in the page: so
# the page is asked, and the document of each of its text editors.
def script_flag(name)
  page.evaluate_script(<<~JS, name)
    (function(name){
      var editors = window.tinymce ? tinymce.editors : [];
      var windows = [window].concat(jQuery.map(editors, function(editor){ return editor.getWin(); }));
      return jQuery.map(windows, function(win){ return win[name]; })[0];
    })(arguments[0])
  JS
end

# What a post in several languages sends for its content. Core composes it from the fields of the
# languages when one of them says it changed, which a text editor does when it loses focus.
def composed_content
  page.evaluate_script("jQuery('#form-post textarea.tinymce_textarea.translated-item')[0].value")
end

# Closes core's alert, and waits until it is gone: it would take the clicks meant for the page.
def close_alert
  page.execute_script("jQuery('#cama_alert_modal').modal('hide');")
  expect(page).to have_no_css('#cama_alert_modal')
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
  wait_until do
    page.evaluate_script(<<~JS, selector)
      !document.querySelector(arguments[0]).getAnimations({subtree: true}).some(function(animation){
        return animation instanceof CSSTransition;
      })
    JS
  end
end

# The post's textarea has more than one writer. The grid writes its export there at every
# auto_save. The text editor writes its content there when it loses focus, with every draft and as
# the form is sent: the grid's export while the grid editor is shown, and its own serialization (a
# newline between tags, #rrggbb for rgb(), <strong> for <b>) once the author went back to it.
#
# So the export is not read off the field. The grid hands it to the text editor right before the
# change_in its auto_save triggers, and what a text editor was last handed at that moment goes on
# record. Nothing else triggers a change_in on a textarea, and the record does not look for the
# editor beside the field: a rebuild that fails never puts its editor in the page. The record
# listens ahead of the editor's own listeners, which may rewrite what it was handed.
def record_grid_exports
  page.execute_script(<<~JS)
    if(window.jQuery && !window.__cama_grid_exports){
      var record = window.__cama_grid_exports = {handed: null, last: null};
      var watch = function(editor){
        editor.on('BeforeSetContent', function(event){ record.handed = event.content; }, true);
      };
      if(window.tinymce){
        jQuery.each(tinymce.editors, function(_index, editor){ watch(editor); });
        tinymce.on('AddEditor', function(event){ watch(event.editor); });
      }
      jQuery(document).on('change_in', 'textarea', function(){ record.last = record.handed; });
    }
  JS
end

# What the field behind the grid editor holds, read off the field itself: jQuery's val() answers
# with the content of the field's text editor once a block form has loaded a text editor.
def grid_field
  page.evaluate_script("jQuery('.panel_grid_editor').next('textarea')[0].value")
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
      return #{POST_TEXT_EDITOR_FIELD}[0].value;
    })()
  JS
end

def trigger_grid_auto_save
  page.execute_script("jQuery('.panel_grid_editor').trigger('auto_save');")
end

# Changes the text of the grid's first block, as a block's form would, and has the grid export.
def change_the_grid
  page.execute_script("jQuery('.panel_grid_body .drg_item b').text('changed');")
  trigger_grid_auto_save
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
