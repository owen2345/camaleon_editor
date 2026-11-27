jQuery(function(){
    // Run this script only one time on a page. The Admin AJAX plugin loads an admin page in place,
    // and the response evaluates this script again. jQuery, TinyMCE and the hook lists stay. A
    // second run adds each hook again (a second toolbar button). It also makes the registries
    // again, without the block kinds and rows of other scripts.
    if($.fn.gridEditor) return;
    init_grid_editor();

    // Grid nodes and the jQuery plugin of TinyMCE. A script (a plugin, a theme or the page) installs
    // that plugin when it first calls jQuery's tinymce() with settings on a set that is not empty.
    // After that, these jQuery methods change for an element that carries the id of a text editor:
    // - html(), text(), val() and attr("value") read the content of that text editor. With a value,
    //   they write the value into that text editor and not into the element. They also remove each
    //   text editor whose panel id a descendant of the element carries.
    // - append() and prepend() add a string to the content of that text editor. They skip the
    //   element, also for a node or a jQuery object, which then goes into no element.
    // - remove() also removes that text editor.
    // remove(), replaceWith(), replaceAll() and empty() also remove each text editor whose panel id
    // ("<id>_parent", on a span or a div with the class "mceEditor") a descendant of the set carries.
    // Stored content and templates can give a grid node any id, for example the id of the post's
    // text editor. For this reason, the grid editor and its block forms use the helpers below on
    // grid nodes. Elsewhere they use DOM calls, or the jQuery methods that the plugin does not change.

    // Removes the nodes of a set from the page with their jQuery data and handlers, as jQuery's
    // remove() does. Returns the set.
    $.fn.gridEditorRemove = function(){
        $.cleanData(this.find("*").addBack());
        return this.detach();
    };
    // The markup in the first element of a set, or "" for an empty set.
    $.fn.gridEditorMarkup = function(){ return this.length ? this[0].innerHTML : ""; };
    // The text of the elements of a set, as jQuery's text() returns it.
    $.fn.gridEditorText = function(){ return $.map(this, function(node){ return node.textContent; }).join(""); };
    // Removes the children of an element with their jQuery data and handlers, as jQuery's empty() does.
    function empty_node(element){
        $.cleanData($(element).find("*"));
        element.textContent = "";
    }

    $.fn.fadeDestroy = function(speed){ $(this).fadeOut(speed, function(){ $(this).gridEditorRemove(); }) }
    // The class of a part that the author deleted: a column or block of the grid, or an item in the
    // list of a block form (a tab, a slide, an accordion panel). The part stays in the page while it
    // fades out. During the fade it is inert: it gets no mouse clicks and no keyboard focus. The
    // pointer-events style also stops mouse clicks in a browser without the inert attribute. No
    // export of the grid includes the part, and no block form reads it at Save.
    var DELETED = "grid-deleted";
    $.fn.gridEditorFadeDeleted = function(){
        this.addClass(DELETED).attr("inert", "").css("pointer-events", "none").fadeDestroy();
        return this;
    };
    // The items in the list of a block form, without the deleted items that still fade out.
    $.fn.gridEditorListedItems = function(){ return this.find("tbody tr").not("."+DELETED); };
    $.fn.isGridEditorContent = function(str){ return str.match(/^\<div\>\[grid_editor/); } // verify is text is a content for grid editor
    // remove libraries shortcode text from grid editor: the marker only, up to ITS closing bracket - a greedy
    // match would run on to the last "]</div>" of the content and take the grid along. Whatever isGridEditorContent
    // takes for a marker comes off, with or without a libraries list: a marker left in would be read as the grid.
    $.fn.skipGridEditorLibraries = function(str){ return str.replace(/^\<div\>\[grid_editor[^\]]*\]\<\/div\>/, ""); }
    $.fn.gridEditor_extra_rows = [];
    $.fn.gridEditor_libraries = [];

    // A value on its way into a quoted attribute of a markup string. The block builders assemble their
    // markup by concatenation: a url holding a quote would end the attribute and go on as markup of
    // its own. The browser reads the escaped value back as the same url, on the public page too.
    $.fn.gridEditorEscapeHtml = function(text){
        return String(text == null ? "" : text).replace(/[&<>"']/g, function(character){
            return {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"}[character];
        });
    };

    //********************** editor content options **********************//
    // The editor's own blocks, named and described in the admin language. The palette writes a
    // description into a title attribute as it is - a block another plugin registers gives its own -
    // so a translated one is escaped here, as tooltip() escapes the strings it is given.
    var hint = $.fn.gridEditorEscapeHtml;
    $.fn.gridEditor_options = {
        text: {title: I18n("grid_editor.block_text", "Text"), description: hint(I18n("grid_editor.block_text_hint", "Permits you to include plain text in any column.")), libraries: [], callback: grid_text_builder},
        editor: {title: I18n("grid_editor.block_editor", "Editor"), description: hint(I18n("grid_editor.block_editor_hint", "Permits you to include HTML text in any column.")), libraries: [], callback: grid_editor_builder},
        tab: {title: I18n("grid_editor.block_tab", "Tabs"), description: hint(I18n("grid_editor.block_tab_hint", "Permits you to include a tabs container in any column.")), callback: grid_tab_builder},
        slider: {title: I18n("grid_editor.block_slider", "Slider"), description: hint(I18n("grid_editor.block_slider_hint", "Permits you to include a slider animation in any column.")), callback: grid_slider_builder},
        image: {title: I18n("grid_editor.block_image", "Image"), description: hint(I18n("grid_editor.block_image_hint", "Permits you to include an image.")), callback: grid_image_builder},
        video: {title: I18n("grid_editor.block_video", "Video"), description: hint(I18n("grid_editor.block_video_hint", "Permits you to include a video.")), callback: grid_video_builder},
        audio: {title: I18n("grid_editor.block_audio", "Audio"), description: hint(I18n("grid_editor.block_audio_hint", "Permits you to include an audio file.")), callback: grid_audio_builder},
        accordion: {title: I18n("grid_editor.block_accordion", "Accordion"), description: hint(I18n("grid_editor.block_accordion_hint", "Permits you to include an accordion in any column.")), callback: grid_accordion_builder},
        //gallery: {title: "Gallery", description: "Permit you to include a gallery of audio, video or image in any column.", callback: grid_gallery_builder},
    };
    //********************** end editor content options **********************//

    // A block item's label, as the block's form lists and edits it. A label of plain text reads as its
    // text ("Q & A", not "Q &amp; A"). One that holds markup - an icon, a bold word - reads as its
    // source, and so does text that spells a tag: decoded, an escaped "<img onerror=...>" would go back
    // into the block as the element it only named. Text that spells a character reference is source
    // for the same reason: "&amp;amp;" read as "&amp;" would go back as the ampersand it only named.
    // The escaping is the form's alone: what the block stores, and the public page shows, stays as it was.
    //
    // A "<" makes markup of a label only when it opens a tag of the label's own. The label is parsed
    // with an element behind it, in the inert document: "x<y" or "a < b" leaves no element but that
    // one, or takes it along into a tag that never ends or an element that is never closed, as it
    // would the markup of the block. Such a label is text the author typed, and is escaped like text.
    function label_is_markup(label){
        label = String(label);
        if(label.indexOf("<") >= 0){
            var probe = inert().createElement("div");
            probe.innerHTML = label + "<i data-grid-label-end></i>";
            // the element has to come out behind the label, not inside it: a tag the label opens and
            // never closes ("<b>News") would hold it, as it would hold the tabs behind the label
            var end = probe.lastElementChild;
            if(!end || end.tagName !== "I" || !end.hasAttribute("data-grid-label-end")) return false;
            if(probe.getElementsByTagName("*").length > 1 || /<[!?]/.test(label)) return true;
        }
        // a character reference is one the parser decodes: "&T;" in "AT&T;" names nothing and stays text
        return $.grep(label.match(/&(#\d+|#x[0-9a-f]+|[a-z][a-z0-9]*);/ig) || [], function(reference){
            var decoder = inert().createElement("div");
            decoder.innerHTML = reference;
            return decoder.textContent !== reference;
        }).length > 0;
    }
    $.fn.gridEditorLabelSource = function(element){
        element = $(element);
        if(!element.length) return "";
        var text = element.gridEditorText();
        return $.trim(!element.children().length && !label_is_markup(text) ? text : element.gridEditorMarkup());
    };
    // The other way, by the same rule: a label that holds a tag or a character reference is markup
    // source and goes into the block as it is; any other is text, and is escaped like text.
    $.fn.gridEditorLabelMarkup = function(label){
        return label_is_markup(label) ? label : $.fn.gridEditorEscapeHtml(label);
    };

    // Markup parsed in a document of its own, where parsing loads and runs nothing, with its scripts
    // kept: a grid's embed blocks carry them. jQuery's parser, so markup gets what html() gave it: a
    // table row or a cell parsed as one, a self-closed <div/> expanded. One document serves every
    // parse; the nodes are only read or moved out of it.
    var inert_document = null;
    function inert(){ return inert_document || (inert_document = document.implementation.createHTMLDocument("")); }
    function parse_nodes(markup){ return $.parseHTML(String(markup), inert(), true) || []; }
    // the elements among parsed nodes
    function elements_of(nodes){ return $(nodes).filter(function(){ return this.nodeType === 1; }); }
    // the top-level elements of markup that came from the server
    function parse_inert(markup){ return elements_of(parse_nodes($.trim(String(markup)))); }

    // Sets an element's markup without running the scripts in it. jQuery's html() evaluates every
    // inline script of what it inserts; a grid's scripts are content for the public page, where the
    // theme has loaded what they call, and have no business in the administrator's session. The
    // parsed nodes are moved in natively: the parser marked their scripts as started.
    $.fn.gridEditorInertHtml = function(markup){
        return this.each(function(){
            var target = this;
            empty_node(target);
            $.each(parse_nodes(markup == null ? "" : markup), function(){ target.appendChild(this); });
        });
    };

    // A title attribute holding a translated string, escaped: a translation holding a quote would end
    // the attribute otherwise. It is the tooltip and, for the templates entries, the heading of the
    // modal their panel opens in (open_templates_modal_on_click).
    function tooltip(key, english, data){
        return ' title="'+$.fn.gridEditorEscapeHtml(I18n(key, english, data))+'"';
    }
    // The actions of an item (a tab, a slide) in the list a block's form shows: edit it, delete it.
    $.fn.gridEditor_item_actions = function(){
        return "<a href='#' class='edit_item'"+tooltip("grid_editor.edit_item", "Edit")+"><i class='fa fa-pencil'></i></a> "+
            "<a href='#' class='del_item'"+tooltip("grid_editor.delete_item", "Delete")+"><i class='fa fa-trash'></i></a>";
    };
    // Binds the actions of the items to the list of a block form. Edit calls show_form with the row
    // of the item. Delete asks for a confirmation, then the row fades out. The Edit link goes to "#".
    // Its handler stops the link first, in case the form throws an error. A browser without the inert
    // attribute lets the keyboard click the links of a deleted row while it fades out. Both handlers
    // ignore that click, so that no edit goes to a row that is removed.
    $.fn.gridEditorBindItemActions = function(show_form){
        return this.on("click", "a.edit_item", function(e){
            e.preventDefault();
            var row = $(this).closest("tr");
            if(!row.hasClass(DELETED)) { show_form(row); }
            return false;
        }).on("click", "a.del_item", function(){
            var row = $(this).closest("tr");
            if(row.hasClass(DELETED) || !confirm(I18n("msg.confirm_del"))) { return false; }
            row.gridEditorFadeDeleted();
            return false;
        });
    };

    // Sets up a text editor with the settings of Camaleon for each textarea of a block form. The
    // forms create the text editor with tinymce.createEditor, as jQuery's tinymce() does. They do
    // not use jQuery's tinymce(), which installs the jQuery plugin of TinyMCE (see "Grid nodes"
    // above). They do not use tinymce.init, which makes its settings the global settings of TinyMCE.
    // Camaleon 2.9.4 sets up the text editors of a sorted custom field again with those global
    // settings. A form calls this when its modal starts to show. Bootstrap puts the
    // modal in the page after that, so the setup starts when the modal is shown. Until the text
    // editor is ready, the textarea is hidden, and the author does not see the markup of the block.
    // A textarea that is not in the page at the setup gets no text editor, and shows again. It
    // shows again also when TinyMCE registers no text editor for it. The text editor goes when the
    // modal of the form closes.
    $.fn.gridEditorFormEditor = function(settings){
        return this.each(function(){
            // A textarea that has a text editor keeps it. A second setup hides nothing and adds
            // no second removal: the "init" event of that text editor can have fired already.
            remove_destroyed_editor(this);
            if(form_editor_of(this)) return;
            var area = this, modal = $(area).closest(".modal"), visibility = area.style.visibility;
            var show_area = function(){ area.style.visibility = visibility; };
            var set_up = function(){
                if(!$.contains(document, area)) return show_area();
                // tinymce.init does these two steps before it creates a text editor.
                area.id = area.id || tinymce.DOM.uniqueId();
                remove_destroyed_editor(area);
                if(!form_editor_of(area)){
                    var created = tinymce.createEditor(area.id, cama_get_tinymce_settings(settings));
                    created.targetElm = area;
                    created.render();
                }
                // TinyMCE registers the text editor in createEditor, and makes it ready later.
                var text_editor = form_editor_of(area);
                if(text_editor) text_editor.on("init", show_area); else show_area();
            };
            area.style.visibility = "hidden";
            if(!modal.length || modal.hasClass("in")) set_up(); else modal.one("shown.bs.modal", set_up);
            modal.one("hidden.bs.modal", function(){
                var text_editor = form_editor_of(area);
                if(text_editor) text_editor.remove();
            });
        });
    };
    // The content of the first textarea of a set: the content of its text editor, or the value of
    // the textarea until that text editor has a body. TinyMCE registers a text editor before it makes
    // the body of that editor, and until then getContent() returns "". TinyMCE loads the content into
    // the body when it makes the body, and marks the text editor as initialized only later.
    $.fn.gridEditorFormContent = function(){
        var area = this[0];
        if(!area) return "";
        var text_editor = form_editor_of(area);
        return text_editor && text_editor.getBody() ? text_editor.getContent() : area.value;
    };
    // The setup gives the textarea an id before it creates the text editor.
    function form_editor_of(area){ return area.id ? tinymce.get(area.id) : null; }
    // Removes the text editor with the id of the textarea when its panel has no parent element: the
    // page removed the panel and kept the text editor. tinymce.init also takes such a text editor
    // out before it creates a text editor, but it does not call remove(), which saves the content.
    function remove_destroyed_editor(area){
        var text_editor = form_editor_of(area);
        if(text_editor && text_editor.initialized && !(text_editor.getContainer() || text_editor.getBody()).parentNode){
            text_editor.remove();
        }
    }

    // An error alert for a request of the editor's own; $.fn.alert lifts the loading overlay too. The
    // alert is core's modal, often the very code whose throw is being reported, and the report runs
    // inside a request's callback: thrown on from here it would make jQuery skip the callbacks still
    // to come and leave whatever sent the request busy. The browser's own alert says it then.
    function report_failure(key, english){
        var message = I18n("grid_editor."+key, english);
        try {
            $.fn.alert({type: "error", title: message});
        } catch(error) {
            if(window.console) console.error(error);
            hideLoading();
            window.alert(message);
        }
    }
    function import_failed(){ report_failure("import_failed", "The template could not be loaded."); }
    function content_unreadable(){
        report_failure("content_unreadable", "This content is marked as a grid but could not be read as a grid, so it stays in the text editor.");
    }
    function editor_failed(){
        report_failure("editor_failed", "The grid editor could not be opened, so the content stays in the text editor.");
    }

    // The templates modal swaps its content for what its requests return: the list, or the template
    // form. A signed-out or refused request is redirected and comes back as a 200 carrying the login
    // or dashboard page, so the views check a response is one of those panels before showing it.
    $.fn.gridEditor_is_templates_panel = function(res){
        return parse_inert(res).filter("#grid_table_list, #grid_template_form").length > 0;
    };
    // for those requests when they fail or return something else
    $.fn.gridEditor_request_failed = function(){
        report_failure("request_failed", "The request was not completed. Reload the page and try again.");
    };

    // What every request of the templates modal does with its answer: show it when it is one of the
    // panels, report the request when it is anything else. show(res) puts the panel where it belongs.
    $.fn.gridEditor_show_templates_panel = function(res, show){
        if(!$.fn.gridEditor_is_templates_panel(res)){
            $.fn.gridEditor_request_failed();
            return false;
        }
        // Showing the panel runs code that is not the editor's - core's modal, its listeners - inside the
        // request's own callback. A throw there would go up through jQuery, which then skips every
        // callback still to come: the overlay would stay, and whatever sent the request stay busy.
        try {
            show(res);
        } catch(error) {
            if(window.console) console.error(error);
            $.fn.gridEditor_request_failed();
            return false;
        }
        hideLoading();
        return true;
    };

    // One request at a time for whatever holds the control that sends it (the modal, the editor). The
    // loading overlay stops the mouse, not Enter on the control that keeps the focus: a second apply
    // over the first, a template saved twice. send() returns the request; nothing is sent while the
    // holder is busy.
    $.fn.gridEditor_one_request = function(holder, send){
        if(holder.data("grid_editor_request")) return;
        holder.data("grid_editor_request", true);
        showLoading();
        // A prefilter or a beforeSend of the page's runs as the request leaves, and a throw there comes
        // out of send() with no request to wait for: the holder is released and the request reported
        // here, or it would stay busy under an overlay nothing lifts.
        var request;
        try {
            request = send();
        } catch(error) {
            if(window.console) console.error(error);
            holder.removeData("grid_editor_request");
            $.fn.gridEditor_request_failed();
            return;
        }
        request.always(function(){ holder.removeData("grid_editor_request"); });
    };

    // Opens the panel a templates menu link points at - the list, the template form - in a modal.
    // Core's ajax_modal would show whatever a 200 carries, and the menu is built from what the page
    // knew when it loaded: a session gone or a permission taken away since then comes back as the
    // login or dashboard page. The panel is fetched and checked first, and only a panel is shown.
    function open_templates_modal_on_click(links, callback){
        links.each(function(){
            var link = $(this);
            // The link's title heads the modal, and is read here, as the editor wrote it: a second
            // after the page loads core gives every link of the admin a Bootstrap tooltip, which takes
            // the title out of the attribute and keeps it where that version of Bootstrap sees fit.
            var heading = link.attr("title");
            link.click(function(e){
                e.preventDefault();
                $.fn.gridEditor_one_request(link.closest(".panel_grid_editor"), function(){
                    return $.get(link.attr("href")).done(function(res){
                        $.fn.gridEditor_show_templates_panel(res, function(panel){
                            open_modal({title: heading, content: panel, callback: callback});
                        });
                    }).fail($.fn.gridEditor_request_failed);
                });
            });
        });
    }

    // What the server says the user may do with the template library. A page can hold several
    // editors (one per language of a post): while a request is under way they share it, and its
    // answer. The answer is not kept: a permission granted or taken away since is found out the next
    // time a menu is opened. cama_ajax_request spares the server the sidebar menus it builds for a
    // whole admin page.
    var abilities_request = null;
    function ask_abilities(){
        if(abilities_request) return abilities_request;
        var request = abilities_request = $.getJSON(root_url+"admin/plugins/camaleon_editor/abilities", {cama_ajax_request: true});
        // attached after the assignment: a request rejected before it left runs this at once
        request.always(function(){ if(abilities_request === request) abilities_request = null; });
        return request;
    }

    // the title a break line is saved with (data-col_title), in every admin language
    var BREAK_LINE = "Break Line";

    // The classes of a grid root. The grid editor finds its grid by the first class.
    var GRID_ROOT_CLASS = "panel_grid_body row";

    // Writes the content of the text editor into its field and triggers "change" on the field, as
    // core does when the text editor loses focus. Use it when the field must have the current
    // content immediately: at a switch of editors, or before a grid is built from the field. A post
    // in more than one language sends the content that core composed at the last "change". A switch
    // of editors does not move the focus.
    function field_follows(text_editor, field){
        text_editor.save();
        field.trigger("change");
    }

    // Returns the value of the field itself. After a script of the page loads a text editor through
    // jQuery's tinymce(), jQuery's val() returns the content of the field's text editor.
    function field_value(field){ return $(field)[0].value || ""; }

    // The names of the jQuery data that link a field and its grid editor.
    var GRID_OF_FIELD = "cama_grid_editor", FIELD_OF_GRID = "cama_grid_field";

    // Returns the grid editor of a field, if there is one. The field and its grid editor refer to
    // each other, so the grid editor is found wherever it is. A page can put an element between
    // them. A copy of the field with its jQuery data refers to the grid editor, but the grid editor
    // does not refer to the copy. A grid editor that is not in a parent element does not count.
    // A grid editor outside the page does not count for a field in the page: the author cannot see
    // that grid editor, so the field can get a new one.
    function built_grid_of(field){
        var grid = $(field).data(GRID_OF_FIELD);
        if(!grid || !grid[0].parentNode || grid.data(FIELD_OF_GRID) !== $(field)[0]) return $();
        return $.contains(document, grid[0]) || !$.contains(document, $(field)[0]) ? grid : $();
    }

    // A grid editor is hidden while the author is in the text editor. Read the display of the grid
    // editor itself: a hidden form or tab around it does not count.
    function grid_hidden(grid){ return grid[0].style.display === "none"; }

    // grid editor plugin
    // tinyEditor is the text editor of the field. If the page sets up a new text editor for the
    // field later, the grid editor works with that editor (see take_text_editor).
    var gridEditor_id = 0;
    $.fn.gridEditor = function(tinyEditor){
        // one editor per field, as jQuery's before() gave each field of a set its own
        if(this.length > 1) return this.each(function(){ $(this).gridEditor(tinyEditor); });
        var textarea = $(this);
        // If this field already has a grid editor, show that editor again and build nothing. The
        // field is not read: the "show_again" handler reads the text editor that the grid editor
        // works with.
        var built_editor = built_grid_of(textarea);
        if(built_editor.length){
            built_editor.triggerHandler("show_again");
            return textarea;
        }
        // Content marked as a grid that cannot be read as one stays in the text editor: shown as an
        // empty grid, its first change would be auto-saved over the content nobody got to see.
        var saved_body = null;
        var saved_content = field_value(textarea);
        if($.fn.isGridEditorContent(saved_content)){
            saved_body = parse_grid_body(saved_content, true);
            if(!saved_body){
                content_unreadable();
                return textarea;
            }
        }
        // The content that a save stores while the grid editor is visible. Until the first
        // auto_save, it is the content that the grid was built from. After that, it is the last
        // export. A grid opened on other content has no export (null) until its first auto_save.
        // Until then, a save stores the content of the text editor.
        var exported = saved_body ? saved_content : null;
        // The content of the text editor, and the markup of its document, when the author left the
        // grid editor.
        var left_with = null, left_with_body = null;
        gridEditor_id ++;
        var tinymce_panel = $(tinyEditor.editorContainer).hide();
        var editor_id = "grid_editor_"+gridEditor_id;
        var tpl_rows = "";
        $.each({6: 50, 4: 33, 3: 25, 2: 16, 8: 66, 9: 75, 12: 100}, function(k, val){ tpl_rows += '<div class="" data-col="'+k+'"'+tooltip("grid_editor.col_block_title", "Insert a column block with %{width}% of width.", {width: val})+' data-col_title="'+val+'%"><div class="grid_sortable_items"></div></div>'; });

        // break line
        tpl_rows += '<div class="clearfix"'+tooltip("grid_editor.break_line_title", "Insert a break line to have ordered column blocks.")+' data-col_title="'+BREAK_LINE+'" data-col="12"></div>' + $.fn.gridEditor_extra_rows.join("");

        // tpl options
        var tpl_options = "";
        $.each($.fn.gridEditor_options, function(key, item){ tpl_options += '<div class="" data-kind="'+key+'" title="'+item["description"]+'"><div class="grid_item_content grid_item_'+key+'"></div></div>'; });

        // Saving a template needs the template-management permission. The page says whether the user
        // holds it; on a page that loaded the editor without saying, the entry is built hidden and the
        // server is asked, so nobody is offered an action they would be refused and nobody entitled
        // to it loses it to a missing variable.
        var can_manage_templates = window.cama_grid_editor_can_manage_templates;
        // only the two literals are a declaration; null, 1 or "true" from a hand-written page is not one
        if(can_manage_templates !== true && can_manage_templates !== false) can_manage_templates = undefined;
        // declared a manager: the entry; declared not one: no entry; not declared: the entry, held back
        var save_template_entry = "";
        if(can_manage_templates !== false){
            save_template_entry = '<li class="'+(can_manage_templates ? '' : 'hidden')+'"><a class="new_template"'+tooltip("grid_editor.save_tpl_title", "New template")+' href = "'+root_url+'/admin/plugins/camaleon_editor/grid_editor/new" >'+I18n("grid_editor.save_tpl", "Save as template")+'</a></li >';
        }

        // the entry that opens the style settings: of the whole grid in the menu, of a block or a
        // content element in its dropdown
        var style_settings_entry = "<li><a class='grid_style_settings'"+tooltip("grid_editor.style_settings_title", "Style settings")+" href='#'><i class='fa fa-paint-brush'></i> "+I18n("button.settings")+"</a></li>";

        // template grid editor
        // Every I18n("grid_editor...") call of the editor passes the English string as its default:
        // the page holds the strings of the admin language alone, and in a language the plugin does
        // not ship core's helper would answer with the titleized key, "List" or "Clear Editor".
        var editor = $("<div class='panel_grid_editor' id='"+editor_id+"'>"+
            "<div class='grid_editor_menu'>"+
            "<ul class='nav nav-tabs'>"+
            "<li class='active'><a href='#grid_columns_"+gridEditor_id+"' role='tab' data-toggle='tab'><i class='fa fa-th-list'></i> "+I18n("grid_editor.blocks", "Blocks")+"</a></li>"+
            "<li class=''><a href='#grid_contents_"+gridEditor_id+"' role='tab' data-toggle='tab'><i class='fa fa-table'></i> "+I18n("grid_editor.contents", "Content Elements")+"</a></li>"+
            '<li>' +
            '<a class="dropdown-toggle" href="#" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">'+I18n("grid_editor.templates", "Templates")+' <span class="caret"></span> </a>'+
            '<ul class="dropdown-menu" aria-labelledby="dropdownMenu1"> ' +
            '<li><a class="list_templates"'+tooltip("grid_editor.list_title", "Grid templates")+' href = "'+root_url+'admin/plugins/camaleon_editor/grid_editor" >'+I18n("grid_editor.list", "List of templates")+'</a></li >'+
            save_template_entry+
            style_settings_entry+
            '</ul> ' +
            '</li>'+
            "<li class=''><a href='#' class='clear'><i class='fa fa-trash'></i>  "+I18n("grid_editor.clear", "Clear")+"</a></li>"+
            "<li class=''><a href='#' class='toggle_panel_grid'><i class='fa fa-share'></i>  "+I18n("grid_editor.text_editor", "Text Editor")+"</a></li>"+
            "<li class='pull-right'><label style='margin: 0px;'><input class='toggle_preview_grid' type='checkbox'/> "+I18n("grid_editor.preview", "Preview")+"</label><br><label style='margin: 0px;'><input class='toggle_fullscreen_grid' type='checkbox'/> "+I18n("grid_editor.fullscreen", "Fullscreen")+"</label></li>"+
            "</ul>"+
            "<div class='tab-content'>"+
            "<div role='tabpanel' class='tab-pane active' id='grid_columns_"+gridEditor_id+"'> "+
            '<p class="text-info">'+I18n("grid_editor.blocks_hint", "Drag and drop these blocks (Column Blocks) into the area below.")+'</p>'+
            tpl_rows+
            " </div>"+
            "<div role='tabpanel' class='tab-pane' id='grid_contents_"+gridEditor_id+"'>"+
            '<p class="text-info">'+I18n("grid_editor.contents_hint", "Drag and drop these blocks (Content Blocks) into any Column Block.")+'</p>'+
            tpl_options+
            "</div>"+
            "</div>"+
            "</div>"+
            "<div class='panel_grid_body_w'><div class='"+GRID_ROOT_CLASS+"'></div></div>"+
            "</div>");

        // The editor's grid: the root its own wrapper holds, and that one alone. A block may hold grid
        // markup of its own - pasted in, or applied with a template - which is that block's content:
        // found by class anywhere under the editor, it would be parsed, styled, emptied and made
        // sortable along with the grid, and saved with the editor's chrome in it.
        var GRID_ROOT = "#"+editor_id+" > .panel_grid_body_w > .panel_grid_body"; // for the widgets that take a selector
        function grid_root(editor){ return $(editor).children(".panel_grid_body_w").children(".panel_grid_body"); }
        // The markup of the editor makes this root, and no path removes it or its class
        // "panel_grid_body". For this reason, the code reads grid_root(editor)[0] with no guard. The
        // design keeps no guard: if the root goes, a TypeError shows the bug at once.

        // grid editor export
        function export_content(editor){
            var container = grid_root(editor).clone();
            container.children("."+DELETED).gridEditorRemove();
            container.children().each(function(){
                var col = $(this).removeClass("drg_column btn-default btn ui-draggable ui-draggable-handle ui-draggable-dragging ui-sortable-handle");
                col.children(".header_box").gridEditorRemove();
                // the column's own area and blocks: what a block holds is content, chrome-like names included
                var area = col.children(".grid_sortable_items").removeClass("ui-sortable");
                area.children("."+DELETED).gridEditorRemove();
                area.children().each(function(){ //contents
                    $(this).removeClass("drg_item btn-default btn ui-draggable ui-draggable-dragging ui-sortable-handle ui-draggable-handle").children(".header_box").gridEditorRemove();
                });
                give_id_back(area);
            });
            give_id_back(container);
            var res = container[0].outerHTML;
            container.gridEditorRemove();
            return res;
        }

        // The grid body in a fetched template or in saved post content, or null when there is none. A refused or signed
        // out request is redirected, and the request follows it to a 200: without this check the
        // dashboard or login page would be written into the grid and auto-saved over the post content.
        // whole: for saved post content, which has to be the grid and nothing else - see below
        function parse_grid_body(res, whole){
            var nodes = parse_nodes($.trim($.fn.skipGridEditorLibraries(String(res))));
            var elements = elements_of(nodes);
            var bodies = elements.filter(".panel_grid_body");
            // The editor holds one grid. Content with several would open as its first alone, and lose the
            // rest at the next auto_save: it is not read at all, which leaves it where it is.
            if(bodies.length > 1) return null;
            var body = bodies.first();
            // A template stored by other means may wrap its columns in a plain element of any kind, or hold
            // its grid body inside the editor's own wrapper. A page is told apart by what only a page's
            // head leaves at the top level - a title, a base, the charset or the csrf token - and not by a
            // link or a meta of another kind, which a template may well start with.
            if(!body.length && !elements.filter("title, base, meta[charset], meta[name='csrf-token']").length){
                // the outermost ones: grid markup inside a grid's block is that block's content, as it
                // is for a grid body at the top level
                var nested = elements.find(".panel_grid_body").filter(function(){ return !$(this).parents(".panel_grid_body").length; });
                if(nested.length > 1) return null; // several grids again, further down
                body = nested.first();
                // a plain element counts as a grid by what it holds, columns: any other - a block of
                // prose, an error message, a marker that was not taken off - is not one
                if(!body.length){
                    var wrappers = elements.filter(function(){ return $(this).children("[data-col]").length > 0; });
                    if(wrappers.length > 1) return null; // several grids once more, in plain wrappers
                    body = wrappers.first();
                }
            }
            if(!body.length) return null;
            // A template is applied for its grid, and what trails it is let go. Saved content is another
            // matter: the editor saves the grid alone, so anything beside it - a paragraph after the grid, a
            // stylesheet link before it - would go at the first auto_save. Such content is not read as a grid.
            // Beside it at any depth: a grid inside a wrapper has siblings there as well.
            if(whole){
                var level = nodes;
                for(var within = body[0]; within; within = within.parentNode){
                    if($.inArray(within, nodes) >= 0) break;
                    level = level.concat($.makeArray(within.parentNode.childNodes));
                }
                if($.grep(level, function(node){ return !holds(node, body[0]) && carries_content(node); }).length) return null;
            }
            return body;
        }
        function holds(node, element){ return node === element || (node.nodeType === 1 && $.contains(node, element)); }
        // what a text editor leaves around a block counts for nothing: blank text, a comment, a br, and a
        // p, div or span that holds nothing but those - "<p><br></p>" is an empty paragraph too
        function carries_content(node){
            if(node.nodeType === 3) return $.trim(node.nodeValue) !== "";
            if(node.nodeType !== 1) return false;
            if(node.tagName === "BR") return false;
            if(!/^(P|DIV|SPAN)$/.test(node.tagName)) return true;
            return $.grep(node.childNodes, function(child){ return carries_content(child); }).length > 0;
        }

        // the style of the whole grid (Templates > Settings) lives on the grid's root, not inside it
        var GRID_STYLE_ATTRIBUTES = ["style", "data-style"];
        function grid_style(root){
            var style = {};
            $.each(GRID_STYLE_ATTRIBUTES, function(_index, name){ style[name] = root.attr(name); });
            return style;
        }
        function set_grid_style(grid, style){
            $.each(GRID_STYLE_ATTRIBUTES, function(_index, name){
                if(style[name] === undefined) grid.removeAttr(name); else grid.attr(name, style[name]);
            });
        }

        // The saved grid root used to be swapped in whole, so whatever a theme hook or a hand edit left on
        // it - an id, a class, a data attribute the public page styles by - came back out on the next
        // save. Now that the editor keeps its own root, those are carried over to it. They go over as
        // copies of their nodes: the HTML parser keeps attribute names that setAttribute refuses.
        function keep_root_attributes(grid, root){
            $.each(root[0].attributes, function(_index, attribute){
                // the saved classes as they are - a root saved without "row" does not get it back - plus
                // the one the editor finds its grid by
                if(attribute.name === "class") grid.attr("class", attribute.value).addClass("panel_grid_body");
                else if($.inArray(attribute.name, GRID_STYLE_ATTRIBUTES) < 0) grid[0].setAttributeNode(document.importNode(attribute, true));
            });
            keep_id_aside(grid);
        }

        // jQuery UI puts the copy of a palette entry into a sortable with jQuery's appendTo(), which
        // calls append(). The jQuery plugin of TinyMCE changes append() for an element that carries
        // the id of a text editor (see "Grid nodes"), and the copy then goes into no sortable. For
        // this reason, the root and the area of each column keep their id in KEPT_ID while the grid
        // is edited. The export gives the id back. An attribute with the name KEPT_ID in the content
        // goes, because the export would make an id of it.
        var KEPT_ID = "data-grid-editor-kept-id";
        function keep_id_aside(elements){
            rename_attribute(elements, "id", KEPT_ID);
        }
        function give_id_back(elements){
            rename_attribute(elements, KEPT_ID, "id");
        }
        // Gives the attribute `from` of each element the name `to`, at the same place among the
        // attributes. First, the function removes the attribute with the name `to`. It moves the
        // other attributes as nodes: the HTML parser keeps attribute names that setAttribute
        // refuses, for example "=x" in <div =x="1">.
        function rename_attribute(elements, from, to){
            elements.each(function(){
                var element = this, attributes = $.makeArray(element.attributes);
                if(!element.hasAttribute(from) && !element.hasAttribute(to)) return;
                $.each(attributes, function(_index, attribute){ element.removeAttributeNode(attribute); });
                $.each(attributes, function(_index, attribute){
                    if(attribute.name === to) return;
                    if(attribute.name === from){
                        var renamed = element.ownerDocument.createAttribute(to);
                        renamed.value = attribute.value;
                        attribute = renamed;
                    }
                    element.setAttributeNode(attribute);
                });
            });
        }

        // Fills the grid from a parsed grid root: the root's style when it has one, then its markup. A
        // root without a style - a template saved from a grid nobody styled - says nothing about the
        // style of the grid it goes into, which stays.
        function fill_grid(grid, root){
            var style = grid_style(root);
            var styled = $.grep(GRID_STYLE_ATTRIBUTES, function(name){ return style[name] !== undefined; }).length > 0;
            if(styled) set_grid_style(grid, style);
            // The parsed nodes are moved in natively rather than serialised and parsed a second time.
            // Their scripts stay inert: the parser marked them as started, and no jQuery insertion, which
            // would evaluate them, is involved. The grid is empty here: a new editor, or contents set aside.
            while(root[0].firstChild) grid[0].appendChild(root[0].firstChild);
        }

        // grid editor parser to recover from saved content
        function parse_content(editor){
            grid_root(editor).children("div").each(function(){ var col = parse_content_column($(this)); });
            return editor;
        }

        // Builds the grid from the root of stored content: the attributes of the root, its style
        // and its markup, then the headers and menus. The grid is filled from markup. Live nodes
        // are not inserted, because they run the scripts of the content.
        function grid_from(root){
            var grid = grid_root(editor);
            keep_root_attributes(grid, root);
            fill_grid(grid, root);
            parse_content(editor);
        }

        // What heads a column: the title saved with it, its width. A break line's saved title is its
        // English name, in whatever admin language it was added: the content keeps it as it is, and
        // the editor shows it in the admin language.
        function column_title(column){
            var title = column.attr("data-col_title") || "";
            return title === BREAK_LINE ? I18n("grid_editor.break_line", "Break Line") : title;
        }

        // Tells if a column or block has its options menu. A palette entry is parsed without a menu
        // (skip_options). A copy dropped from the palette gets its menu one time, when its sort
        // ends. The columns and blocks of a rebuilt grid, and clones, already have a menu.
        function has_menu(element){
            return element.children(".header_box").children(".dropdown").length > 0;
        }

        // parse column editor
        // column: content element
        // skip_options: boolean to add drodown options
        function parse_content_column(column, skip_options){
            // the title comes from stored content: it goes in as text, never as markup
            var html = $('<div class="header_box"><a><i class="fa fa-stop"></i> </a></div>');
            html.children("a").append(document.createTextNode(column_title(column)));
            var options = "<div class='dropdown'>" +
                "<a class='dropdown-toggle' data-toggle='dropdown'>&nbsp; <span class='caret'></span></a>" +
                "<ul class='dropdown-menu auto_with pull-right' role='menu'>"+
                "<li><a class='grid_col_remove' href='#'><i class='fa fa-trash-o'></i> "+I18n("button.delete")+"</a></li>"+
                "<li><a class='grid_col_clone' href='#'><i class='fa fa-copy'></i> "+I18n("button.clone")+"</a></li>"+
                style_settings_entry+
                "</ul>"+
                "</div>" ;
            column.addClass("drg_column btn btn-default");
            if(column.children(".header_box").length == 0) column[0].insertBefore(html[0], column[0].firstChild);
            if(!skip_options){
                // the column's own header, area and blocks: a block may hold grid markup of its own
                column.children('.header_box').each(function(){ this.insertAdjacentHTML("beforeend", options); });
                keep_id_aside(column.children(".grid_sortable_items"));
                grid_content_manager(column.children(".grid_sortable_items"));
                column.children(".grid_sortable_items").children().each(function(){ //contents
                    parse_content_content($(this));
                });
            }
            column;
        }

        // The registry entry of a block's kind, or null for a kind no script registers. An entry is the
        // registry's own: a kind named like something every object carries ("constructor") has none.
        function registered_kind(block){
            var key = block.attr("data-kind");
            return Object.prototype.hasOwnProperty.call($.fn.gridEditor_options, key) ? $.fn.gridEditor_options[key] : null;
        }

        // parse column editor
        // content: content element
        // skip_options: boolean to add drodown options
        function parse_content_content(content, skip_options){
            // a block of a kind no script registers - its plugin gone - has no name
            var kind = registered_kind(content);
            var t = kind ? kind.title : I18n("grid_editor.block_unknown", "unknown");
            var html = '<div class="header_box">'+
                '<a><i class="fa fa-keyboard-o"></i> '+ t +'</a>'+
                '</div>';
            var options = "<div class='dropdown'>" +
                "<a class='dropdown-toggle' data-toggle='dropdown'>&nbsp; <span class='caret'></span></a>" +
                "<ul class='dropdown-menu auto_with pull-right' role='menu'>"+
                "<li><a class='grid_content_remove' href='#'><i class='fa fa-trash-o'></i> "+I18n("button.delete")+"</a></li>"+
                "<li><a class='grid_content_clone' href='#'><i class='fa fa-copy'></i> "+I18n("button.clone")+"</a></li>"+
                "<li><a class='grid_content_edit' href='#'><i class='fa fa-pencil'></i> "+I18n("button.edit")+"</a></li>"+
                style_settings_entry+
                "</ul>"+
                "</div>";
            content.addClass("drg_item btn btn-default");
            // The header is parsed in a div. A block can be a script or an iframe, and in such an
            // element the browser reads markup as text, which the export keeps.
            if(content.children(".header_box").length == 0) content[0].insertBefore($(html)[0], content[0].firstChild);
            if(!skip_options){
                content.children('.header_box').each(function(){ this.insertAdjacentHTML("beforeend", options); });
            }
            // save used libraries
            // TODO: finish or retire the list of libraries a grid uses, a design of the plugin's first
            // commit that neither end completed.
            // The plan, as the code shows it: a kind declares libraries: [...] in the registry, names of
            // Camaleon asset libraries; this line collects those of the kinds in use; auto_save writes
            // them into the marker, [grid_editor data='a,b']; and on the public page the grid_editor
            // shortcode (camaleon_editor_front in main_helper.rb) loads them, so a block's front-end
            // assets arrive only where the block is used.
            // What happens: the merge takes the registry entry itself, an object with no length, so it
            // adds nothing and data is always empty; and the shortcode ignores its attributes and loads
            // the plugin's stylesheet alone. The marker still tells a grid from other content
            // (isGridEditorContent) and brings that stylesheet in: only the list is dead.
            // To finish it: merge kind.libraries, each name once, into a list built for each save - this
            // array is shared by every editor of the page and never emptied - and have the shortcode
            // load what data names. To retire it: drop this line and the libraries keys of the
            // registry, and keep data='' in the marker so saved content stays as it is;
            // $.fn.gridEditor_libraries is public, so another plugin may read it.
            $.fn.gridEditor_libraries = $.merge($.fn.gridEditor_libraries, kind || {})
            content;
        }

        // add editor menu actions
        function do_editor_menus(editor){
            // toggle editor menus
            editor.find(".grid_editor_menu .toggle_panel_grid").click(function(e){
                // Stop the link first, in case the switch throws an error.
                e.preventDefault();
                if(!confirm(I18n("grid_editor.toggle_editor", "Are you sure to leave this editor?"))) return false;
                // Show the text editor before its content is read or written. If a listener of the
                // editor throws an error at a read, the author sees the text editor, not two hidden
                // editors. While the grid editor is hidden, the text editor returns its own content
                // (see the GetContent listener).
                editor.hide();
                tinymce_panel.show();
                // Give the text editor its backup: the content from before the grid, or other
                // content that the author wrote there later. With an empty backup, the text editor
                // keeps the grid export, and the author can edit the grid as markup. This applies
                // to a grid made on an empty post, or kept after the author emptied the text
                // editor.
                if(editor.data("tiny_backup")) tinyEditor.setContent(editor.data("tiny_backup"));
                left_with = tinyEditor.getContent();
                left_with_body = tinyEditor.getBody().innerHTML;
                field_follows(tinyEditor, textarea);
                return false;
            });
            editor.find(".grid_editor_menu .clear").click(function(e){
                // Stop the link first, in case an export listener throws an error.
                e.preventDefault();
                if(!confirm(I18n("grid_editor.clear_editor", "Are you sure to clear the editor?"))) return false;
                empty_node(grid_root(editor)[0]);
                editor.trigger("auto_save");
                return false;
            });
            // toggle preview
            editor.find(".grid_editor_menu .toggle_preview_grid").change(function(){
                if($(this).is(":checked"))
                    editor.addClass("preview_mode");
                else
                    editor.removeClass("preview_mode");
            });
            // main style
            editor.find(".grid_editor_menu .grid_style_settings").click(function(e){
                e.preventDefault();
                grid_style_setting(grid_root(editor), editor, grid_root(editor));
            });
            // toggle fullscreen
            //$(window).unbind("resize.cama_editor").on("resize.cama_editor", function(){ if(editor.hasClass("fullscreen_mode")){ editor.find(".panel_grid_body").height($(window).height()-editor.find(".grid_editor_menu").height()); } });
            editor.find(".grid_editor_menu .toggle_fullscreen_grid").change(function(){
                if($(this).is(":checked")) editor.addClass("fullscreen_mode");
                else editor.removeClass("fullscreen_mode");
                //$(window).trigger("resize");
            });

            // modal with available templates
            open_templates_modal_on_click(editor.find(".grid_editor_menu .list_templates"), function(modal){
                // The link goes nowhere (its url travels as data) and every path returns false. A failure
                // leaves the list open, so another template can be picked.
                modal.on("click", ".import_item", function(){
                    var url = $(this).attr("data-url");
                    // one apply at a time, and no prompt for one that would not be sent
                    if(modal.data("grid_editor_request") || !confirm($(this).attr("data-message"))) return false;
                    $.fn.gridEditor_one_request(modal, function(){ return $.get(url, function(res){
                        var grid = grid_root(editor), previous = null, applied = false;
                        // everything from reading the response on runs under the finally that lifts the overlay
                        try {
                            var template_body = parse_grid_body(res);
                            if(!template_body) return import_failed();
                            // keep the current grid, to restore it if the rebuild fails
                            previous = set_aside(grid);
                            fill_grid(grid, template_body);
                            parse_content(editor); // recover saved content
                            editor.trigger("auto_save");
                            applied = true;
                        } catch(error) {
                            // A parser or an auto_save listener threw part-way: a half-built grid that the post content
                            // may not match is worse than no template, so the grid goes back to what it was. The way
                            // back is guarded too: whatever it hits, the failure still gets reported.
                            try {
                                if(previous){
                                    previous.restore();
                                    editor.trigger("auto_save");
                                }
                            } catch(restore_error) { if(window.console) console.error(restore_error); }
                            if(window.console) console.error(error);
                            import_failed();
                        } finally {
                            // whatever happened above, the overlay must not outlive it
                            hideLoading();
                        }
                        if(!applied) return;
                        // After the guard, nothing can undo the applied template. Release the grid
                        // that was kept for a rollback. Close the list only now, because each
                        // failure leaves it open. An error from a listener of the modal is not a
                        // failure of the apply.
                        previous.release();
                        try { modal.modal("hide"); } catch(error) { if(window.console) console.error(error); }
                    }).fail(import_failed); });
                    return false;
                });
            });

            // Asked when the Templates menu is opened, the moment the answer matters. Anything but a plain
            // yes - a refusal, a redirect to the login page, a failed request - hides the entry, or leaves it hidden.
            if(can_manage_templates === undefined) editor.find(".grid_editor_menu .dropdown-toggle").on("click", function(){
                // this runs before Bootstrap's own handler: a menu still marked open is being closed
                if($(this).parent().hasClass("open")) return;
                var entry = editor.find(".grid_editor_menu .new_template").parent();
                ask_abilities().done(function(abilities){
                    entry.toggleClass("hidden", !(abilities && abilities.manage_templates === true));
                }).fail(function(){ entry.addClass("hidden"); });
            });

            // save as a new template
            open_templates_modal_on_click(editor.find(".grid_editor_menu .new_template"), function(modal){
                modal.find("textarea").val(export_content(editor));
            });

            // parse menu options
            editor.find("#grid_columns_"+gridEditor_id).children("div").each(function(){ parse_content_column($(this), true) });
            editor.find("#grid_contents_"+gridEditor_id).children("div").each(function(){ parse_content_content($(this), true) });

            // tooltips
            editor.find(".grid_editor_menu .drg_item, .grid_editor_menu .drg_column").tooltip();

            // if saved content is a grid_editor content, then rebuilt or recover this content
            if(saved_body){
                grid_from(saved_body);
            }else{
                editor.data("tiny_backup", tinyEditor.getContent())
            }

            // trigger auto save changes
            // Write the field directly, as field_value reads it. After a script of the page loads a
            // text editor through jQuery's tinymce(), jQuery's val() gives the export to the text
            // editor again and does not change the field.
            editor.bind("auto_save", function(){
                var txt = exported = "<div>[grid_editor data='"+$.fn.gridEditor_libraries.join(",")+"']</div>"+export_content($(this));
                tinyEditor.setContent(txt);
                textarea[0].value = txt;
                textarea.trigger("change_in");
            });

            // The registry entry of a block's kind, when it has a builder: the form the block is edited
            // in. A block of a kind no script registers - its plugin gone - has none, so its menu offers
            // no Edit. The registry is read as the menu opens and as Edit is clicked, not as the grid
            // is rebuilt: a script may register its kind after that.
            function editable_kind(block){
                var kind = registered_kind(block);
                return kind && $.isFunction(kind.callback) ? kind : null;
            }

            // Deletes a block or column. The element fades out, and stays in the grid until the
            // fade ends. A mark removes it from each export, and the grid is exported at the click.
            // A later export lets a save during the fade store the element. While it fades out, the
            // element is inert: no second delete, and no clone with the mark. A column that
            // fades out accepts no dropped block, because the block goes with the column. The fade
            // starts before the export, in case an export listener throws an error.
            function fade_out_of_grid(element){
                element.children(".grid_sortable_items").filter(":ui-sortable").sortable("disable");
                element.gridEditorFadeDeleted();
                editor.trigger("auto_save");
            }

            // A browser without the inert attribute lets the keyboard click the links and menu
            // toggles of a block or column that fades out. This handler runs before the options
            // below and ignores that click: no second delete, and no clone with the mark.
            grid_root(editor).on("click", "."+DELETED+" a, ."+DELETED+" .dropdown-toggle", function(e){
                e.preventDefault();
                e.stopImmediatePropagation();
                return false;
            });

            // Block options. Each is a link to "#", and each handler stops the link first. The
            // column options below do the same. The menu toggle at the end of this chain is not a
            // link.
            grid_root(editor).on("click", '.drg_item .grid_content_remove', function (e) {
                e.preventDefault();
                if(confirm(I18n("grid_editor.del_content", "Are you sure to delete this content?"))) {
                    fade_out_of_grid(jQuery(this).closest(".drg_item"));
                }
            }).on("click", '.drg_item .grid_content_clone', function (e) {
                e.preventDefault();
                var widget = jQuery(this).closest(".drg_item");
                var widget_clone = widget.clone();
                widget.after(widget_clone);
                editor.trigger("auto_save");
            }).on("click", '.drg_item .grid_content_edit', function (e) {
                e.preventDefault();
                var panel_content = $(this).closest(".drg_item");
                var kind = editable_kind(panel_content);
                if(kind) kind.callback(panel_content.children(".grid_item_content"), editor);
            }).on("click", "a.grid_style_settings", function(e){
                e.preventDefault();
                grid_style_setting($(this), editor);
            }).on("click", ".drg_item > .header_box .dropdown-toggle", function(){
                // this runs before Bootstrap's own handler opens the menu
                var edit_entry = $(this).next(".dropdown-menu").find(".grid_content_edit").parent();
                edit_entry.toggleClass("hidden", !editable_kind($(this).closest(".drg_item")));
            });

            // column dropdown options
            grid_root(editor).on("click", '.grid_col_remove', function (e) {
                e.preventDefault();
                if(confirm(I18n("grid_editor.del_block", "Are you sure to delete this block?"))){
                    fade_out_of_grid(jQuery(this).closest(".drg_column"));
                }
            }).on("click", '.grid_col_clone', function (e) {
                e.preventDefault();
                var widget = jQuery(this).closest(".drg_column");
                var widget_clone = widget.clone();
                // Remove the copy of a block that still fades out: the copy does not fade.
                widget_clone.children(".grid_sortable_items").children("."+DELETED).gridEditorRemove();
                widget.after(widget_clone);
                grid_content_manager(widget_clone.children(".grid_sortable_items"));
                editor.trigger("auto_save");
            });

            //// autosave changes
            //var time_control;
            //$('.panel_grid_body', editor).bind("DOMSubtreeModified",function(){
            //    var thiss = $(this);
            //    if(time_control) clearTimeout(time_control);
            //    time_control = setTimeout(function(){ editor.trigger("auto_save"); }, 5000);
            //});
        }

        // Rebuilding saved content runs the same parsers an applied template goes through, and the text
        // editor is hidden by now with the grid editor not in the page yet: a throw here would leave
        // neither. The content then stays in the text editor, like content that could not be read at all.
        try {
            do_editor_menus(editor);
        } catch(error) {
            // Either way the half-built editor goes, the text editor comes back, and the author is told:
            // thrown on, the error would reach only the text editor's button, which shows nothing to the
            // author who has just confirmed the switch. Over ordinary content it is none of the content's doing.
            editor.gridEditorRemove();
            tinymce_panel.show();
            if(window.console) console.error(error);
            if(saved_body) content_unreadable(); else editor_failed();
            return textarea;
        }
        // The grid editor goes before the panel of the field's text editor, and the field stays
        // immediately after that panel. While the author drags a custom field group, Camaleon
        // removes the text editors of the group and sets them up again at the drop. Camaleon 2.9.4
        // takes the element after the panel of a text editor for the field of that editor.
        // The grid editor goes immediately before the field in these cases:
        // - The field has no text editor of its own.
        // - The text editor has no panel, because the page removed it.
        // - An element is between the panel and the field.
        // The insert is native, because jQuery's before() runs the scripts of a grid that is built
        // again from saved content. A field that has no parent element gets no grid editor, as with
        // jQuery's before().
        var place = tinymce_panel.length && textarea.prev()[0] === tinymce_panel[0] ? tinymce_panel[0] : textarea[0];
        if(place.parentNode){
            place.parentNode.insertBefore(editor[0], place);
            textarea.data(GRID_OF_FIELD, editor);
            editor.data(FIELD_OF_GRID, textarea[0]);
        }

        // The field has a second writer. Core writes the content of the text editor into the field
        // when the text editor loses focus, with each draft and at submit. The text editor does not
        // serialize the export as the grid editor exports it: it changes <b> and rgb(), and
        // flattens bare table rows. (It keeps scripts: see keep_scripts.)
        // For this reason, while the grid editor is visible, each read of the text editor's content
        // as HTML returns the export. The text editor returns its own content:
        // - for a read of its text, its raw content or a selection
        // - while the grid has no export (see exported)
        // - while the grid editor is hidden
        function answer_with_export(e){
            var grid_shown = $.contains(document, editor[0]) && !grid_hidden(editor);
            if(exported !== null && grid_shown && e.format === "html" && !e.selection) e.content = exported;
        }
        tinyEditor.on("GetContent", answer_with_export);

        // The page can remove the text editor of the field and set up a new one while the grid
        // editor stays. Camaleon does this for the text editors of a custom field group that the
        // author sorts. From then on, the grid editor works with the new text editor. A read of
        // that editor returns the export, a grid change goes to it, and the Text Editor link shows
        // its panel. The author stays in the editor that was visible:
        // - While the grid editor is visible, the panel of the new text editor is hidden. The new
        //   text editor gets the export as its content, as after an auto_save, whatever it read
        //   from the field. The field is not written here: each save of the text editor writes
        //   the export. A grid that has no export leaves the new text editor its content.
        // - While the grid editor is hidden, the new text editor keeps the content that it read
        //   from the field. A text editor writes its content into its field when the page removes
        //   it, so this is the content that the author left. left_with and the backup stay. When
        //   the author comes back, show_again compares the new content with left_with as before.
        function take_text_editor(text_editor){
            tinyEditor.off("GetContent", answer_with_export);
            tinyEditor = text_editor;
            tinyEditor.on("GetContent", answer_with_export);
            tinymce_panel = $(tinyEditor.editorContainer);
            if(grid_hidden(editor)) return;
            tinymce_panel.hide();
            if(exported !== null) tinyEditor.setContent(exported);
        }
        // The grid editor takes a new text editor of its field. It also takes a new text editor
        // that replaces the removed text editor that it works with. That editor can be the text
        // editor of another field: a field that has no text editor of its own can use one.
        editor.bind("text_editor_made_again", function(_event, text_editor){
            var of_its_field = built_grid_of(text_editor.targetElm)[0] === editor[0];
            var replaces_its_editor = tinyEditor.removed && tinyEditor.id === text_editor.id;
            if(of_its_field || replaces_its_editor) take_text_editor(text_editor);
        });

        // Keeps the current grid while a new grid replaces it (a template is applied, or the grid
        // is built again from the text editor), in case the build throws an error. It keeps the
        // nodes with their handlers and widgets, and the attributes of the root. restore() puts the
        // grid back. release() removes the kept nodes when the new grid is complete. Without
        // release(), jQuery's data store holds them until the page unloads.
        function set_aside(grid){
            var contents = grid.contents().detach(), attributes = attributes_of(grid);
            return {
                restore: function(){
                    empty_node(grid[0]);
                    set_attributes(grid, attributes);
                    // The kept nodes go back natively, as fill_grid moves nodes in. The browser does
                    // not run a script that it inserted or parsed before.
                    contents.each(function(){ grid[0].appendChild(this); });
                },
                release: function(){ contents.gridEditorRemove(); }
            };
        }

        // Builds the grid again from a grid root parsed from the text editor's content: its
        // attributes, its style and its columns. If a parser throws an error, the previous grid
        // comes back complete, because a partial grid is worse. Returns false in that case.
        function rebuild_grid(body){
            var grid = grid_root(editor);
            var previous = set_aside(grid);
            try {
                // The same sequence as the first build: the class of the root, then the attributes
                // of the content root, then the class that the sortable keeps on its root.
                set_attributes(grid, [{name: "class", value: GRID_ROOT_CLASS}]);
                grid_from(body);
                grid.addClass("ui-sortable");
            } catch(error) {
                if(window.console) console.error(error);
                previous.restore();
                return false;
            }
            previous.release();
            return true;
        }
        // The attributes of an element, as copies of their nodes.
        function attributes_of(element){
            return $.map(element[0].attributes, function(attribute){ return attribute.cloneNode(true); });
        }
        // Gives an element the attributes of a list in place of its own. An item of the list is a node
        // from attributes_of, or a {name, value} pair whose name setAttribute accepts.
        function set_attributes(element, attributes){
            var node = element[0];
            $.each($.makeArray(node.attributes), function(_index, attribute){ node.removeAttributeNode(attribute); });
            $.each(attributes, function(_index, attribute){
                if(attribute.cloneNode) node.setAttributeNode(attribute.cloneNode(true));
                else node.setAttribute(attribute.name, attribute.value);
            });
        }

        // Applies the content that the author changed in the text editor, which is newer than the
        // grid. Returns false if the author must stay in the text editor.
        // - A grid: the grid is built again from it. A save stores that content until the next
        //   auto_save.
        // - Content with the grid marker that does not parse as a grid: it stays in the text
        //   editor, as when the post opens.
        // - Other content: there is no grid to build. The grid stays as the author left it, and a
        //   save stores the grid. The content becomes the backup of the text editor, which gets it
        //   back when the author goes there again.
        function follow_text_editor(content){
            if(!$.fn.isGridEditorContent(content)){
                editor.data("tiny_backup", content);
                return true;
            }
            var body = parse_grid_body(content, true);
            if(!body || !rebuild_grid(body)){
                content_unreadable();
                return false;
            }
            exported = content;
            // the content from before the grid is no longer the backup of the text editor
            editor.removeData("tiny_backup");
            return true;
        }

        // The author comes back from the text editor (see the start of gridEditor). If nothing
        // changed there, the grid and its export stay as they were. The panel of the text editor
        // is hidden when the grid editor shows.
        editor.bind("show_again", function(){
            var hidden = grid_hidden(editor);
            // Compare the markup of the body first, because the same document gives the same
            // content. A read of the content serializes the document (approximately a third of a
            // second for each megabyte). TinyMCE's raw format is not sufficient: it removes a
            // selection attribute also from text that spells one.
            if(hidden && tinyEditor.getBody().innerHTML !== left_with_body){
                var content = tinyEditor.getContent();
                if(content !== left_with && !follow_text_editor(content)) return;
            }
            tinymce_panel.hide();
            editor.show();
            if(hidden) field_follows(tinyEditor, textarea);
            // Clear the state of the last switch to the text editor. The next switch sets it again.
            left_with = left_with_body = null;
        });

        // drag columns
        jQuery(".grid_editor_menu .drg_column", editor).draggable({
            connectToSortable: GRID_ROOT,
            cursor: 'move',          // sets the cursor apperance
            revert: 'invalid',       // makes the item to return if it isn't placed into droppable
            revertDuration: -1,     // duration while the item returns to its place
            opacity: 1,           // opacity while the element is dragged
            helper: "clone"
        });

        //draggable content elements
        jQuery(".grid_editor_menu .drg_item", editor).draggable({
            connectToSortable: "#"+editor_id+" .grid_sortable_items",
            cursor: 'move',          // sets the cursor apperance
            revert: 'invalid',       // makes the item to return if it isn't placed into droppable
            revertDuration: -1,     // duration while the item returns to its place
            opacity: 1,           // opacity while the element is dragged
            zIndex: 1,           // opacity while the element is dragged
            helper: "clone"
        });

        // Sort the parents
        grid_root(editor).sortable({
            tolerance: "pointer",
            cursor: "move",
            revert: false,
            delay: 150,
            dropOnEmpty: true,
            items: ".drg_column",
            connectWith: GRID_ROOT,
            placeholder: "placeholder",
            start: function (e, ui) {
                ui.helper.css({'width': '' , 'height': ''}).addClass('col-md-' + jQuery(ui.helper).attr('data-col'));
                ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).gridEditorInertHtml(ui.helper.gridEditorMarkup()).fadeTo("fast", 0.4);
            },
            over: function (e, ui) {
                ui.placeholder.attr('class', jQuery(ui.helper).attr("class"));
                $(this).addClass("hover-grid");
            },
            out: function (e, ui) {
                $(this).removeClass("hover-grid");
            },
            stop: function (e, ui) {
                ui.item.css({left: "", opacity: "", right: "", bottom: "", top: "", position: ""}).removeAttr("data-original-title").removeAttr("aria-describedby");
                if(!has_menu(ui.item)) parse_content_column(ui.item)
                editor.trigger("auto_save");
            }
        });

        function grid_content_manager(item) {
            // Sort the children (content elements)
            jQuery(item).sortable({
                tolerance: "pointer",
                cursor: "move",
                revert: false,
                delay: 150,
                dropOnEmpty: true,
                items: ".drg_item",
                connectWith: "#"+editor_id+' .grid_sortable_items',
                placeholder: "placeholder",
                start: function (e, ui) {
                    ui.helper.css({'width': '' , 'height': ''}).addClass('col-md-12');
                    ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).gridEditorInertHtml(ui.helper.gridEditorMarkup()).fadeTo("fast", 0.4);
                },
                over: function (e, ui) {
                    $(this).addClass("hover-grid");
                },
                out: function (e, ui) {
                    $(this).removeClass("hover-grid");
                },
                stop: function (e, ui) {
                    ui.item.removeClass('col-md-12').css({left: "", opacity: "", right: "", bottom: "", top: "", position: ""}).removeAttr("data-original-title").removeAttr("aria-describedby");
                    if(!has_menu(ui.item)) parse_content_content(ui.item)
                    editor.trigger("auto_save");
                }
            });
        }

        return textarea;
    }

    // init all required actions for grid editor availability
    function init_grid_editor(){
        // auto switch on grid editor detected
        // A field that already has its grid editor is left as it is: the author stays in the
        // editor that was visible (see grid_takes_text_editor).
        var auto_switch_editor = function(editor){
            if(built_grid_of(editor.targetElm).length) return;
            if($.fn.isGridEditorContent(field_value(editor.targetElm)))
                $(editor.targetElm).gridEditor(editor);
        }
        tinymce_global_settings["init"].push(auto_switch_editor);
        tinymce_global_settings["custom_toolbar"].push("grid_editor");

        // A text editor removes the scripts from its content, and the embed blocks of a grid
        // contain scripts. A grid lost them when it went through a text editor: the author left the
        // grid editor, or edited an Editor block in its form.
        // For this reason, the script element is added to the valid elements of each text editor.
        // The editor then keeps a script as it keeps other elements:
        // - In its document, the script has a type that a browser does not run.
        // - The editor returns the script under its own type, with its text unchanged.
        // This applies to all the content of each text editor on a page that loads the grid editor.
        // Core applies its rules when the content is saved.
        // The rule is added to the settings of the editor, before the editor reads them. The
        // settings object of the page is not changed. The rule is added only if the editor has no
        // rule for the script element:
        // - A rule of the page for the script element stays in effect, also a narrower rule. The
        //   editor uses the last rule that it gets for an element.
        // - A rule for all elements ("*[...]") does not count. With only that rule, the editor
        //   keeps a script but removes the attributes that the script loads with.
        var SCRIPTS = "script[*]";
        var keep_scripts = function(editor){
            var settings = editor.settings;
            if(new tinymce.html.Schema(settings).elements.script) return;
            var elements = settings.extended_valid_elements || "";
            settings.extended_valid_elements = (elements ? elements + "," : "") + SCRIPTS;
        }

        // A paste is different. Its markup can come from any page, and a pasted script stays in the
        // editor where the author does not see it. The paste filter of the editor removed scripts
        // by the list of valid elements, which now includes the script element. For this reason,
        // the scripts are removed here from all pasted or dropped markup. Markup that says it was
        // copied in the editor also loses its scripts, because any markup can say that.
        // - The markup is parsed with the parser and the schema of the editor, as the editor reads
        //   it later. A browser reads some markup differently and finds no script where the editor
        //   finds one: a script after a plaintext tag or an incomplete tag, in a comment that a
        //   noscript ends early for the editor, or in a template.
        // - The work is done at PastePreProcess. At PastePostProcess, the editor first parses the
        //   markup in its own document. There, the handler of an element that does not load runs on
        //   the admin page.
        // - The listener is added at PreInit, after the plugins of the editor add theirs. The
        //   filters of the paste plugin then run first. The filter that removes style attributes
        //   from tags can make a script tag from a tag that spelled none.
        // - A paste that spells no script at that time is not changed.
        var paste_without_scripts = function(editor){
            editor.on("PreInit", function(){
                editor.on("PastePreProcess", function(e){
                    if(!/<script/i.test(e.content)) return;
                    // parse with the settings of the editor, as its parser reads inserted content
                    var parser = new tinymce.html.DomParser(editor.settings, editor.schema);
                    var root = parser.parse(e.content, {forced_root_block: false, isRootContent: true});
                    // Remove the scripts, and the nodes that can hide a script from this filter:
                    // - A comment or a CDATA section. The editor reads it to its end. A browser can
                    //   end it at the first ">" ("<!--->", "<![CDATA[ >") and read the remainder as
                    //   markup.
                    // - A processing instruction. The editor writes "<?xml ?>" as "<?xml?>", and
                    //   its next read continues to the first "/>", one tag too far. Raw text after
                    //   it can then become a script.
                    // These three are not content. Collect the nodes first: remove() unlinks a
                    // node, and a walk that continues from an unlinked node stops there.
                    var removed = [];
                    for(var node = root.firstChild; node; node = node.walk()){
                        if(node.name === "script" || node.type === 4 || node.type === 7 || node.type === 8) removed.push(node);
                    }
                    for(var i = 0; i < removed.length; i++) removed[i].remove();
                    e.content = new tinymce.html.Serializer({validate: editor.settings.validate}, editor.schema).serialize(root);
                });
            });
        }

        // The editor puts each top-level node of its content that is not a block into a paragraph.
        // A top-level script then comes back in a paragraph that nobody wrote. The parser of the
        // editor already reads a script as a block, but the block element map of the editor does
        // not have it. The editor reads that map by two names:
        // - "SCRIPT", for an element of the editor's document. The code that adds the paragraph,
        //   and the lists plugin, test if the map has the name. (Before TinyMCE 4.7.4, the minimum
        //   for the gem, that code tests the value.) The block test of the editor, Indent and the
        //   search test the value. The search ignores the text of a script only while the script is
        //   not a block. For this reason, the name is in the map with the value false: no paragraph
        //   is added, and the search and Indent ignore the script.
        // - "script", for markup that goes into the editor. Here the script is a block, as it is
        //   for the parser. When inserted markup ends with a script that has a src, the caret stays
        //   before that script, not after it as bare text. (After a script with text, the editor
        //   stops at that text, and the caret stays after the markup.)
        // The two names are set at PreInit, before the editor gets its content.
        var script_takes_no_paragraph = function(editor){
            editor.on("PreInit", function(){
                var blocks = editor.schema.getBlockElements();
                blocks.SCRIPT = false;
                blocks.script = {};
            });
        }

        // Finds the end of a script as a browser does. TinyMCE ends a script at the first closing
        // tag, or at a tag that only starts like one ("</scriptx>"). A browser reads the text of a
        // script differently. "<!--" starts a comment, and "<script" in that comment starts a
        // second script. The next closing tag then ends the second script, not the element. An old
        // technique hides a script in a comment and writes a second script from it. TinyMCE cut
        // such a script at the tag that it writes and showed the remainder as text. The public
        // page, in a browser, read from the cut into the content after it.
        // TinyMCE gets the end of such an element from its schema: an object that it asks for the
        // next closing tag (the media plugin sets one for a video). The entry for the script now
        // uses the rules that the HTML standard gives for the text of a script.
        var script_end = {
            lastIndex: 0,
            exec: function(markup){
                var marks = /<!(?=--)|-->|<\/?script(?=[\t\n\f\r \/>])/gi, closing = /<\/script[^>]*>/gi;
                var TEXT = 0, COMMENT = 1, WRITTEN = 2, state = TEXT, mark;
                marks.lastIndex = this.lastIndex;
                while((mark = marks.exec(markup))){
                    var found = mark[0].toLowerCase();
                    if(found === "<!"){ if(state === TEXT) state = COMMENT; }
                    else if(found === "-->") state = TEXT;
                    else if(found === "<script"){ if(state === COMMENT) state = WRITTEN; }
                    else if(state === WRITTEN) state = COMMENT;
                    else {
                        closing.lastIndex = mark.index;
                        return closing.exec(markup);
                    }
                }
                return null;
            }
        };
        var script_ends_as_in_a_browser = function(editor){
            editor.on("PreInit", function(){ editor.schema.getSpecialElements().script = script_end; });
        }

        // A plugin of the editor can mark text with its own elements (for example, a visible
        // no-break space). The editor removes them when its content is read, but in a script they
        // come back as part of the script text. For this reason, the elements in each script are
        // removed, and their text stays. PreProcess gets a copy that the editor makes for the read:
        // the marks stay in the editor, for the plugin to remove. The copy is queried directly: the
        // select() of the editor walks each element of the copy at each read, which takes some
        // milliseconds for a long post.
        var script_text_alone = function(editor){
            editor.on("PreProcess", function(e){
                if(e.node.nodeType !== 1) return;
                editor.dom.remove(e.node.querySelectorAll("script *"), true);
            });
        }

        // An undo level holds the markup of the editor's document, not a read of its content. When
        // the editor writes a level back, it reads the content of a script as text, and the markup
        // of the marks becomes part of the script text. For this reason, the listener removes the
        // marks from the scripts of the document before the editor stores a level. A browser does
        // not show a script, so the author sees no change.
        // The editor makes the level before BeforeAddUndo, from the document with the marks. The
        // listener asks the editor for a second level, stops it before the editor stores it, and
        // copies its content into the first level. The caller of add() and the listeners after this
        // one then see one level, as when no script has marks. A listener that was added before
        // this one sees both levels.
        var undo_levels_without_marks = function(editor){
            var clean_level = null;
            editor.on("BeforeAddUndo", function(e){
                if(clean_level){
                    clean_level.found = e.level;
                    e.preventDefault();
                    e.stopImmediatePropagation();
                    return;
                }
                if(e.isDefaultPrevented()) return;
                var marks = editor.getBody().querySelectorAll("script *");
                if(!marks.length) return;
                editor.dom.remove(marks, true);
                clean_level = {};
                try { editor.undoManager.add(); } finally {
                    if(clean_level.found) tinymce.util.Tools.extend(e.level, clean_level.found);
                    clean_level = null;
                }
            });
        }

        // The field has a third writer. Before the page unloads, each text editor writes its raw
        // content into its field: the markup of the editor, with each script under the type that
        // the editor gives it. If the author cancels the unload at the unsaved-changes prompt, the
        // fields keep that markup. At the next grid change or switch of editors, a post in more
        // than one language composes its content from its fields. The other languages are then
        // stored as raw content.
        // TinyMCE triggers no GetContent for that write, but it triggers RawSaveContent before each
        // raw save. The listener replaces the raw content with the content that the other saves
        // write (the export of a visible grid, see gridEditor). An editor that TinyMCE hid, so that
        // the author can edit its field, writes nothing. An editor with the unload write disabled
        // also writes nothing.
        var content_at_unload = function(editor){
            editor.on("RawSaveContent", function(e){ e.content = editor.getContent({save: true}); });
        }

        // The page can set up a text editor for a field that has its grid editor. The grid editor
        // then takes that text editor (see take_text_editor). The hook tells each grid editor at
        // "init", when the new text editor has its panel and its content. Each grid editor decides
        // if it takes the new text editor. A grid editor outside the page takes no text editor: the
        // author cannot see that grid editor. For the new text editor, the field then has no grid
        // editor (see built_grid_of).
        var grid_takes_text_editor = function(editor){
            editor.on("init", function(){
                $(".panel_grid_editor").each(function(){
                    $(this).triggerHandler("text_editor_made_again", [editor]);
                });
            });
        }

        // Each text editor of the page gets the eight hooks when TinyMCE adds it, before it reads its
        // settings. The hooks of core do not reach each editor. The settings hook runs when core
        // makes its settings, and the editor hooks run from the setup of those settings. A page can
        // add its own lists to the settings of core, pass its own setup, or set up an editor
        // without those settings.
        tinymce.on("AddEditor", function(added){
            keep_scripts(added.editor);
            paste_without_scripts(added.editor);
            script_takes_no_paragraph(added.editor);
            script_ends_as_in_a_browser(added.editor);
            script_text_alone(added.editor);
            undo_levels_without_marks(added.editor);
            content_at_unload(added.editor);
            grid_takes_text_editor(added.editor);
        });

        // grid editor button
        var grid_editor_button = function(editor){
            editor.addButton('grid_editor', {
                text: 'Grid Editor',
                icon: false,
                onclick: function(){
                    if(!confirm(I18n("grid_editor.switch_editor", "Are you sure to change the editor?"))) return false;
                    // The first grid of a field is built from the field. The field holds the last
                    // write of the text editor (at a focus loss or with a draft). For this reason,
                    // the text editor writes the field first. A listener can throw an error at that
                    // write, or at the read when a grid shows again. The author then gets the same
                    // message as when the grid cannot be built. If the grid editor is already
                    // visible when the error comes (a field listener, at the field write), it stays
                    // visible and no message shows.
                    try {
                        field_follows(editor, $(editor.targetElm));
                        $(editor.targetElm).gridEditor(editor);
                    } catch(error) {
                        if(window.console) console.error(error);
                        var grid = built_grid_of(editor.targetElm);
                        if(!grid.length || grid_hidden(grid)) editor_failed();
                    }
                }
            });
        }
        tinymce_global_settings["setups"].push(grid_editor_button);
    }
});