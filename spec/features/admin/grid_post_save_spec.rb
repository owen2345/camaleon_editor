# frozen_string_literal: true

# The post's field has two writers: the grid editor, and the text editor behind it. Core writes the
# content of the text editor into the field when it loses focus, with each draft and at submit. The
# text editor does not serialize a grid as the grid editor exports it: it changes <b> and rgb(), and
# adds a newline between tags. While the grid editor is visible, the text editor returns the grid
# export, and the post stores the export.
RSpec.describe 'saving a post from the grid editor', :js do
  init_site

  let(:script) { '<script>window.__cama_widget_loaded = true;</script>' }
  let(:stored_content) do
    grid = grid_with_block("<p>embedded widget</p>#{script}<p><b>bold</b></p>",
                           kind: 'editor', attributes: 'style="background-color: rgb(255, 204, 0);"')
    grid_post_content(grid)
  end

  # Returns after the grid editor shows the stored grid. Without the wait, an example that reads or
  # changes the grid can pass with only a text editor on the page.
  def open_stored_post(as: nil)
    store_post_content(@post, stored_content)
    open_post_in_editor(@post, as: as)
    find('.panel_grid_editor .panel_grid_body .drg_column .drg_item')
  end

  def change_in_the_text_editor(from, to)
    text_editor_holds(text_editor_content.sub(from) { to })
  end

  # Adds a listener that throws an error at each read of the text editor's content, until
  # restore_the_text_editor_reads. A plugin listener can do this, and a switch of editors reads
  # first. With `only_plain`, the reads of a save work and only the plain reads fail.
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

    # The switch back to the text editor hides the grid editor and then reads the text editor's
    # content. If the read throws an error, the author sees the text editor, not two hidden editors.
    # The page also stays in position: the browser does not follow the link.
    it 'leaves the text editor shown when its content cannot be read on the way back to it' do
      break_the_text_editor_reads
      leave_for_the_text_editor
      restore_the_text_editor_reads

      expect(page).to have_css('.mce-tinymce')
      expect(page).to have_no_css('.panel_grid_editor')
      expect(current_url_fragment).to be_nil
    end

    # If the document of the text editor changed, the grid editor reads the text editor's content
    # before it shows again. If that read throws an error, the author gets a message and stays in
    # the text editor.
    it 'tells the author when the grid editor cannot be shown again from the text editor' do
      leave_for_the_text_editor
      change_in_the_text_editor('bold', 'changed in the text editor')
      break_the_text_editor_reads(only_plain: true)
      open_grid_editor
      restore_the_text_editor_reads

      expect(page).to have_css('#cama_alert_modal', text: 'could not be opened')
      expect(page).to have_no_css('.panel_grid_editor')
      expect(page).to have_css('.mce-tinymce')
    end

    # If the document of the text editor did not change, the grid editor does not read its content.
    # The broken read does not occur, the grid shows, and the post is stored unchanged.
    it 'shows the grid again without reading a text editor whose document did not change' do
      leave_for_the_text_editor
      break_the_text_editor_reads(only_plain: true)
      open_grid_editor
      restore_the_text_editor_reads

      expect(page).to have_css('.panel_grid_editor')
      expect(page).to have_no_css('body.modal-open')
      submit_post_form
      expect(post_content).to eq(stored_content)
    end

    # After the grid editor shows again, it writes the field. If a field listener throws an error
    # then, the grid editor stays visible and the author gets no "could not be opened" message.
    it 'says nothing false when the field cannot be written once the grid is shown again' do
      leave_for_the_text_editor
      page.execute_script(<<~JS)
        jQuery('.panel_grid_editor').next('textarea').on('change', function(){
          if(jQuery('.panel_grid_editor').is(':visible')) throw new Error('the field cannot be written');
        });
      JS
      open_grid_editor

      expect(page).to have_css('.panel_grid_editor')
      expect(page).to have_no_css('.mce-tinymce')
      expect(page).to have_no_css('body.modal-open')
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

    # A deleted block or column fades out, and stays in the grid until the fade ends. The export
    # does not include it, and the post stores the export.
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

    # The export at the click already excludes the deleted element, while it still fades out. A save
    # before the end of the fade stores the grid without it. The element gets no clicks during the
    # fade.
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

    # An export listener (for example, of a block plugin) can throw an error. The deleted element
    # still fades out and goes, because the fade starts before the export. The Delete entry is a
    # link to "#": after a real click, the browser does not follow it and the page does not move.
    it 'takes a deleted block out of the grid and leaves the page where it was when a listener of the export throws' do
      make_the_grid_export_throw
      open_the_menu_of('.drg_item')
      accept_confirm { find('.panel_grid_body .drg_item .grid_content_remove').click }

      expect(page).to have_no_css('.panel_grid_body .drg_item', visible: :all)
      expect(saved_grid_content).not_to include('embedded widget')
      expect(current_url_fragment).to be_nil
    end

    # The other entries that export the grid are also links to "#": Clone of a block or column,
    # Delete of a column, and Clear. After a real click, the browser follows none of them. The page
    # errors prove that the listener threw an error at each click.
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

    # The Settings entries of a block and of the grid open a modal and export nothing. They are also
    # links to "#", and the browser does not follow them when the modal cannot open. The page errors
    # prove that the modal threw an error at each click.
    it 'leaves the page where it was when the style settings cannot be opened' do
      page.execute_script("window.open_modal = function(){ throw new Error('modal broke'); };")
      watch_the_page_errors
      open_the_menu_of('.drg_item')
      find('.panel_grid_body .drg_item a.grid_style_settings').click
      expect(current_url_fragment).to be_nil

      open_grid_style_settings
      expect(current_url_fragment).to be_nil
      expect(page_errors.length).to eq(2)
    end

    # A clone of a column does not include a block that fades out. A copy of that block cannot fade
    # out, and no export includes it.
    it 'leaves a deleted block out of a clone of its column' do
      confirm_every_prompt
      page.execute_script(<<~JS)
        jQuery('.panel_grid_body .drg_item .grid_content_remove').click();
        jQuery('.panel_grid_body .drg_column .grid_col_clone').click();
      JS

      expect(page).to have_css('.panel_grid_body .drg_column', count: 2)
      expect(page).to have_no_css('.panel_grid_body .drg_item', visible: :all)
    end

    # A column that fades out is still in the grid, but it accepts no block: a dropped block goes
    # with the column. The example slows the fade, so that the drag ends during it. It also asserts
    # that the sort started: a block that nobody drags also stays in its column.
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

    # The post form writes the content of each text editor into its field to find unsaved changes:
    # two seconds after it opens, and with each draft. A text editor that loses focus does the same.
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

    # The text editor returns the export only for a read of its content as HTML. A read of its text,
    # its raw content or a selection gets the text editor's own result.
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

    # The text editor returns the export while its grid editor is visible. A grid editor that is not
    # in the page is not visible (a page loaded in place removes the post form). The text editor
    # then returns its own content again.
    it 'leaves the text editor to answer for itself once the grid editor is out of the page' do
      page.execute_script("jQuery('.panel_grid_editor').detach();")

      expect(text_editor_content).to include('<strong>bold</strong>')
      expect(text_editor_content).not_to include('<b>bold</b>')
    end

    # A block form loads its own text editor through jQuery's tinymce(). After that, jQuery's val()
    # gives a value to the text editor of a field and does not change the field. The grid editor
    # writes its field directly, and the field always holds the export.
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

    # A grid editor builds its grid from the value of its field, and a save stores that value until
    # the grid changes. After a block form loads a text editor, jQuery's val() returns the text
    # editor's serialization for a field. The grid editor reads the field itself.
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

    # In the text editor, the author sees and edits the text editor's content. A save stores that
    # content, as the text editor serializes it, with the scripts of the grid.
    it 'leaves the save to the text editor once the author went back to it' do
      trigger_grid_auto_save
      leave_for_the_text_editor
      shown = text_editor_content
      submit_post_form

      expect(shown).to include('<strong>bold</strong>', script)
      expect(post_content.delete("\r\n")).to eq(shown)
    end

    # The grid that shows again agrees with the text editor. With no changes there, it is the grid
    # as the author left it. With changes, the grid is built again from that content.
    context 'when the author comes back to the grid from the text editor' do
      before { leave_for_the_text_editor }

      it 'stores the post as it was when nothing was changed in the text editor' do
        open_grid_editor
        submit_post_form

        expect(post_content).to eq(stored_content)
      end

      # The grid editor compares the document of the text editor first, because a read of the
      # content costs more. A bogus element of the editor changes the document, not the content.
      it 'stores the post as it was when only a mark of the text editor changed' do
        page.execute_script(<<~JS)
          #{POST_TEXT_EDITOR}.getBody().firstChild.insertAdjacentHTML('afterbegin', '<span data-mce-bogus="1"></span>');
        JS
        open_grid_editor
        submit_post_form

        expect(post_content).to eq(stored_content)
      end

      # The grid editor compares the markup of the document itself. TinyMCE's raw format removes a
      # selection attribute also from text that spells one, and then does not show such a change.
      it 'makes the grid again from text changed to spell a mark of the editor' do
        page.execute_script(<<~JS)
          var editor = #{POST_TEXT_EDITOR};
          editor.getBody().querySelector('p').appendChild(editor.getDoc().createTextNode(' data-mce-selected="1"'));
        JS
        open_grid_editor
        submit_post_form

        expect(post_content).to include('embedded widget data-mce-selected="1"')
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

      # The rebuilt grid gets the root that the author wrote in the text editor, with those
      # attributes only. The old style, which the author removed there, does not come back.
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

      # A rebuild runs the parsers of a stored grid, and a widget that they set up can throw an
      # error. Then the previous grid comes back complete, with its old root (the rebuild already
      # replaced it) and with its script not run. The author stays in the text editor.
      it 'keeps the grid built earlier when making it again throws' do
        change_in_the_text_editor('bold', 'changed in the text editor')
        change_in_the_text_editor(/<div class="panel_grid_body row"[^>]*>/,
                                  '<div id="hero" class="panel_grid_body row wide">')
        page.execute_script("jQuery.fn.sortable = function(){ throw new Error('widget broke'); };")
        open_grid_editor

        expect(page).to have_css('#cama_alert_modal', text: 'could not be read as a grid')
        expect(page).to have_css('.mce-tinymce')
        expect(page).to have_no_css('.panel_grid_editor')
        expect(page).to have_css('.panel_grid_body.ui-sortable[style*="rgb(255, 204, 0)"] .drg_item > .header_box',
                                 count: 1, visible: :all)
        expect(page).to have_no_css('.panel_grid_body#hero, .panel_grid_body.wide', visible: :all)
        expect(page).to have_css('.panel_grid_body .drg_item b', text: 'bold', visible: :all)
        expect(page).to have_css('.panel_grid_body .drg_item script', count: 1, visible: :all)
        expect(script_flag('__cama_widget_loaded')).to be_nil
      end

      # Content that is not a grid gives no grid to build. The grid comes back as the author left
      # it, and a save stores the grid.
      it 'stores the grid, not other content written in the text editor meanwhile' do
        text_editor_holds('<p>written instead of the grid</p>')
        open_grid_editor
        find('.panel_grid_body .drg_item')
        submit_post_form

        expect(post_content).to eq(stored_content)
      end

      # The grid editor keeps that content for the text editor, although the grid gives the text
      # editor an export in that interval. When the author goes back there, the content shows again,
      # and a save stores it.
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

    # The switch makes the text editor write its field before a grid is built. If a listener of the
    # editor throws an error at that write, the author gets a message and stays in the text editor.
    it 'tells the author when the switch to the grid editor fails before the grid is made' do
      break_the_text_editor_reads
      open_grid_editor
      restore_the_text_editor_reads

      expect(page).to have_css('#cama_alert_modal', text: 'could not be opened')
      expect(page).to have_no_css('.panel_grid_editor', visible: :all)
      expect(page).to have_css('.mce-tinymce')
    end
  end

  # A grid opened on other content has no export. Until the first change of the grid, the post
  # stores the content of the text editor.
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

    # A visit to the text editor does not change that. The grid still has no export, and the post
    # stores the content that the author wrote in the text editor.
    it 'stores what was written in the text editor meanwhile while the grid has exported nothing' do
      leave_for_the_text_editor
      text_editor_holds('<p>written meanwhile</p>')
      open_grid_editor
      find('.panel_grid_editor .grid_editor_menu')
      submit_post_form

      expect(post_content).to eq('<p>written meanwhile</p>')
    end

    # The switch back shows the text editor and then gives it the content from before the grid. If a
    # listener of the editor throws an error at that write, the author sees the text editor, not two
    # hidden editors. The page also stays in position.
    it 'leaves the text editor shown when it cannot be handed its content on the way back to it' do
      page.execute_script(<<~JS)
        #{POST_TEXT_EDITOR}.on('BeforeSetContent', function(){ throw new Error('the writes are broken'); });
      JS
      leave_for_the_text_editor

      expect(page).to have_css('.mce-tinymce')
      expect(page).to have_no_css('.panel_grid_editor')
      expect(current_url_fragment).to be_nil
    end

    # An author who leaves such a grid gets the content from before the grid in the text editor. If
    # the author writes a grid there, the grid editor shows that grid. After that, the text editor
    # no longer gets the content from before the grid.
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

  # A post in more than one language has one field for each language, each with its own text editor
  # and grid editor. Core composes the stored content from these fields.
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

    # Before the page unloads, TinyMCE makes each text editor write its raw content into its field:
    # the markup of the editor, with each script under the type that the editor gives it. If the
    # author cancels the unload at the unsaved-changes prompt, the next grid change makes core
    # compose from the fields. The plugin makes each editor write its content there, not its raw
    # content. The example removes the prompt of core: up to 2.9.4, core wrote the fields when it
    # compared the form.
    it 'stores the other language as it was after a leave of the page that did not happen' do
      page.execute_script("window.onbeforeunload = null; window.dispatchEvent(new Event('beforeunload'));")
      change_the_english_grid
      export = saved_grid_content
      submit_post_form

      expect(post_content).to eq({ en: export, es: grid_in('spanish') }.to_translate)
    end

    # Core composes the content that the post sends when a field triggers a change, which occurs
    # when a text editor loses focus. A switch of editors does not wait for that: it writes the
    # field and triggers the change immediately.
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

  # Core refuses a script from a role without unfiltered HTML, and changes nothing. Before, the text
  # editor removed the script and the save passed without it.
  context 'with an author core does not trust with unfiltered HTML' do
    # The grid marker is a shortcode: a role also needs the shortcode permission of core to save a
    # grid.
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

    # To core, the text editor's version of a grid is changed content, and it still has the script.
    it 'refuses the text editor version of a grid that holds a script, and leaves the post as it was' do
      leave_for_the_text_editor
      submit_post_form

      expect(page).to have_css('.alert-danger', text: /script/i)
      expect(post_content).to eq(stored_content)
    end
  end
end
