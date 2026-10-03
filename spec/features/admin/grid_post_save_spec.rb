# frozen_string_literal: true

# The post's field has two writers: the grid editor, and the text editor it stands in front of.
# Core has the text editor write its content into the field when it loses focus, with every draft
# and as the form is sent, and the text editor's serialization of a grid is not the grid's export:
# <b> and rgb() are respelled, a newline goes between tags. While the grid editor is the one shown,
# the text editor answers with the grid's export, so the export is what the post stores.
RSpec.describe 'saving a post from the grid editor', :js do
  init_site

  let(:script) { '<script>window.__cama_widget_loaded = true;</script>' }
  let(:stored_content) do
    grid = grid_with_block("<p>embedded widget</p>#{script}<p><b>bold</b></p>",
                           kind: 'editor', attributes: 'style="background-color: rgb(255, 204, 0);"')
    grid_post_content(grid)
  end

  # The stored grid is open in its editor when this returns: an example that reads or changes the
  # grid would otherwise pass over a text editor alone.
  def open_stored_post(as: nil)
    store_post_content(@post, stored_content)
    open_post_in_editor(@post, as: as)
    find('.panel_grid_editor .panel_grid_body .drg_column .drg_item')
  end

  def change_in_the_text_editor(from, to)
    text_editor_holds(text_editor_content.sub(from) { to })
  end

  # A listener of the text editor's that throws at every read of its content, from here until
  # the reads are restored: a listener a plugin adds may, and a switch of editors reads first.
  # `only_plain` spares the reads a save makes, and breaks the plain ones alone.
  def break_the_text_editor_reads(only_plain: false)
    page.execute_script(<<~JS, only_plain)
      var only_plain = arguments[0];
      window.__cama_break_reads = true;
      #{POST_TEXT_EDITOR}.on('GetContent', function(e){
        if(window.__cama_break_reads && !(only_plain && e.save)) throw new Error('the reads are broken');
      });
    JS
  end

  def restore_the_text_editor_reads
    page.execute_script('window.__cama_break_reads = false;')
  end

  context 'with an administrator' do
    before { open_stored_post }

    # On the way back to the text editor its content is read, once the grid editor is hidden. A
    # read that throws leaves the author in the text editor, not before two hidden editors, and
    # where they were: the link goes nowhere, whatever the read does.
    it 'leaves the text editor shown when its content cannot be read on the way back to it' do
      break_the_text_editor_reads
      leave_for_the_text_editor
      restore_the_text_editor_reads

      expect(page).to have_css('.mce-tinymce')
      expect(page).to have_no_css('.panel_grid_editor')
      expect(current_url_fragment).to be_nil
    end

    # Shown again from the text editor, the grid editor reads the text editor's content first: a
    # read that throws is told too, and the author stays in the text editor.
    it 'tells the author when the grid editor cannot be shown again from the text editor' do
      leave_for_the_text_editor
      break_the_text_editor_reads(only_plain: true)
      open_grid_editor
      restore_the_text_editor_reads

      expect(page).to have_css('#cama_alert_modal', text: 'could not be opened')
      expect(page).to have_no_css('.panel_grid_editor')
      expect(page).to have_css('.mce-tinymce')
    end

    # Once the grid is the one shown again, the field is written: a listener of the field's that
    # throws there leaves the grid shown, and the author is not told the grid could not be opened.
    # Core's alert is watched for rather than looked for: its modal comes a moment after the call.
    it 'says nothing false when the field cannot be written once the grid is shown again' do
      leave_for_the_text_editor
      page.execute_script(<<~JS)
        var alert = jQuery.fn.alert;
        jQuery.fn.alert = function(options){ window.__cama_alerts = (window.__cama_alerts || []).concat([options.title]); return alert.apply(this, arguments); };
        jQuery('.panel_grid_editor').next('textarea').on('change', function(){
          if(jQuery('.panel_grid_editor').is(':visible')) throw new Error('the field cannot be written');
        });
      JS
      open_grid_editor

      expect(page).to have_css('.panel_grid_editor')
      expect(page).to have_no_css('.mce-tinymce')
      expect(page.evaluate_script('window.__cama_alerts')).to be_nil
    end

    it 'stores the grid as the grid exported it, a block script included' do
      trigger_grid_auto_save
      export = saved_grid_content
      submit_post_form

      expect(export).to include(script, '<b>bold</b>', 'background-color: rgb(255, 204, 0)')
      expect(post_content).to eq(export)
    end

    it 'stores a post saved with nothing changed as it was' do
      submit_post_form

      expect(post_content).to eq(stored_content)
    end

    # A block or a column the author deletes fades out, and is in the grid until it is gone: the
    # grid is exported without it, and the export is what the post stores.
    it 'stores the grid without a block the author deleted' do
      accept_confirm { page.execute_script("jQuery('.panel_grid_body .drg_item .grid_content_remove').click();") }
      expect(page).to have_no_css('.panel_grid_body .drg_item', visible: :all)
      export = saved_grid_content
      submit_post_form

      expect(export).to include('data-col="6"')
      expect(export).not_to include('embedded widget')
      expect(post_content).to eq(export)
    end

    it 'stores the grid without a column the author deleted' do
      accept_confirm { page.execute_script("jQuery('.panel_grid_body .drg_column .grid_col_remove').click();") }
      expect(page).to have_no_css('.panel_grid_body .drg_column', visible: :all)
      export = saved_grid_content
      submit_post_form

      expect(export).to start_with(grid_post_content('<div class="panel_grid_body row'))
      expect(export).not_to include('data-col=')
      expect(post_content).to eq(export)
    end

    # What was deleted is out of the export from the click on, while it still fades out in the
    # grid: a save sent before the fade ends stores the grid without it. It takes no click
    # meanwhile.
    it 'exports the grid without a deleted block or column at the click, while it still fades out' do
      confirm_every_prompt
      without_block, without_column = page.evaluate_script(<<~JS)
        (function(){
          var seen = function(kind){
            var fading = jQuery('.panel_grid_body .' + kind);
            return [window.__cama_grid_exports.last, fading.length, fading.css('pointer-events')];
          };
          jQuery('.panel_grid_body .drg_item .grid_content_remove').click();
          var without_block = seen('drg_item');
          jQuery('.panel_grid_body .drg_column .grid_col_remove').click();
          return [without_block, seen('drg_column')];
        })()
      JS
      submit_post_form

      expect(without_block[0]).to include('data-col="6"')
      expect(without_block[0]).not_to include('embedded widget')
      expect(without_block[1..]).to eq([1, 'none'])
      expect(without_column[0]).to start_with(grid_post_content('<div class="panel_grid_body row'))
      expect(without_column[0]).not_to include('data-col=')
      expect(without_column[1..]).to eq([1, 'none'])
      expect(post_content).to eq(without_column[0])
    end

    # A listener of the grid's export may throw, a block plugin's among them: what was deleted
    # fades out and goes all the same, its fade under way before the grid is exported. The Delete
    # entry is a link to "#": clicked for real, it still goes nowhere, and the page stays where it was.
    it 'takes a deleted block out of the grid and leaves the page where it was when a listener of the export throws' do
      make_the_grid_export_throw
      open_the_menu_of('.drg_item')
      accept_confirm { find('.panel_grid_body .drg_item .grid_content_remove').click }

      expect(page).to have_no_css('.panel_grid_body .drg_item', visible: :all)
      expect(saved_grid_content).not_to include('embedded widget')
      expect(current_url_fragment).to be_nil
    end

    # The other entries that export the grid are links to "#" as well: Clone of a block or of a
    # column, Delete of a column, Clear. Clicked for real, each goes nowhere all the same. The
    # errors the page reports say that the listener threw at each click, as the example assumes.
    it 'leaves the page where it was whichever entry a listener of the export throws at' do
      make_the_grid_export_throw
      watch_the_page_errors
      open_the_menu_of('.drg_item')
      find('.panel_grid_body .drg_item .grid_content_clone').click
      expect(current_url_fragment).to be_nil

      open_the_menu_of('.drg_column')
      find('.panel_grid_body .drg_column .grid_col_clone').click
      expect(current_url_fragment).to be_nil

      open_the_menu_of('.drg_column')
      accept_confirm { find('.panel_grid_body .drg_column .grid_col_remove').click }
      expect(current_url_fragment).to be_nil

      accept_confirm { find('.grid_editor_menu .clear').click }
      expect(current_url_fragment).to be_nil
      expect(page_errors.length).to eq(4)
    end

    # A column cloned while one of its blocks fades out does not take that block along: the copy
    # would stay in the clone for good, marked as deleted and in no export.
    it 'leaves a deleted block out of a clone of its column' do
      confirm_every_prompt
      page.execute_script(<<~JS)
        jQuery('.panel_grid_body .drg_item .grid_content_remove').click();
        jQuery('.panel_grid_body .drg_column .grid_col_clone').click();
      JS

      expect(page).to have_css('.panel_grid_body .drg_column', count: 2)
      expect(page).to have_no_css('.panel_grid_body .drg_item', visible: :all)
    end

    # A column that fades out is still in the grid, where blocks are dragged from column to column:
    # it takes no block, which would go with it. The fade is slowed down for the drag to end within
    # it, and the drag is seen to start: a block that was never dragged stays where it is too.
    it 'drops no block into a deleted column that still fades out' do
      confirm_every_prompt
      watch_for_a_sort
      page.execute_script(<<~JS)
        jQuery.fx.speeds._default = 60000;
        jQuery('.panel_grid_body .drg_column .grid_col_clone').click();
        jQuery('.panel_grid_body .drg_column').last().find('.grid_col_remove').click();
      JS
      deleted_area = find('.panel_grid_body .drg_column.grid-deleted > .grid_sortable_items').native
      drag_the_first_block(to: deleted_area)

      expect(sort_started).to be(true)
      expect(page).to have_css('.panel_grid_body .drg_column:not(.grid-deleted) .drg_item', count: 1)
      expect(saved_grid_content).to include('embedded widget')
    end

    # The post form writes each text editor's content into its field to tell whether there is
    # anything to save, two seconds after it opens and with every draft; so does a text editor
    # that loses focus.
    def let_core_read_the_text_editors
      page.execute_script(<<~JS)
        jQuery.each(tinymce.editors, function(_index, editor){
          jQuery('#' + editor.id).val(editor.getContent()).trigger('change');
          editor.fire('blur');
        });
      JS
    end

    it 'keeps the export in the field when core reads the text editors' do
      trigger_grid_auto_save
      let_core_read_the_text_editors

      expect(grid_field).to eq(saved_grid_content)
    end

    # The export is the answer to a read of the text editor's content as markup. A read of its
    # text, of its raw body or of a selection asks for something else, and gets the text editor's
    # own answer.
    it "answers a read of its text, of its raw body or of a selection with the text editor's own" do
      trigger_grid_auto_save
      text, raw, selection = page.evaluate_script(<<~JS)
        (function(){
          var editor = #{POST_TEXT_EDITOR};
          editor.selection.select(editor.getBody(), true);
          return [editor.getContent({format: 'text'}), editor.getContent({format: 'raw'}), editor.selection.getContent()];
        })()
      JS

      expect(text).to include('embedded widget')
      expect(text).not_to include('<')
      expect(raw).to include('<strong>bold</strong>', '<script type="mce-no/type">')
      expect(selection).to include('<strong>bold</strong>')
    end

    # The text editor answers with the export while its grid editor is the one shown. A grid
    # editor out of the page - an admin page loaded in place takes the post's form with it - is
    # shown to nobody: the text editor speaks for itself again.
    it 'leaves the text editor to answer for itself once the grid editor is out of the page' do
      page.execute_script("jQuery('.panel_grid_editor').detach();")

      expect(text_editor_content).to include('<strong>bold</strong>')
      expect(text_editor_content).not_to include('<b>bold</b>')
    end

    # A block form loads a text editor of its own through jQuery's tinymce(), and from then on
    # jQuery's val() hands a value to the text editor of a field that has one and leaves the field
    # alone. The grid writes its field itself: the field holds the export whatever was loaded.
    it 'stores the export once a block form has loaded a text editor of its own' do
      load_a_block_form_text_editor
      change_the_grid
      export = saved_grid_content
      field = grid_field
      submit_post_form

      expect(export).to include(script, '<b>changed</b>')
      expect(field).to eq(export)
      expect(post_content).to eq(export)
    end

    # A grid editor is made from what its field holds, and stands for that content until the grid
    # changes. Once a block form has loaded a text editor, jQuery's val() answers for a field with
    # its text editor's serialization: the field itself is read, whenever its grid editor is made.
    it 'stands for the content as it was when a grid editor is made after a block form loaded a text editor' do
      load_a_block_form_text_editor
      page.execute_script(<<~JS, stored_content)
        jQuery('<textarea id="later_field"></textarea>').appendTo('#form-post')[0].value = arguments[0];
        tinymce.init(cama_get_tinymce_settings({selector: '#later_field'}));
      JS
      expect(page).to have_css('.panel_grid_editor + #later_field', visible: :all)

      written = page.evaluate_script(<<~JS)
        (function(){
          tinymce.get('later_field').save();
          return document.getElementById('later_field').value;
        })()
      JS

      expect(written).to eq(stored_content)
    end

    it 'saves the export as the draft' do
      trigger_grid_auto_save
      let_core_read_the_text_editors
      page.execute_script('App_post.save_draft_ajax(function(){});')
      wait_for_ajax

      draft = CamaleonCms::Post.drafts.find_by!(post_parent: @post.id)
      expect(draft.content).to eq(saved_grid_content)
    end

    # Back in the text editor, the author sees and edits the text editor's content: that is what
    # is stored, in the text editor's serialization, with the grid's scripts still in it.
    it 'leaves the save to the text editor once the author went back to it' do
      trigger_grid_auto_save
      leave_for_the_text_editor
      shown = text_editor_content
      submit_post_form

      expect(shown).to include('<strong>bold</strong>', script)
      expect(post_content.delete("\r\n")).to eq(shown)
    end

    # The grid shown again is the grid of what the text editor holds: as it was left when nothing
    # was changed there, made again from the text editor's content when something was.
    context 'when the author comes back to the grid from the text editor' do
      before { leave_for_the_text_editor }

      it 'stores the post as it was when nothing was changed in the text editor' do
        open_grid_editor
        submit_post_form

        expect(post_content).to eq(stored_content)
      end

      it 'makes the grid again from what was changed in the text editor, and stores that' do
        change_in_the_text_editor('bold', 'changed in the text editor')
        changed = text_editor_content
        open_grid_editor

        expect(page).to have_css('.panel_grid_body .drg_item strong', text: 'changed in the text editor', visible: :all)
        expect(page).to have_css('.panel_grid_body .drg_item', count: 1)
        expect(script_flag('__cama_widget_loaded')).to be_nil

        submit_post_form

        expect(changed).to include(script)
        expect(post_content.delete("\r\n")).to eq(changed)
      end

      it 'stores the export of the grid made again once that grid changes' do
        change_in_the_text_editor('bold', 'changed in the text editor')
        open_grid_editor
        find('.panel_grid_body .drg_item strong', text: 'changed in the text editor', visible: :all)
        trigger_grid_auto_save
        export = saved_grid_content
        submit_post_form

        expect(export).to include(script, '<strong>changed in the text editor</strong>')
        expect(post_content.delete("\r")).to eq(export)
      end

      # The root of the grid made again is the root written in the text editor: its attributes, and
      # none the grid had before, the style taken out there included.
      it 'gives the grid made again the root written in the text editor' do
        change_in_the_text_editor(/<div class="panel_grid_body row"[^>]*>/,
                                  '<div id="hero" class="panel_grid_body row wide">')
        open_grid_editor

        expect(page).to have_css('.panel_grid_editor .panel_grid_body#hero.wide.ui-sortable .drg_item')
        expect(page).to have_no_css('.panel_grid_editor .panel_grid_body[style]', visible: :all)

        trigger_grid_auto_save

        expect(saved_grid_content).to include('id="hero"', 'panel_grid_body row wide')
        expect(saved_grid_content).not_to include('background-color')
      end

      it 'keeps the author in the text editor when what was changed there is no longer a grid alone' do
        text_editor_holds("#{text_editor_content}<p>written after the grid</p>")
        changed = text_editor_content
        open_grid_editor

        expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
        expect(page).to have_css('.mce-tinymce')
        expect(page).to have_no_css('.panel_grid_editor')

        close_alert
        submit_post_form

        expect(post_content.delete("\r\n")).to eq(changed)
      end

      # Making the grid again runs the parsers that rebuild a saved grid, and a widget they set up
      # can throw: the grid built earlier comes back whole, its script not run on the way, and the
      # author stays in the text editor.
      it 'keeps the grid built earlier when making it again throws' do
        change_in_the_text_editor('bold', 'changed in the text editor')
        page.execute_script("jQuery.fn.sortable = function(){ throw new Error('widget broke'); };")
        open_grid_editor

        expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
        expect(page).to have_css('.mce-tinymce')
        expect(page).to have_no_css('.panel_grid_editor')
        expect(page).to have_css('.panel_grid_body[style*="background-color"] .drg_item > .header_box',
                                 count: 1, visible: :all)
        expect(page).to have_css('.panel_grid_body .drg_item b', text: 'bold', visible: :all)
        expect(page).to have_css('.panel_grid_body .drg_item script', count: 1, visible: :all)
        expect(script_flag('__cama_widget_loaded')).to be_nil
      end

      # Other content written in the text editor is no grid to make. The grid built earlier comes
      # back as it was left, standing for what it stood for: what the grid shows is what is saved.
      it 'stores the grid, not other content written in the text editor meanwhile' do
        text_editor_holds('<p>written instead of the grid</p>')
        open_grid_editor
        find('.panel_grid_body .drg_item')
        submit_post_form

        expect(post_content).to eq(stored_content)
      end

      # That content is kept for the text editor, whatever the grid hands it meanwhile: going back
      # there brings it back, and there it is what is saved.
      it 'brings other content written in the text editor back there, where it is what is saved' do
        text_editor_holds('<p>written instead of the grid</p>')
        open_grid_editor
        find('.panel_grid_body .drg_item')
        trigger_grid_auto_save
        leave_for_the_text_editor
        shown = text_editor_content
        submit_post_form

        expect(shown).to eq('<p>written instead of the grid</p>')
        expect(post_content).to eq(shown)
      end
    end
  end

  context 'with content that is not a grid, when the text editor cannot be read' do
    let(:stored_content) { '<p>written in the text editor</p>' }

    before do
      store_post_content(@post, stored_content)
      open_post_in_editor(@post)
    end

    # The switch has the text editor write its field before the grid is made, and a listener of
    # the editor's may throw there: the author, who has just answered the prompt, is told, and
    # stays in the text editor.
    it 'tells the author when the switch to the grid editor fails before the grid is made' do
      break_the_text_editor_reads
      open_grid_editor
      restore_the_text_editor_reads

      expect(page).to have_css('#cama_alert_modal', text: 'could not be opened')
      expect(page).to have_no_css('.panel_grid_editor', visible: :all)
      expect(page).to have_css('.mce-tinymce')
    end
  end

  # A grid opened over other content has exported nothing yet: the text editor's content stays what
  # the post stores until the grid's first change.
  context 'with a grid opened over other content' do
    let(:stored_content) { '<p>written in the text editor</p>' }

    before do
      store_post_content(@post, stored_content)
      open_post_in_editor(@post)
      open_grid_editor
      find('.panel_grid_editor .panel_grid_body', visible: :all)
    end

    it 'stores the content of the text editor while the grid has exported nothing' do
      submit_post_form

      expect(post_content).to eq(stored_content)
    end

    it 'stores the export from the first change of the grid on' do
      trigger_grid_auto_save
      export = saved_grid_content
      submit_post_form

      expect(export).to start_with(grid_post_content('<div class="panel_grid_body row'))
      expect(post_content).to eq(export)
    end

    # A detour through the text editor changes nothing about that: the grid has still exported
    # nothing, and what was written in the text editor meanwhile is what the post stores.
    it 'stores what was written in the text editor meanwhile while the grid has exported nothing' do
      leave_for_the_text_editor
      text_editor_holds('<p>written meanwhile</p>')
      open_grid_editor
      find('.panel_grid_editor .grid_editor_menu')
      submit_post_form

      expect(post_content).to eq('<p>written meanwhile</p>')
    end

    # The author who leaves such a grid gets the content from before the grid back in the text
    # editor. A grid written there is then the grid the grid editor shows, and that content is no
    # longer what the text editor goes back to.
    it 'goes back to a grid written in the text editor, not to the content from before the grid' do
      trigger_grid_auto_save
      leave_for_the_text_editor
      handed_back = text_editor_content
      written = grid_post_content(grid_with_block('<p>grid written in the text editor</p>'))
      text_editor_holds(written)
      open_grid_editor
      find('.panel_grid_body .drg_item', visible: :all)
      leave_for_the_text_editor
      shown = text_editor_content
      submit_post_form

      expect(handed_back).to eq(stored_content)
      expect(shown).to eq(written)
      expect(post_content.delete("\r\n")).to eq(written)
    end
  end

  # A post in several languages has one field for each, with a text editor and a grid editor of
  # its own, and core composes what the post stores from them.
  context 'with a post in two languages' do
    let(:stored_content) { { en: grid_in('english'), es: grid_in('spanish') }.to_translate }

    def grid_in(language)
      grid_post_content(grid_with_block("<p>#{language}</p>#{script}<p><b>bold</b></p>", kind: 'editor'))
    end

    before do
      @site.set_meta('languages_site', %w[en es])
      store_post_content(@post, stored_content)
      open_post_in_editor(@post)
      page.assert_selector('.panel_grid_editor .panel_grid_body .drg_item', count: 2, visible: :all)
    end

    it 'stores a post saved with nothing changed as it was' do
      submit_post_form

      expect(post_content).to eq(stored_content)
    end

    def change_the_english_grid
      page.execute_script(<<~JS)
        var english = jQuery('.panel_grid_editor').first();
        english.find('.panel_grid_body .drg_item b').text('changed');
        english.trigger('auto_save');
      JS
    end

    it 'stores the export of the changed language, and the other language as it was' do
      change_the_english_grid
      export = saved_grid_content
      submit_post_form

      expect(export).to include('<p>english</p>', script, '<b>changed</b>')
      expect(post_content).to eq({ en: export, es: grid_in('spanish') }.to_translate)
    end

    # As the page is being left, each text editor's own write would put its raw body into its
    # field: its own markup, a script under the type the editor holds it with. On a page that is
    # not left after all - the author stays at the prompt about unsaved changes - the next change
    # of a grid has core compose from the fields. Each editor writes its content there instead, so
    # the fields hold content. Core's prompt is taken off: up to 2.9.4 it wrote the fields itself
    # as it compared the form.
    it 'stores the other language as it was after a leave of the page that did not happen' do
      page.execute_script("window.onbeforeunload = null; window.dispatchEvent(new Event('beforeunload'));")
      change_the_english_grid
      export = saved_grid_content
      submit_post_form

      expect(post_content).to eq({ en: export, es: grid_in('spanish') }.to_translate)
    end

    # Core composes what the post sends when a field says it changed, which a text editor does
    # when it loses focus. An editor that takes over from the other does not wait for that: the
    # field is written, and says so, then.
    it 'has the post send the text editor version once the author went back to it' do
      leave_for_the_text_editor

      expect(composed_content).to include('<strong>bold</strong>', grid_in('spanish'))
    end

    it 'has the post send the grid made again from what was changed in the text editor' do
      leave_for_the_text_editor
      change_in_the_text_editor('bold', 'changed in the text editor')
      open_grid_editor
      find('.panel_grid_body .drg_item strong', text: 'changed in the text editor', visible: :all)

      expect(composed_content).to include('<strong>changed in the text editor</strong>', grid_in('spanish'))

      submit_post_form

      expect(post_content).to include('<strong>changed in the text editor</strong>', grid_in('spanish'))
    end
  end

  # Core refuses a script from a role it does not trust with unfiltered HTML, and rewrites nothing.
  # The text editor used to take the script out on the way, so the save went through without it.
  context 'with an author core does not trust with unfiltered HTML' do
    # The grid's marker is a shortcode, so saving a grid takes core's shortcode permission as well.
    before do
      post_type = [@post.post_type.id.to_s]
      grants = { Plugins::CamaleonEditor::MainHelper::PERMISSION_USE => 1, content_shortcodes: 1 }
      author = user_with_manager_grants(grants, 'grid-author',
                                        post_type_meta: { edit: post_type, edit_other: post_type,
                                                          edit_publish: post_type })
      open_stored_post(as: author)
    end

    it 'refuses a changed grid that holds a script, and leaves the post as it was' do
      change_the_grid
      submit_post_form

      expect(page).to have_css('.alert-danger', text: /script/i)
      expect(post_content).to eq(stored_content)
    end

    it 'stores a changed grid once the script is out of it' do
      page.execute_script("jQuery('.panel_grid_body .drg_item script').remove();")
      change_the_grid
      export = saved_grid_content
      submit_post_form

      expect(export).to include('<b>changed</b>')
      expect(export).not_to include('<script')
      expect(post_content).to eq(export)
    end

    # The text editor's version of a grid is changed content to core, and still holds the script.
    it 'refuses the text editor version of a grid that holds a script, and leaves the post as it was' do
      leave_for_the_text_editor
      submit_post_form

      expect(page).to have_css('.alert-danger', text: /script/i)
      expect(post_content).to eq(stored_content)
    end
  end
end
