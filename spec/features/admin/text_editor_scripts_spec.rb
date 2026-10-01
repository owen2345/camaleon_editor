# frozen_string_literal: true

# A text editor takes the scripts out of the content it is handed. A grid's scripts are content for
# the public page, and the grid hands its export to the text editor it stands in front of: a grid
# that went through the text editor came back without them. So the plugin has the text editors keep
# scripts, with the editor's own protect setting: out of the document, and given back as they were.
# The setting goes by the markup, whatever it is: a grid, any other content, markup a script puts
# in at the caret. A paste is another matter: the editor's paste filter takes its scripts out
# before the markup goes in, as it always did.
RSpec.describe 'scripts in the text editor', :js do
  init_site

  let(:script) { '<script>window.__cama_widget_loaded = 1 < 2 && true;</script>' }

  before do
    open_post_in_editor(@post)
    find('.mce-btn', text: 'Grid Editor')
  end

  # What the post's text editor answers with after it was handed the markup, and after the markup
  # in `inserted` went in at the caret.
  def through_the_text_editor(markup, inserted: nil)
    page.evaluate_script(<<~JS, markup, inserted).delete("\n")
      (function(markup, inserted){
        var editor = tinymce.get(jQuery('#form-post textarea.tinymce_textarea').first().attr('id'));
        editor.setContent(markup);
        if(inserted) editor.insertContent(inserted);
        window.__cama_scripts_in_text_editor = editor.getBody().getElementsByTagName('script').length;
        return editor.getContent();
      })(arguments[0], arguments[1])
    JS
  end

  def scripts_in_the_text_editor
    page.evaluate_script('window.__cama_scripts_in_text_editor')
  end

  def script_ran
    page.evaluate_script('window.__cama_widget_loaded')
  end

  it 'gives back the scripts of a grid as they were, without holding or running them' do
    grid = grid_post_content(grid_with_block("<p>embedded widget</p>#{script}", kind: 'editor'))

    expect(through_the_text_editor(grid)).to eq(grid)
    expect(scripts_in_the_text_editor).to eq(0)
    expect(script_ran).to be_nil
  end

  it 'gives back the scripts of content that is not a grid' do
    content = "<p>written in the text editor</p>#{script}"

    expect(through_the_text_editor(content)).to eq(content)
    expect(scripts_in_the_text_editor).to eq(0)
    expect(script_ran).to be_nil
  end

  it 'keeps the script of markup put in at the caret' do
    answer = through_the_text_editor('<p>written in the text editor</p>', inserted: "<p>inserted</p>#{script}")

    expect(answer).to include('inserted', script)
    expect(scripts_in_the_text_editor).to eq(0)
    expect(script_ran).to be_nil
  end

  it 'leaves pasted markup to the paste filter, which takes its script out' do
    answer = page.evaluate_script(<<~JS, "<p>pasted</p>#{script}").delete("\n")
      (function(markup){
        var editor = tinymce.get(jQuery('#form-post textarea.tinymce_textarea').first().attr('id'));
        editor.setContent('<p>written in the text editor</p>');
        editor.focus();
        var clipboard = new DataTransfer();
        clipboard.setData('text/html', markup);
        editor.getBody().dispatchEvent(new ClipboardEvent('paste', {clipboardData: clipboard, bubbles: true, cancelable: true}));
        return editor.getContent();
      })(arguments[0])
    JS

    expect(answer).to include('pasted', 'written in the text editor')
    expect(answer).not_to include('script')
    expect(script_ran).to be_nil
  end
end
