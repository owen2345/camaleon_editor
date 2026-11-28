# frozen_string_literal: true

# A text editor removes the scripts from its content. The scripts of a grid are content for the
# public page, and the grid editor gives its export to the text editor behind it. A grid that went
# through the text editor lost its scripts. For this reason, the plugin makes the text editors keep
# scripts as they keep other valid elements: in the document under a type that a browser does not
# run, and returned under their own type with their text unchanged. This applies to all markup: a
# grid, other content, and markup that a script inserts at the caret. A paste is different: its
# markup can come from any page, and the plugin removes its scripts.
RSpec.describe 'scripts in the text editor', :js do
  init_site

  let(:script) { '<script>window.__cama_widget_loaded = 1 < 2 && true;</script>' }
  let(:stored_content) { nil }
  # A script whose text holds a no-break space. The editor marks that character while it shows
  # invisible characters.
  let(:text_with_a_no_break_space) { "var name =\u00a0'A B';" }
  let(:content_with_a_no_break_space) do
    "<p>written in the text editor</p><script>#{text_with_a_no_break_space}</script>"
  end

  before do
    store_post_content(@post, stored_content) if stored_content
    open_post_in_editor(@post)
  end

  # The content that a text editor returns after it gets the markup, and after `inserted` goes in at
  # the caret. The default editor is the text editor of the post.
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

  # The types under which the text editor holds the scripts of its content.
  def script_types_in_the_text_editor
    page.evaluate_script(<<~JS)
      jQuery.map(#{POST_TEXT_EDITOR}.getBody().getElementsByTagName('script'), function(script){
        return script.type;
      })
    JS
  end

  # The content that a text editor returns after a paste of the markup. The default editor is the
  # text editor of the post.
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

  # The content that a text editor returns after it gets the markup and its caret moves outside all
  # blocks, to the start of the content.
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

  # The editor does not read the text of a script as markup. The text comes back character for
  # character, under the type of the script.
  it "gives back a script's text as it was, under its own type" do
    data = %(<script type="application/ld+json">{\n  "name": "A & B <c>",\n  "url": "https://example.invalid/?a=1&b=2"\n}</script>)
    template = '<script id="row" type="text/template"><tr class="row"><td>{{ name }}</td></tr></script>'
    code = "<script>\n  if (1 < 2 && window.__cama_widget_loaded) {\n\tgo('</p>');   \n  }\n</script>"

    expect(through_the_text_editor("#{data}#{template}#{code}")).to eq([data, template, code].join("\n"))
    expect(script_types_in_the_text_editor).to eq(%w[mce-application/ld+json mce-text/template mce-no/type])
    expect(script_ran).to be_nil
  end

  # A plugin of the editor can mark text in the document with its own elements (for example, a
  # visible no-break space). The editor removes them when its content is read, but not in a script.
  # The grid editor plugin removes them there: a script comes back with only its text. The plugin also
  # removes the marks from each script of the document when the editor stores an undo level (see the
  # next example). For this reason, the example shows the characters with no level stored, so that the
  # marks stay in the script.
  it "gives back a script's text as it was while the editor shows invisible characters" do
    marked, shown, hidden = page.evaluate_script(<<~JS, content_with_a_no_break_space)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent(markup);
        editor.undoManager.ignore(function(){ editor.execCommand('mceVisualChars'); });
        var marked = editor.getBody().querySelectorAll('script .mce-nbsp').length;
        var shown = editor.getContent();
        editor.execCommand('mceVisualChars');
        return [marked, shown, editor.getContent()];
      })(arguments[0])
    JS

    expect(marked).to eq(1)
    expect(shown.delete("\n")).to eq(content_with_a_no_break_space)
    expect(hidden.delete("\n")).to eq(content_with_a_no_break_space)
  end

  # An undo level holds the markup of the editor's document, not a read of the content. When the
  # editor writes a level back, it reads the content of a script as text, and the marks in a script
  # then become part of its text. The plugin removes the marks from each script before the editor
  # stores a level.
  it "gives back a script's text as it was after an undo while the editor shows invisible characters" do
    undone, text = page.evaluate_script(<<~JS, content_with_a_no_break_space)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent(markup);
        editor.undoManager.clear();
        editor.undoManager.add();
        editor.execCommand('mceVisualChars');
        editor.selection.select(editor.getBody().firstChild, true);
        editor.selection.collapse(false);
        editor.insertContent(' and edited');
        editor.undoManager.undo();
        return [editor.getContent(), editor.getBody().querySelector('script').textContent];
      })(arguments[0])
    JS

    expect(undone.delete("\n")).to eq(content_with_a_no_break_space)
    expect(text).to eq(text_with_a_no_break_space)
  end

  # A redo also writes a level back. The editor stores the level of a change while the marks are in
  # the script, and the plugin removes them from the script before the editor stores it.
  it "gives back a script's text as it was after a redo while the editor shows invisible characters" do
    redone, text = page.evaluate_script(<<~JS, content_with_a_no_break_space)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent(markup);
        editor.undoManager.clear();
        editor.undoManager.add();
        editor.undoManager.ignore(function(){ editor.execCommand('mceVisualChars'); });
        editor.selection.select(editor.getBody().firstChild, true);
        editor.selection.collapse(false);
        editor.insertContent(' and edited');
        editor.undoManager.undo();
        editor.undoManager.redo();
        return [editor.getContent(), editor.getBody().querySelector('script').textContent];
      })(arguments[0])
    JS

    expect(redone.delete("\n")).to eq(content_with_a_no_break_space.sub('</p>', ' and edited</p>'))
    expect(text).to eq(text_with_a_no_break_space)
  end

  # The editor makes some changes in two steps, with an undo level for each step: for example, a
  # link pasted over a selection is first pasted as text and then made a link. The editor does the
  # second step only if the first step stored its level. The plugin removes the marks from the
  # scripts and the first step still stores its level, so the second step is done too.
  it 'does the second step of a two-step change while a script holds the marks of invisible characters' do
    marked, changed, levels = page.evaluate_script(<<~JS, content_with_a_no_break_space)
      (function(markup){
        var editor = #{POST_TEXT_EDITOR};
        editor.setContent(markup);
        editor.undoManager.clear();
        editor.undoManager.add();
        editor.undoManager.ignore(function(){ editor.execCommand('mceVisualChars'); });
        var marked = editor.getBody().querySelectorAll('script *').length;
        editor.undoManager.extra(function(){ editor.insertContent('first '); },
                                 function(){ editor.insertContent('second '); });
        return [marked, editor.getContent(), editor.undoManager.data.length];
      })(arguments[0])
    JS

    expect(marked).to eq(1)
    expect(changed.delete("\n")).to eq(content_with_a_no_break_space.sub('<p>', '<p>second '))
    expect(levels).to eq(3)
  end

  # The attributes of a script come back as the editor writes all attributes: each with a value, in
  # double quotes, in the same sequence.
  it "gives back a script's attributes in the editor's spelling" do
    written = "<script async src='https://example.invalid/w.js?a=1&b=2' data-id=w1 defer></script>"

    expect(through_the_text_editor(written))
      .to eq('<script async="" src="https://example.invalid/w.js?a=1&amp;b=2" data-id="w1" defer="defer"></script>')
  end

  # TinyMCE ends a script at the first closing tag, or at a tag that only starts like one. A browser
  # reads the text of a script differently. "<!--" starts a comment, and "<script" in that comment
  # starts a second script. The next closing tag then ends the second script, not the element. An
  # old technique hides a script in a comment and writes a second script from it. The plugin gives
  # the editor the rule of a browser: the full script comes back, and the markup after it stays
  # content.
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

  # Outside such a comment, the first closing tag ends the script, also for a browser. A script that
  # writes an unescaped closing tag ends there, and the remainder is content.
  it 'ends a script at the first closing tag outside a comment of its text, as a browser does' do
    answer = through_the_text_editor(%q(<script>document.write('<script src="/w.js"></script>');</script><p>after</p>))

    expect(answer.delete("\n")).to eq(%q(<script>document.write('<script src="/w.js"></script><p>');</p><p>after</p>))
  end

  # A script with no end contains all the markup after it, also for a browser. Here the closing tag
  # ends the second script in the comment, and the markup after it is still script text.
  it 'reads a script that nothing ends up to the end of the content, as a browser does' do
    content = '<p>before</p><script><!-- <script> </script><b>after</b>'

    expect(through_the_text_editor(content).delete("\n")).to eq("#{content}</script>")
    expect(script_types_in_the_text_editor).to eq(['mce-no/type'])
  end

  # The page break plugin of the editor works on the content as a string. It replaces each page break
  # separator with the markup of its placeholder image, also in the text of a script or a text area
  # and in an attribute value. The grid editor plugin hides each separator from the plugin, and makes
  # the placeholder image only where the separator is a page break. Each other separator comes back
  # as it was written.
  context 'with page break separators' do
    def separator
      '<!-- pagebreak -->'
    end

    def paging_text
      "var pages = text.split('#{separator}');"
    end

    # A page break between two paragraphs, and a script whose text holds the separator. The editor
    # returns the page break in a paragraph.
    def content
      "<p>first page</p>#{separator}<p>second page</p><script>#{paging_text}</script>"
    end

    def returned
      "<p>first page</p><p>#{separator}</p><p>second page</p><script>#{paging_text}</script>"
    end

    # The markup of the placeholder image that the page break plugin writes.
    def placeholder
      page.evaluate_script(<<~JS)
        '<img src="' + tinymce.Env.transparentSrc + '" class="mce-pagebreak" data-mce-resize="false" data-mce-placeholder />'
      JS
    end

    # The number of placeholder images in the document of the post's text editor, and the text of its
    # script.
    def page_breaks_and_script_text
      page.evaluate_script(<<~JS)
        (function(){
          var body = #{POST_TEXT_EDITOR}.getBody(), script = body.querySelector('script');
          return [body.querySelectorAll('img.mce-pagebreak').length, script && script.text];
        })()
      JS
    end

    it "gives back the separator in a script's text, and a page break outside the script" do
      expect(through_the_text_editor(content).delete("\n")).to eq(returned)
      expect(page_breaks_and_script_text).to eq([1, paging_text])
    end

    it 'makes a page break in the text of a paragraph' do
      in_a_paragraph = "<p>first page#{separator}second page</p>"

      expect(through_the_text_editor(in_a_paragraph).delete("\n")).to eq(in_a_paragraph)
      expect(page_breaks_and_script_text).to eq([1, nil])
    end

    # An undo writes the markup of an undo level back into the editor. The page break plugin replaces
    # the separator in that markup too.
    it "gives back the separator in a script's text after an undo" do
      undone = page.evaluate_script(<<~JS, content)
        (function(markup){
          var editor = #{POST_TEXT_EDITOR};
          editor.setContent(markup);
          editor.undoManager.clear();
          editor.undoManager.add();
          editor.selection.select(editor.getBody().firstChild, true);
          editor.selection.collapse(false);
          editor.insertContent(' and edited');
          editor.undoManager.undo();
          return editor.getContent();
        })(arguments[0])
      JS

      expect(undone.delete("\n")).to eq(returned)
      expect(page_breaks_and_script_text).to eq([1, paging_text])
    end

    it 'gives back the separator in the text of a script put in at the caret' do
      answer = through_the_text_editor('<p>written in the text editor</p>', inserted: content)

      expect(answer.delete("\n")).to include("<script>#{paging_text}</script>", "<p>#{separator}</p>")
      expect(page_breaks_and_script_text).to eq([1, paging_text])
    end

    # The plugin finds the separator in each letter case. A script keeps the separator as it was
    # written. A page break comes back as the settings spell the separator.
    it "keeps the letter case of the separator in a script's text" do
      written = content.sub(separator, '<!-- PageBreak -->').sub(paging_text, paging_text.upcase)

      expect(through_the_text_editor(written).delete("\n")).to eq(returned.sub(paging_text, paging_text.upcase))
      expect(page_breaks_and_script_text).to eq([1, paging_text.upcase])
    end

    # The text of a script can hold the markup of the placeholder image itself. That text is not a
    # page break, and it stays as it is.
    it "keeps the markup of the placeholder image in a script's text" do
      kept = "<p>first page</p><script>var image = '#{placeholder}';</script>"

      expect(through_the_text_editor(kept).delete("\n")).to eq(kept)
      expect(page_breaks_and_script_text.first).to eq(0)
    end

    # In an attribute value, the quotes of the placeholder markup ended the value and made more
    # attributes. In a text area, the markup stayed text.
    it 'gives back the separator in an attribute value and in the text of a text area' do
      markup = "<p title=\"before #{separator} after\">first page</p><textarea>#{separator}</textarea>"
      kept = page.evaluate_script(<<~JS, markup)
        (function(markup){
          var editor = #{POST_TEXT_EDITOR};
          editor.setContent(markup);
          var body = editor.getBody();
          return [body.querySelector('p').getAttribute('title'), body.querySelector('p').attributes.length,
                  body.querySelector('textarea').value, body.querySelectorAll('img').length];
        })(arguments[0])
      JS

      expect(kept).to eq(["before #{separator} after", 1, separator, 0])
    end

    # The parser of the editor keeps some attribute names that setAttribute() of an older browser
    # refuses, for example a name that starts with a digit. The example makes setAttribute() refuse
    # such a name, as that browser does.
    it 'gives back the separator in an attribute whose name setAttribute() refuses' do
      markup = "<p 1x=\"before #{separator} after\">first page</p>"
      answer = page.evaluate_script(<<~JS, markup)
        (function(markup){
          var editor = #{POST_TEXT_EDITOR}, element = editor.getWin().Element.prototype, set = element.setAttribute;
          element.setAttribute = function(name){
            if(/^[^A-Za-z_:]/.test(name)) throw new DOMException('refused', 'InvalidCharacterError');
            return set.apply(this, arguments);
          };
          try { editor.setContent(markup); } catch(error) { return error.name; } finally { element.setAttribute = set; }
          return editor.getContent();
        })(arguments[0])
      JS

      expect(answer.delete("\n")).to eq('<p 1x="before &lt;!-- pagebreak --&gt; after">first page</p>')
    end

    # A write of a tree of nodes gets a SetContent and no BeforeSetContent. Here such a write comes
    # in the middle of another write.
    it 'gives back the separator after a write of a tree in the middle of a write' do
      answer = page.evaluate_script(<<~JS, content)
        (function(markup){
          var editor = #{POST_TEXT_EDITOR}, first = true;
          editor.on('BeforeSetContent', function(){
            if(!first) return;
            first = false;
            editor.setContent(editor.parser.parse('<p>a tree</p>'));
          });
          editor.setContent(markup);
          return editor.getContent();
        })(arguments[0])
      JS

      expect(answer.delete("\n")).to eq(returned)
      expect(page_breaks_and_script_text).to eq([1, paging_text])
    end

    # A page can give a text editor its own separator. A script then gets that separator back.
    it "gives back the page's own separator in a script's text" do
      own_separator = '<!-- next page -->'
      set_up_text_editors(%w[own_separator], <<~JS)
        cama_get_tinymce_settings({selector: selector, pagebreak_separator: '#{own_separator}'})
      JS

      answer = through_the_text_editor(content.gsub(separator, own_separator), editor: "tinymce.get('own_separator')")

      expect(answer.delete("\n")).to eq(returned.gsub(separator, own_separator))
    end

    # An editor without the page break plugin makes no page break. The separator stays a comment of
    # the content, and the text of a script stays as it is.
    it 'leaves the separators as they are in an editor without the page break plugin' do
      set_up_text_editors(%w[no_page_breaks], '{selector: selector}')

      answer = through_the_text_editor(content, editor: "tinymce.get('no_page_breaks')")

      expect(answer.delete("\n")).to eq(content)
    end
  end

  # The plugin adds the script element to the list of valid elements of each text editor. The source
  # of the list does not matter. It can be the default of core, or a list that the page gives to the
  # settings of core or adds later. It can also be in settings that are not from core.
  context "with text editors set up with settings of the page's own" do
    # The list of valid elements of the text editor with this field id.
    def list_of(id)
      page.evaluate_script("tinymce.get('#{id}').settings.extended_valid_elements")
    end

    # The plugin does not change the settings object of a page, for any number of editors that the
    # page sets up with it. It also does not change the defaults of core.
    it "adds the script to a page's own list for each editor, and to the default one otherwise" do
      # Keep a reference to the settings object of the page, to read it after the editors are ready.
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

    # A rule for the script element in the lists of a page stays in effect, also a narrower rule.
    # The editor uses the last rule that it gets for an element. For this reason, the plugin adds no
    # rule after it, and a script comes back with the attributes that the page permits. A rule for
    # all elements ("*[...]") is not a script rule: the plugin still adds the script element after
    # it.
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

  # Before the page unloads, a text editor writes its content into its field. TinyMCE's own write
  # puts the raw content there, with each script under the type that the editor gives it.
  # grid_post_save_spec shows what a page then sends if the author cancels the unload. An editor
  # that TinyMCE hid, so that the author can edit its field, writes nothing.
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

  # When the caret moves outside all blocks, the editor puts each top-level node of its content into
  # a paragraph. It does not do this if the block element map has the name of the node. The map has
  # the script name: a script stays in its position.
  it 'leaves a script at the top level of the content where it stands' do
    content = "#{script}<p>written in the text editor</p>"

    expect(with_the_caret_outside_any_block(content).delete("\n")).to eq(content)
  end

  # After the editor inserts markup at the caret, it puts the caret after the last content of the
  # markup. To find that content, it steps back across the blocks. It steps across a script with a
  # src at the end of the markup: the next text that the author types goes before the script, not
  # after it.
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

  # The search of the editor ignores the text of an element that shows no text (for example, a
  # script). This applies only if the element is not a block. The plugin keeps a script out of a
  # paragraph and does not make it a block for the search: the search does not find the script text,
  # and Replace does not change it.
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

  # The post's text editor gets the stored content when the form opens, and writes its content into
  # the field at submit. A post that is not a grid keeps its script, in the same position, through
  # the two steps.
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

  # The markup of a paste can come from any page, and a pasted script stays in the editor where the
  # author does not see it. For this reason, the plugin removes the scripts from pasted markup. This
  # includes markup that says it was copied in the editor, because any markup can say that.
  # - The plugin finds the scripts as the editor reads the markup. A browser reads some markup
  #   differently and finds no script there. Examples are a script after a plaintext tag or an
  #   incomplete tag, and a script in a template. A third example is a script in a comment that a
  #   noscript, an svg style or a video ends early for the editor (the media plugin reads a video as
  #   raw text).
  # - The editor reads a comment or a CDATA section to its end. A browser can end it at the first
  #   ">" ("<!--->", "<![CDATA[ >") and read a script after it.
  # - The editor writes a processing instruction "<?xml ?>" as "<?xml?>", and its next read
  #   continues to the first "/>", one tag too far. A script in the text of a textarea after it then
  #   becomes a script.
  # - A comment, a CDATA section and a processing instruction are not content: a paste that spells a
  #   script loses them. A processing instruction with text ("<?x >…") comes back with the text
  #   encoded and hides no script. The example pastes one to prove that.
  # - The plugin reads the markup after the filters of the paste plugin. In a WebKit browser, the
  #   filter that removes style attributes from tags can make a script tag from a tag that spelled
  #   none.
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

  # After a script loads a text editor through jQuery's tinymce(), jQuery's remove() also removes
  # the text editor that has the id of a removed element. A pasted script can have any id (for
  # example, the id of the post's text editor). The plugin removes that script, and the editor stays.
  it 'takes out a pasted script that carries the id of a text editor, and leaves that editor in place' do
    load_a_text_editor_through_jquery
    id = page.evaluate_script("#{POST_TEXT_EDITOR}.id")

    answer = pasted_into_the_text_editor(script.sub('<script', %(<p>pasted</p><script id="#{id}")))

    expect(answer).to include('pasted', 'written in the text editor')
    expect(answer).not_to include('script')
    expect(page.evaluate_script("!!#{POST_TEXT_EDITOR}")).to be(true)
    expect(script_ran).to be_nil
  end

  # The plugin does not parse pasted markup in a document of the page, with or without a script to
  # remove. Markup that a browser parses in a document of the page can run code there. For example,
  # the error handler of a video source that does not load runs in the window of the editor, on the
  # admin page. The example defines a custom element in the window of the editor: its constructor
  # records a parse of the markup in that document.
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

  # A page can set up a text editor with its own setup. That setup replaces the setup of core, and
  # with it the hooks that core runs for plugins. That editor still keeps scripts. For this reason,
  # the plugin attaches its hooks to each text editor of a page that loads the grid editor. Each
  # editor filters its pastes, keeps a script out of a paragraph and writes its content before the
  # page unloads. This applies with all settings, also with its own list of block elements.
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
