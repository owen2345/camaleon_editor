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

  # A script is one however its tags are written: a slash right behind the name, something behind
  # the name of the closing tag. Each is set aside alone, and what stands between two stays content.
  it 'gives back a script whose tags are written the less usual ways' do
    content = '<p>before</p><script/src="//example.invalid/widget.js"></script><p>between</p>' \
              '<script>window.__cama_widget_loaded = true;</script ignored><p>after</p>'

    expect(through_the_text_editor(content)).to eq(content)
    expect(scripts_in_the_text_editor).to eq(0)
    expect(script_ran).to be_nil
    within_frame(find('.mce-edit-area iframe')) { expect(page).to have_css('p', text: 'between') }
  end

  # Inside a comment, a quoted attribute value or a textarea, the editor reads a script's tags as
  # text, and so does the pattern: such content goes through the text editor as it would without
  # the setting, and a script element beside it is still set aside.
  it 'leaves the text of a script inside a comment, an attribute value or a textarea as it is' do
    commented = '<p>before</p><!-- <script src="//example.invalid/widget.js"></script> --><p>between</p>' \
                "#{script}<p>after</p>"

    expect(through_the_text_editor(commented)).to eq(commented)
    expect(scripts_in_the_text_editor).to eq(0)
    expect(script_ran).to be_nil
    expect(through_the_text_editor('<p title="<script>x()</script>">in a title</p>'))
      .to eq('<p title="&lt;script&gt;x()&lt;/script&gt;">in a title</p>')
    expect(through_the_text_editor('<p><textarea><script>x()</script></textarea></p>'))
      .to eq('<p><textarea>&lt;script&gt;x()&lt;/script&gt;</textarea></p>')
  end

  # The pattern goes by the editor's reading of markup where a browser's differs: a noscript and a
  # CDATA section hold text, a comment ends at "--!>" as well, and one that opens with "<!-->" goes
  # on to the next "-->". Each comes back as the editor gives it back without the setting.
  it 'leaves the text of a script alone wherever the editor reads it as text' do
    {
      '<p>a</p><noscript><script>x()</script></noscript><p>b</p>' =>
        '<p>a</p><noscript><script>x()</script></noscript><p>b</p>',
      '<p>a</p><![CDATA[ <script>x()</script> ]]><p>b</p>' => '<p>a</p><![CDATA[ <script>x()</script> ]]><p>b</p>',
      '<p>a</p><!-- <script>x()</script> --!><p>b</p>' => '<p>a</p><!-- <script>x()</script> --><p>b</p>',
      '<p>a</p><!--> <script>x()</script> --><p>b</p>' => '<p>a</p><!-- > <script>x()</script> --><p>b</p>'
    }.each { |markup, given_back| expect(through_the_text_editor(markup)).to eq(given_back) }

    instruction = through_the_text_editor('<p>a</p><?php echo "<script>x()</script>"; ?><p>b</p>')
    expect(instruction).to include('<?php echo')
    expect(instruction).not_to include('mce:protected')
  end

  # A page may set its text editors up with a protect list of its own, which is used in place of
  # core's default: the scripts' pattern joins that list, once, however many editors the page sets
  # up with those settings. What each pattern of a list leaves of the markup shows which patterns
  # the list holds.
  it "adds the pattern to a page's own protect list once, and to the default one otherwise" do
    own_list, default_list = page.evaluate_script(<<~JS)
      (function(){
        var left_by = function(settings){
          return jQuery.map(settings.protect, function(pattern){
            return '<?php one(); ?><script>two()</script>'.replace(pattern, function(){ return ''; });
          });
        };
        var own = {protect: [/<\\?php[\\s\\S]*?\\?>/g]};
        cama_get_tinymce_settings(own);
        return [left_by(cama_get_tinymce_settings(own)), left_by(cama_get_tinymce_settings())];
      })()
    JS

    expect(own_list).to eq(['<script>two()</script>', '<?php one(); ?>'])
    expect(default_list).to eq(['<?php one(); ?>'])
  end

  # As the page is being left, a text editor writes its raw body into its field, a script as the
  # comment it is set aside as, and then its content (grid_post_save_spec has what a page that is
  # not left would send otherwise). An editor hidden for its field to be edited writes neither.
  it 'writes its content as the page is being left, unless it is hidden for its field to be edited' do
    written, typed = page.evaluate_script(<<~JS, "<p>written in the text editor</p>#{script}")
      (function(markup){
        var editor = tinymce.get(jQuery('#form-post textarea.tinymce_textarea').first().attr('id'));
        var field = editor.getElement();
        window.onbeforeunload = null;
        editor.setContent(markup);
        window.dispatchEvent(new Event('beforeunload'));
        var written = field.value;
        editor.hide();
        field.value = 'typed in the field';
        window.dispatchEvent(new Event('beforeunload'));
        return [written, field.value];
      })(arguments[0])
    JS

    expect(written.delete("\n")).to eq("<p>written in the text editor</p>#{script}")
    expect(typed).to eq('typed in the field')
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
