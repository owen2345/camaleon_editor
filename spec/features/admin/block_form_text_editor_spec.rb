# frozen_string_literal: true

# The forms of the Editor, Tabs, Slider and Accordion blocks each set up a text editor for a
# textarea. TinyMCE's jQuery plugin changes jQuery's val(), html(), remove() and other methods for
# the whole page the first time that a script calls jQuery's tinymce() with settings. The block
# forms set up their text editors with tinymce.createEditor, so these methods stay the methods of
# jQuery. tinymce.init is not used either: it makes its settings the global settings of TinyMCE.
RSpec.describe 'the text editor of a block form', :js do
  init_site

  # The text editor of the textarea in the modal `modal`.
  def text_editor_in(modal)
    "tinymce.get(jQuery('#{modal} textarea').attr('id'))"
  end

  def keep_the_jquery_methods
    page.execute_script(<<~JS)
      window.__cama_jquery_methods = {};
      jQuery.each(['val', 'html', 'text', 'attr', 'append', 'prepend', 'remove', 'empty'], function(_index, name){
        window.__cama_jquery_methods[name] = jQuery.fn[name];
      });
    JS
  end

  # The names of the jQuery methods that are not the methods that keep_the_jquery_methods kept.
  def changed_jquery_methods
    page.evaluate_script(<<~JS)
      jQuery.grep(Object.keys(window.__cama_jquery_methods), function(name){
        return jQuery.fn[name] !== window.__cama_jquery_methods[name];
      })
    JS
  end

  def text_editor_count
    page.evaluate_script('tinymce.get().length')
  end

  # Opens the post with a grid of one block of the kind `kind`, and opens the form of that block. A
  # block with a list of items then opens the form of a new item. Returns the modal that holds the
  # text editor, when that text editor is ready.
  def open_the_text_editor_of(kind)
    store_post_content(@post, grid_post_content(grid_with_block('<p>stored</p>', kind: kind)))
    open_post_in_editor(@post)
    keep_the_jquery_methods
    @editors_before = text_editor_count
    open_first_block_form
    modal = '#ow_inline_modal'
    unless kind == 'editor'
      wait_for_modal_at_rest(modal)
      find("#{modal} a.add_item").click
      modal = '#cama_editor_modal2'
    end
    find("#{modal} .mce-tinymce")
    wait_for_text_editor(text_editor_in(modal))
    modal
  end

  # Opens the form of a block as open_the_text_editor_of does, with the transitions of Bootstrap off.
  # Bootstrap then shows the modal of the form during the click. Returns the modal, and the state of
  # the textarea at the end of the click: if it has a text editor, and its visibility.
  def open_the_form_with_no_transition(kind)
    store_post_content(@post, grid_post_content(grid_with_block('<p>stored</p>', kind: kind)))
    open_post_in_editor(@post)
    find('.panel_grid_body .drg_item')
    modal = '#ow_inline_modal'
    click = "jQuery('.panel_grid_body .drg_item .grid_content_edit').first().click();"
    unless kind == 'editor'
      open_first_block_form
      wait_for_modal_at_rest(modal)
      click = "jQuery('#{modal} a.add_item').click();"
      modal = '#cama_editor_modal2'
    end
    state = page.evaluate_script(<<~JS, modal)
      (function(modal){
        jQuery.support.transition = false;
        #{click}
        var area = jQuery(modal + ' textarea')[0];
        return {text_editor: !!(area.id && tinymce.get(area.id)), visibility: area.style.visibility};
      })(arguments[0])
    JS
    [modal, state]
  end

  def textarea_visibility(modal)
    page.evaluate_script("jQuery('#{modal} textarea')[0].style.visibility")
  end

  # Saves the form in `modal`. For a block with a list of items, that is the form of the item: the
  # list then saves the block. Each modal leaves the page when its fade ends.
  def save_the_form(modal)
    find("#{modal} .modal_submit").click
    expect(page).to have_no_css(modal, visible: :all)
    return if modal == '#ow_inline_modal'

    find('#ow_inline_modal .modal_submit').click
    expect(page).to have_no_css('#ow_inline_modal', visible: :all)
  end

  # The number of characters of the text before the caret of a text editor.
  def caret_position(editor)
    page.evaluate_script(<<~JS)
      (function(editor){
        var caret = editor.selection.getRng(), before = editor.getDoc().createRange();
        before.selectNodeContents(editor.getBody());
        before.setEnd(caret.startContainer, caret.startOffset);
        return before.toString().length;
      })(#{editor})
    JS
  end

  { 'editor' => 'an Editor', 'tab' => 'a Tabs', 'slider' => 'a Slider',
    'accordion' => 'an Accordion' }.each do |kind, block|
    it "keeps the methods of jQuery when the form of #{block} block sets up its text editor" do
      open_the_text_editor_of(kind)

      expect(changed_jquery_methods).to be_empty
    end

    it "stores the content of the text editor in the form of #{block} block" do
      modal = open_the_text_editor_of(kind)
      page.execute_script("#{text_editor_in(modal)}.setContent('<p>written in the form</p>');")
      save_the_form(modal)

      expect(saved_grid_content).to include('<p>written in the form</p>')
    end

    # Bootstrap reports the close at the end of the fade, and Camaleon then removes the modal.
    it "removes the text editor of the form of #{block} block when the form closes" do
      modal = open_the_text_editor_of(kind)
      find("#{modal} .modal-header .close").click
      expect(page).to have_no_css(modal, visible: :all)

      expect(text_editor_count).to eq(@editors_before)
    end

    # The setup starts when Bootstrap reports the modal as shown, and not after a delay. The
    # textarea is hidden until its text editor is ready, so the author does not see the markup.
    it "sets up the text editor of the form of #{block} block when its modal is shown, " \
       'with the textarea hidden until the text editor is ready' do
      modal, state = open_the_form_with_no_transition(kind)

      expect(state).to eq('text_editor' => true, 'visibility' => 'hidden')
      wait_for_text_editor(text_editor_in(modal))
      expect(textarea_visibility(modal)).to eq('')
    end
  end

  # A form can set up its text editor again while its modal is open: Camaleon runs the callback of a
  # modal again when it shows that modal again. The textarea keeps its text editor and stays shown.
  it 'leaves a textarea with a text editor as it is when its form sets it up again' do
    modal = open_the_text_editor_of('editor')
    page.execute_script(<<~JS)
      window.__cama_form_editor = #{text_editor_in(modal)};
      jQuery('#{modal} textarea').gridEditorFormEditor({height: 120});
    JS

    expect(textarea_visibility(modal)).to eq('')
    expect(page.evaluate_script("#{text_editor_in(modal)} === window.__cama_form_editor")).to be(true)
    expect(text_editor_count).to eq(@editors_before + 1)
  end

  # Camaleon 2.9.4 sets up the text editors of a sorted custom field again with the global settings
  # of TinyMCE.
  it 'leaves the global settings of TinyMCE as they were when a block form sets up its text editor' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>stored</p>', kind: 'editor')))
    open_post_in_editor(@post)
    page.execute_script('window.__cama_tinymce_settings = tinymce.settings;')
    open_first_block_form
    find('#ow_inline_modal .mce-tinymce')
    wait_for_text_editor(text_editor_in('#ow_inline_modal'))

    expect(page.evaluate_script('tinymce.settings === window.__cama_tinymce_settings')).to be(true)
  end

  # A page can remove the panel of a text editor and keep the text editor. TinyMCE then still has a
  # text editor with the id of a new textarea, and tinymce.init removes such a text editor.
  it 'replaces a text editor whose panel the page removed when a textarea with its id gets one' do
    open_post_in_editor(@post)
    page.execute_script(<<~JS)
      window.__cama_holder = jQuery('<div><textarea id="reused_area"></textarea></div>').appendTo('body');
      window.__cama_holder.find('textarea').gridEditorFormEditor({height: 120});
    JS
    wait_for_text_editor("tinymce.get('reused_area')")
    page.execute_script(<<~JS)
      var panel = (window.__cama_first_editor = tinymce.get('reused_area')).getContainer();
      panel.parentNode.removeChild(panel);
      window.__cama_holder[0].parentNode.removeChild(window.__cama_holder[0]);
      jQuery('<textarea id="reused_area"></textarea>').appendTo('body').gridEditorFormEditor({height: 120});
    JS
    wait_for_text_editor("tinymce.get('reused_area')")

    expect(page.evaluate_script("tinymce.get('reused_area') !== window.__cama_first_editor")).to be(true)
    expect(page.evaluate_script("jQuery.contains(document, tinymce.get('reused_area').getContainer())")).to be(true)
  end

  it 'shows the textarea of a block form when TinyMCE registers no text editor for it' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>stored</p>', kind: 'editor')))
    open_post_in_editor(@post)
    page.execute_script('tinymce.createEditor = function(){ return {render: function(){}}; };')
    open_first_block_form

    expect(page).to have_css('#ow_inline_modal textarea')
    expect(textarea_visibility('#ow_inline_modal')).to eq('')
  end

  # TinyMCE registers a text editor before it loads the scripts of that editor and makes its body.
  # Until then, getContent() returns "". The replacement of tinymce.createEditor below registers the
  # text editor and makes no body, so the text editor stays in that state.
  it 'stores the content of the textarea when the author saves the form before its text editor is ready' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>stored</p>', kind: 'editor')))
    open_post_in_editor(@post)
    page.execute_script(<<~JS)
      tinymce.createEditor = function(id, settings){
        tinymce.EditorManager.add(new tinymce.Editor(id, settings, tinymce.EditorManager));
        return {render: function(){}};
      };
    JS
    open_first_block_form
    wait_until { page.evaluate_script("!!#{text_editor_in('#ow_inline_modal')}") }
    find('#ow_inline_modal .modal_submit').click
    expect(page).to have_no_css('#ow_inline_modal', visible: :all)

    expect(saved_grid_content).to include('<p>stored</p>')
  end

  # TinyMCE makes the body of a text editor and loads the content into it before it loads the
  # content CSS. The author can write in the body during that load, but TinyMCE marks the text
  # editor as initialized only after it. Below, no new text editor gets that mark.
  it 'stores what the author wrote before TinyMCE marked the text editor as initialized' do
    store_post_content(@post, grid_post_content(grid_with_block('<p>stored</p>', kind: 'editor')))
    open_post_in_editor(@post)
    page.execute_script(<<~JS)
      Object.defineProperty(tinymce.Editor.prototype, 'initialized', {
        configurable: true, get: function(){ return false; }, set: function(){}
      });
    JS
    open_first_block_form
    text_editor = text_editor_in('#ow_inline_modal')
    wait_until { page.evaluate_script("!!(#{text_editor} && #{text_editor}.getBody())") }
    page.execute_script("#{text_editor}.getBody().innerHTML = '<p>written in the form</p>';")
    find('#ow_inline_modal .modal_submit').click
    expect(page).to have_no_css('#ow_inline_modal', visible: :all)

    expect(saved_grid_content).to include('<p>written in the form</p>')
  end

  # Camaleon 2.9.4 writes the content of each text editor into its field with jQuery's val(). It does
  # this two seconds after the post form opens, every 60 seconds, and before the page unloads. If
  # jQuery's val() sets the content of the text editor, the caret goes to the start of the text.
  it 'keeps the caret of the post text editor in place when Camaleon writes the field' do
    modal = open_the_text_editor_of('editor')
    find("#{modal} .modal-header .close").click
    expect(page).to have_no_css(modal, visible: :all)
    leave_for_the_text_editor
    page.execute_script(<<~JS)
      var editor = #{POST_TEXT_EDITOR};
      editor.focus();
      editor.selection.select(editor.getBody(), true);
      editor.selection.collapse(false);
    JS
    at_the_end = caret_position(POST_TEXT_EDITOR)

    page.execute_script(<<~JS)
      var editor = #{POST_TEXT_EDITOR};
      jQuery('#' + editor.id).val(tinymce.get(editor.id).getContent()).trigger('change');
    JS

    expect(at_the_end).to be_positive
    expect(caret_position(POST_TEXT_EDITOR)).to eq(at_the_end)
  end
end
