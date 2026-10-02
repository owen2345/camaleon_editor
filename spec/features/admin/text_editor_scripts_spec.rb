# frozen_string_literal: true

# A text editor takes the scripts out of the content it is handed. A grid's scripts are content for
# the public page, and the grid hands its export to the text editor it stands in front of: a grid
# that went through the text editor came back without them. So the plugin has the text editors keep
# scripts, as the editor keeps any element it is allowed: in its document, under a type that makes
# it no script to the browser, and given back under its own type with its text as it was. The
# editors go by the markup, whatever it is: a grid, any other content, markup a script puts in at
# the caret. A paste is another matter: its markup comes from wherever it was copied, and the
# plugin takes the scripts out of it.
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
    page.evaluate_script(<<~JS, markup, inserted)
      (function(markup, inserted){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent(markup);
        if(inserted) editor.insertContent(inserted);
        return editor.getContent();
      })(arguments[0], arguments[1])
    JS
  end

  # The types the text editor holds the scripts of its content under.
  def script_types_in_the_text_editor
    page.evaluate_script(<<~JS)
      jQuery.map(#{POST_TEXT_EDITOR}.getBody().getElementsByTagName('script'), function(script){
        return script.type;
      })
    JS
  end

  # What the post's text editor answers with after the markup was pasted into it.
  def pasted_into_the_text_editor(markup)
    page.evaluate_script(<<~JS, markup)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent('<p>written in the text editor</p>');
        editor.focus();
        var clipboard = new DataTransfer();
        clipboard.setData('text/html', markup);
        editor.getBody().dispatchEvent(new ClipboardEvent('paste', {clipboardData: clipboard, bubbles: true, cancelable: true}));
        return editor.getContent();
      })(arguments[0])
    JS
  end

  def script_ran
    script_flag('__cama_widget_loaded')
  end

  it 'gives back the scripts of a grid as they were, and holds them under a type that does not run' do
    grid = grid_post_content(grid_with_block("<p>embedded widget</p>#{script}", kind: 'editor'))

    expect(through_the_text_editor(grid).delete("\n")).to eq(grid)
    expect(script_types_in_the_text_editor).to eq(['mce-no/type'])
    expect(script_ran).to be_nil
  end

  it 'gives back the scripts of content that is not a grid' do
    content = "<p>written in the text editor</p>#{script}"

    expect(through_the_text_editor(content).delete("\n")).to eq(content)
    expect(script_types_in_the_text_editor).to eq(['mce-no/type'])
    expect(script_ran).to be_nil
  end

  # A script's text is no markup to the editor: it comes back character for character, whatever it
  # holds, under the type the script was written with.
  it "gives back a script's text as it was, under its own type" do
    data = %(<script type="application/ld+json">{\n  "name": "A & B <c>",\n  "url": "https://example.invalid/?a=1&b=2"\n}</script>)
    template = '<script id="row" type="text/template"><tr class="row"><td>{{ name }}</td></tr></script>'
    code = "<script>\n  if (1 < 2 && window.__cama_widget_loaded) {\n\tgo('</p>');   \n  }\n</script>"

    expect(through_the_text_editor("#{data}#{template}#{code}")).to eq([data, template, code].join("\n"))
    expect(script_types_in_the_text_editor).to eq(%w[mce-application/ld+json mce-text/template mce-no/type])
    expect(script_ran).to be_nil
  end

  # A script's attributes come back as the editor writes those of any element: each with its
  # value, in double quotes, in the order they were written.
  it "gives back a script's attributes in the editor's spelling" do
    written = "<script async src='https://example.invalid/w.js?a=1&b=2' data-id=w1 defer></script>"

    expect(through_the_text_editor(written))
      .to eq('<script async="" src="https://example.invalid/w.js?a=1&amp;b=2" data-id="w1" defer="defer"></script>')
  end

  # A page may set its text editors up with a list of elements of its own, which is used in place
  # of core's default: the script joins that list, once, however many editors the page sets up
  # with those settings.
  it "adds the script to a page's own list of elements once, and to the default one otherwise" do
    own_list, default_list = page.evaluate_script(<<~JS)
      (function(){
        var own = {extended_valid_elements: 'video[*]'};
        cama_get_tinymce_settings(own);
        return [cama_get_tinymce_settings(own).extended_valid_elements, cama_get_tinymce_settings().extended_valid_elements];
      })()
    JS

    expect(own_list).to eq('video[*],script[*]')
    expect(default_list.split(',')).to include('div[*]').and end_with('script[*]')
    expect(default_list.scan('script').size).to eq(1)
  end

  # As the page is being left, a text editor writes its raw body into its field, a script under
  # the type the editor holds it with, and then its content (grid_post_save_spec has what a page
  # that is not left would send otherwise). An editor hidden for its field to be edited writes
  # neither.
  it 'writes its content as the page is being left, unless it is hidden for its field to be edited' do
    written, typed = page.evaluate_script(<<~JS, "<p>written in the text editor</p>#{script}")
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
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
    expect(script_types_in_the_text_editor).to eq(['mce-no/type'])
    expect(script_ran).to be_nil
  end

  # The markup of a paste comes from wherever it was copied, a page that puts what it likes on the
  # clipboard included, and a script would sit in the editor unseen. So the scripts are taken out
  # of what is pasted; out of markup that says it was copied in the editor too, which any markup
  # can say.
  it 'takes the scripts out of pasted markup' do
    ["<p>pasted</p>#{script}", "<!-- x-tinymce/html --><p>pasted</p>#{script}"].each do |markup|
      answer = pasted_into_the_text_editor(markup)

      expect(answer).to include('pasted', 'written in the text editor')
      expect(answer).not_to include('script')
      expect(script_types_in_the_text_editor).to be_empty
    end
    expect(script_ran).to be_nil
  end
end
