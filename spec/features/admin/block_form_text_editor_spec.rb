# frozen_string_literal: true

# The forms of the Editor, Tabs, Slider and Accordion blocks each set up a text editor for a
# textarea. TinyMCE's jQuery plugin changes jQuery's val(), html(), remove() and other methods for
# the whole page the first time that the page calls jQuery's tinymce(). The block forms set up their
# text editors with tinymce.init, so these methods stay the methods of jQuery.
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
