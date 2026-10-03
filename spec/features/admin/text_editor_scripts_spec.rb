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
  let(:stored_content) { nil }

  before do
    store_post_content(@post, stored_content) if stored_content
    open_post_in_editor(@post)
  end

  # What a text editor, the post's unless another is given, answers with after it was handed the
  # markup, and after the markup in `inserted` went in at the caret.
  def through_the_text_editor(markup, inserted: nil, editor: POST_TEXT_EDITOR)
    page.evaluate_script(<<~JS, markup, inserted)
      (function(markup, inserted){
        var editor = #{editor};
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

  # What a text editor, the post's unless another is given, answers with after the markup was
  # pasted into it.
  def pasted_into_the_text_editor(markup, editor: POST_TEXT_EDITOR)
    page.evaluate_script(<<~JS, markup)
      (function(markup){
        var editor = #{editor};
        editor.setContent('<p>written in the text editor</p>');
        editor.focus();
        var clipboard = new DataTransfer();
        clipboard.setData('text/html', markup);
        editor.getBody().dispatchEvent(new ClipboardEvent('paste', {clipboardData: clipboard, bubbles: true, cancelable: true}));
        return editor.getContent();
      })(arguments[0])
    JS
  end

  # What a text editor answers with after it was handed the markup and its caret came to stand
  # outside any block, at the very start of its content.
  def with_the_caret_outside_any_block(markup, editor: POST_TEXT_EDITOR)
    page.evaluate_script(<<~JS, markup)
      (function(markup){
        var editor = #{editor};
        editor.setContent(markup);
        editor.focus();
        editor.selection.setCursorLocation(editor.getBody(), 0);
        editor.nodeChanged();
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

  # A script's text is text of the editor's document, where a plugin of the editor that marks text
  # (a no-break space made visible, for one) wraps it in elements of its own. Outside a script the
  # editor takes those off as its content is read; inside one they would come back as part of the
  # script. Read, a script holds its text alone.
  it "gives back a script's text as it was while the editor shows invisible characters" do
    content = "<p>written in the text editor</p><script>var name =\u00a0'A B';</script>"

    marked, shown, hidden = page.evaluate_script(<<~JS, content)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent(markup);
        editor.execCommand('mceVisualChars');
        var marked = editor.getBody().querySelectorAll('script .mce-nbsp').length;
        var shown = editor.getContent();
        editor.execCommand('mceVisualChars');
        return [marked, shown, editor.getContent()];
      })(arguments[0])
    JS

    expect(marked).to eq(1)
    expect(shown.delete("\n")).to eq(content)
    expect(hidden.delete("\n")).to eq(content)
  end

  # A script's attributes come back as the editor writes those of any element: each with its
  # value, in double quotes, in the order they were written.
  it "gives back a script's attributes in the editor's spelling" do
    written = "<script async src='https://example.invalid/w.js?a=1&b=2' data-id=w1 defer></script>"

    expect(through_the_text_editor(written))
      .to eq('<script async="" src="https://example.invalid/w.js?a=1&amp;b=2" data-id="w1" defer="defer"></script>')
  end

  # The editor ends a script at the first closing tag it reads, or at a tag that only begins like
  # one. A browser reads a script's text otherwise: "<!--" opens a comment there, "<script" inside
  # the comment a script of the text's own, and a closing tag then ends that script, not the
  # element. A script hidden in a comment, the old way, may so write another script out. The
  # editor is given a browser's reading: what a browser takes for the script comes back whole, and
  # what stands behind it stays content.
  it 'reads where a script ends as a browser does' do
    written_out = '<script src="//example.invalid/widget.js"></script>'
    [
      "<script><!-- document.write('#{written_out}'); //--></script>",
      "<script><!-- document.write('#{written_out.sub('</', '<\/')}'); //--></script>",
      '<script>var tag = "</scriptx>";</script>',
      '<script><!-- hidden --> var tag = "<script>";</script>'
    ].each do |script|
      content = "<p>before</p>#{script}<p>after</p>"

      expect(through_the_text_editor(content).delete("\n")).to eq(content)
      expect(script_types_in_the_text_editor).to eq(['mce-no/type'])
      within_frame(find('.mce-edit-area iframe')) { expect(page).to have_css('body > p', text: 'after') }
    end
  end

  # Outside such a comment the first closing tag ends the script, for a browser too: a script that
  # writes one out unescaped ends there, and the rest of it is content.
  it 'ends a script at the first closing tag outside a comment of its text, as a browser does' do
    answer = through_the_text_editor(%q(<script>document.write('<script src="/w.js"></script>');</script><p>after</p>))

    expect(answer.delete("\n")).to eq(%q(<script>document.write('<script src="/w.js"></script><p>');</p><p>after</p>))
  end

  # The script joins the list of elements each text editor is added with, whatever made that list:
  # core's default, a list of the page's own handed to core's settings or put onto them afterwards,
  # settings that are not core's.
  context "with text editors set up with settings of the page's own" do
    # The list of elements a text editor was added with, by its field's id.
    def list_of(id)
      page.evaluate_script("tinymce.get('#{id}').settings.extended_valid_elements")
    end

    # The settings a page sets its editors up with are the page's: they stay as it wrote them,
    # however many editors it sets up with them, and so do core's defaults.
    it "adds the script to a page's own list for each editor, and to the default one otherwise" do
      # the settings object the page made stays at hand as the page's
      set_up_text_editors(%w[own_a own_b], <<~JS)
        window.__cama_own_settings = cama_get_tinymce_settings({selector: selector, extended_valid_elements: 'video[*]'})
      JS
      default_list = page.evaluate_script("#{POST_TEXT_EDITOR}.settings.extended_valid_elements")

      expect([list_of('own_a'), list_of('own_b')]).to all(eq('video[*],script[*]'))
      expect(page.evaluate_script('window.__cama_own_settings.extended_valid_elements')).to eq('video[*]')
      expect(default_list.split(',')).to include('div[*]').and end_with('script[*]')
      expect(default_list.scan('script').size).to eq(1)
      expect(page.evaluate_script('cama_get_tinymce_settings().extended_valid_elements')).not_to include('script')
    end

    it "keeps a script in an editor whose list the page put onto core's settings afterwards" do
      set_up_text_editors(%w[late_list], <<~JS)
        jQuery.extend(cama_get_tinymce_settings({selector: selector}), {extended_valid_elements: 'video[*]'})
      JS

      answer = through_the_text_editor("<p>a</p>#{script}", editor: "tinymce.get('late_list')")

      expect(answer.delete("\n")).to eq("<p>a</p>#{script}")
    end

    it "keeps a script in an editor set up without core's settings" do
      set_up_text_editors(%w[not_cores], '{selector: selector}')

      answer = through_the_text_editor("<p>a</p>#{script}", editor: "tinymce.get('not_cores')")

      expect(answer.delete("\n")).to eq("<p>a</p>#{script}")
    end

    # A rule the page's own lists hold for the script is the page's say on scripts, a narrower one
    # included: the editor goes by the last rule it is given for an element, so none is put behind
    # it, and a script comes back with the attributes the page allows it. A rule for every element
    # ("*[...]") is no say on scripts: behind it the script still joins the list.
    it "leaves a rule that a page's own lists hold for the script as the page wrote it" do
      set_up_text_editors(%w[own_rule], <<~JS)
        cama_get_tinymce_settings({selector: selector, extended_valid_elements: 'video[*],script[src|type]'})
      JS
      set_up_text_editors(%w[other_list],
                          "cama_get_tinymce_settings({selector: selector, valid_elements: 'p,script[src]'})")
      set_up_text_editors(%w[rule_for_all],
                          "cama_get_tinymce_settings({selector: selector, valid_elements: '*[class|style|id]'})")
      answer = through_the_text_editor('<p>a</p><script src="/w.js" type="text/x" charset="utf-8"></script>',
                                       editor: "tinymce.get('own_rule')")

      expect(answer.delete("\n")).to eq('<p>a</p><script src="/w.js" type="text/x"></script>')
      expect(list_of('own_rule')).to eq('video[*],script[src|type]')
      expect(list_of('other_list')).not_to include('script')
      expect(list_of('rule_for_all')).to end_with(',script[*]')
    end
  end

  # As the page is being left, a text editor writes its content into its field, where its own
  # write would put its raw body, a script under the type the editor holds it with
  # (grid_post_save_spec has what a page that is not left would send otherwise). An editor hidden
  # for its field to be edited writes nothing.
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

  # The editor gives whatever stands at the top level of its content a paragraph, once the caret
  # comes to stand outside any block, unless its map of block elements has the element's name.
  # The map has the script's: a script stays where it was written.
  it 'leaves a script at the top level of the content where it stands' do
    content = "#{script}<p>written in the text editor</p>"

    expect(with_the_caret_outside_any_block(content).delete("\n")).to eq(content)
  end

  # Markup put in at the caret leaves the caret behind its last piece of content, and the editor
  # steps back over what it takes for a block to find it: a script loaded by its src that ends the
  # markup is stepped over, so what the author types next goes behind the text before the script,
  # not behind the script.
  it 'leaves the caret before a script that ends markup put in at the caret' do
    widget = '<div class="widget"><div>body</div><script src="/widget.js"></script></div>'

    answer = page.evaluate_script(<<~JS, widget)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent('<p>written in the text editor</p>');
        editor.focus();
        editor.selection.select(editor.getBody(), true);
        editor.selection.collapse(false);
        editor.insertContent(markup);
        editor.insertContent('typed');
        return editor.getContent();
      })(arguments[0])
    JS

    expect(answer.delete("\n")).to include(widget.sub('body', 'bodytyped'))
  end

  # The editor's search goes through the text of the content and leaves out the text of an element
  # that shows none, a script's for one, as long as the element is no block to it. The script is
  # kept out of a paragraph without becoming a block to the search: its text is not found, and
  # Replace does not rewrite it unseen.
  it "leaves a script's text out of the editor's find and replace" do
    content = "<p>pick a color</p><script>var tint = 'color';</script>"

    found, replaced = page.evaluate_script(<<~JS, content)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR}, search = editor.plugins.searchreplace;
        editor.setContent(markup);
        var found = search.find('color', false, false);
        search.replace('colour', true, true);
        search.done();
        return [found, editor.getContent()];
      })(arguments[0])
    JS

    expect(found).to eq(1)
    expect(replaced.delete("\n")).to eq("<p>pick a colour</p><script>var tint = 'color';</script>")
  end

  # The post's text editor is handed the stored content as the form opens, and writes its content
  # into the field as the form is sent: a post that is not a grid keeps its script through both,
  # where it stood.
  context 'with a post whose content holds a script' do
    let(:stored_content) { "<p>written in the text editor</p>#{script}<p>and below it</p>" }

    it 'stores the post with its script where it stood when it is saved from the text editor' do
      expect(script_types_in_the_text_editor).to eq(['mce-no/type'])
      expect(script_ran).to be_nil

      submit_post_form

      expect(post_content.delete("\r\n")).to eq(stored_content)
    end
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
  # can say. They are found as the editor will find them: a browser reads some markup otherwise -
  # a script behind a plaintext tag or an unfinished tag, one inside a comment that a noscript, an
  # svg style or a video (raw text to the editor's media plugin) ends early for the editor, one
  # inside a template - and would see no script where the editor does. The other way round too:
  # a comment or a CDATA section the editor reads to its end, where a browser ends it at its first
  # ">" ("<!--->", "<![CDATA[ >") and reads a script behind it; and a processing instruction the
  # editor writes back ("<?xml ?>" as "<?xml?>"), which its next read takes up to the first "/>",
  # a tag further, so that a script in a textarea's text behind it becomes a script. None of the
  # three is content: a paste that spells a script loses them. And
  # they are found in the markup as the editor's paste plugin leaves it: its own filters run first,
  # and the one that takes style attributes out of tags (in a WebKit browser) can glue a script tag
  # together out of a tag that spelled none.
  it 'takes the scripts out of pasted markup' do
    glued = script.sub('<script>', '<scr style="x"ipt>').sub('</script>', '</scr style="x"ipt>')
    markups = ["<p>pasted</p>#{script}", "<!-- x-tinymce/html --><p>pasted</p>#{script}",
               "<p>pasted</p><plaintext>#{script}", "<p>pasted</p><i#{script}",
               "<p>pasted</p><noscript><!-- </noscript>#{script} --></noscript>",
               "<p>pasted</p><svg><style><!-- </style>#{script} --></style></svg>",
               "<p>pasted</p><video><!-- </video>#{script} --></video>",
               "<p>pasted</p><template>#{script}</template>", "<p>pasted</p>#{glued}",
               "<p>pasted</p><!--->#{script}-->", "<p>pasted</p><![CDATA[ >#{script} ]]>",
               "<p>pasted</p><?x >#{script}?>", "<p>pasted</p><?xml ?><textarea><x/>#{script}</textarea>"]
    markups.each do |markup|
      answer = pasted_into_the_text_editor(markup)

      expect(answer).to include('pasted', 'written in the text editor')
      expect(answer).not_to match(/<script[\s>]/i)
      expect(script_types_in_the_text_editor).to be_empty
    end
    expect(script_ran).to be_nil
  end

  # Once a block form has loaded a text editor, jQuery's remove() takes the text editor of an
  # element along, found by the element's id. A pasted script carries whatever id its markup gives
  # it, the id of the post's text editor for one: it is taken out like any other, and that editor
  # stays.
  it 'takes out a pasted script that carries the id of a text editor, and leaves that editor in place' do
    load_a_block_form_text_editor
    id = page.evaluate_script("#{POST_TEXT_EDITOR}.id")

    answer = pasted_into_the_text_editor(script.sub('<script', %(<p>pasted</p><script id="#{id}")))

    expect(answer).to include('pasted', 'written in the text editor')
    expect(answer).not_to include('script')
    expect(page.evaluate_script("!!#{POST_TEXT_EDITOR}")).to be(true)
    expect(script_ran).to be_nil
  end

  # The markup of a paste is read in no document of the page's, with or without a script in it
  # to take out. What a browser makes of markup read in the document of a page runs there: a
  # handler of an image or of a video's source that fails to load, for one, in the editor's
  # window over the admin's page. An element the editor's window defines says, the moment it is
  # made there, whether the markup was read in that document.
  it 'runs no handler of pasted markup' do
    page.execute_script("#{POST_TEXT_EDITOR}.getWin().eval(arguments[0]);", <<~JS)
      customElements.define('cama-pasted-witness', class extends HTMLElement {
        constructor(){ super(); window.__cama_pasted_markup_read = true; }
      });
    JS
    witness = '<p>pasted</p><video><cama-pasted-witness></cama-pasted-witness>' \
              '<source src="x://y" onerror="window.__cama_pasted_handler_ran = true"></video>'

    [witness, witness + script].each do |markup|
      expect(pasted_into_the_text_editor(markup)).to include('pasted', 'written in the text editor')
      expect(script_flag('__cama_pasted_markup_read')).to be_nil
      expect(script_flag('__cama_pasted_handler_ran')).to be_nil
    end
    expect(script_ran).to be_nil
  end

  # A page may set a text editor up with a setup of its own, which takes the place of core's, and
  # with it of the hooks core's setup runs for the plugins; that editor keeps scripts like the
  # others. So every text editor of a page that loads the grid editor has its pastes filtered,
  # keeps a script out of a paragraph and writes its content as the page is being left, whatever
  # it was set up with, a list of block elements of its own included.
  context 'with a text editor set up with a setup and a list of block elements of its own' do
    let(:own_editor) { "tinymce.get('own_editor')" }

    before do
      set_up_text_editors(%w[own_editor], <<~JS)
        cama_get_tinymce_settings({
          selector: selector, setup: function(){}, block_elements: 'p div h1 h2 ul ol li table tr td blockquote'
        })
      JS
    end

    it 'takes the scripts out of markup pasted into it' do
      answer = pasted_into_the_text_editor("<p>pasted</p>#{script}", editor: own_editor)

      expect(answer).to include('pasted', 'written in the text editor')
      expect(answer).not_to include('script')
    end

    it 'leaves a script at the top level of its content where it stands' do
      content = "#{script}<p>written in the text editor</p>"

      expect(with_the_caret_outside_any_block(content, editor: own_editor).delete("\n")).to eq(content)
    end

    it 'writes its content as the page is being left' do
      written = page.evaluate_script(<<~JS, "<p>written in the text editor</p>#{script}")
        (function(markup){
          var editor = #{own_editor};
          window.onbeforeunload = null;
          editor.setContent(markup);
          window.dispatchEvent(new Event('beforeunload'));
          return editor.getElement().value;
        })(arguments[0])
      JS

      expect(written.delete("\n")).to eq("<p>written in the text editor</p>#{script}")
    end
  end
end
