jQuery(function(){
    init_grid_editor();

    $.fn.fadeDestroy = function(speed){ $(this).fadeOut(speed, function(){ $(this).remove(); }) }
    $.fn.isGridEditorContent = function(str){ return str.match(/^\<div\>\[grid_editor/); } // verify is text is a content for grid editor
    // remove libraries shortcode text from grid editor: the marker only, up to ITS closing bracket - a greedy
    // match would run on to the last "]</div>" of the content and take the grid along. Whatever isGridEditorContent
    // takes for a marker comes off, with or without a libraries list: a marker left in would be read as the grid.
    $.fn.skipGridEditorLibraries = function(str){ return str.replace(/^\<div\>\[grid_editor[^\]]*\]\<\/div\>/, ""); }
    $.fn.gridEditor_extra_rows = [];
    $.fn.gridEditor_libraries = [];
    //********************** editor content options **********************//
    $.fn.gridEditor_options = {
        text: {title: "Text", description: "Permit you to include text plain in any column.", libraries: [], callback: grid_text_builder},
        editor: {title: "Editor", description: "Permit you to include text html in any column.", libraries: [], callback: grid_editor_builder},
        tab: {title: "Tabs", description: "Permit you to include tabs container in any col.", callback: grid_tab_builder},
        slider: {title: "Slider", description: "Permit you to include a slider animation in any col.", callback: grid_slider_builder},
        image: {title: "Image", description: "Permit you to include an image.", callback: grid_image_builder},
        video: {title: "Video", description: "Permit you to include a video.", callback: grid_video_builder},
        audio: {title: "Audio", description: "Permit you to include a audio.", callback: grid_audio_builder},
        accordion: {title: "Accordion", description: "Permit you to include an accordion in any column.", callback: grid_accordion_builder},
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
    // one, or takes it along into a tag that never ends, as it would the markup of the block. Such a
    // label is text the author typed, and is escaped like text.
    function label_is_markup(label){
        label = String(label);
        if(label.indexOf("<") >= 0){
            var probe = inert().createElement("div");
            probe.innerHTML = label + "<i data-grid-label-end></i>";
            if(!probe.querySelector("i[data-grid-label-end]")) return false;
            if(probe.getElementsByTagName("*").length > 1 || /<[!?]/.test(label)) return true;
        }
        return /&(#\d+|#x[0-9a-f]+|[a-z][a-z0-9]*);/i.test(label);
    }
    $.fn.gridEditorLabelSource = function(element){
        element = $(element);
        if(!element.length) return "";
        var text = element.text();
        return $.trim(!element.children().length && !label_is_markup(text) ? text : element.html());
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
            $(target).empty();
            $.each(parse_nodes(markup == null ? "" : markup), function(){ target.appendChild(this); });
        });
    };

    // A value on its way into a quoted attribute of a markup string. The block builders assemble their
    // markup by concatenation: a url holding a quote would end the attribute and go on as markup of
    // its own. The browser reads the escaped value back as the same url, on the public page too.
    $.fn.gridEditorEscapeHtml = function(text){
        return String(text == null ? "" : text).replace(/[&<>"']/g, function(character){
            return {"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;"}[character];
        });
    };

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
        send().always(function(){ holder.removeData("grid_editor_request"); });
    };

    // Opens the panel a templates menu link points at - the list, the template form - in a modal.
    // Core's ajax_modal would show whatever a 200 carries, and the menu is built from what the page
    // knew when it loaded: a session gone or a permission taken away since then comes back as the
    // login or dashboard page. The panel is fetched and checked first, and only a panel is shown.
    function open_templates_modal_on_click(links, callback){
        links.click(function(e){
            e.preventDefault();
            var link = $(this);
            $.fn.gridEditor_one_request(link.closest(".panel_grid_editor"), function(){
                return $.get(link.attr("href")).done(function(res){
                    $.fn.gridEditor_show_templates_panel(res, function(panel){
                        open_modal({title: link.attr("title"), content: panel, callback: callback});
                    });
                }).fail($.fn.gridEditor_request_failed);
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

    // grid editor plugin
    var gridEditor_id = 0;
    $.fn.gridEditor = function(tinyEditor){
        // one editor per field, as jQuery's before() gave each field of a set its own
        if(this.length > 1) return this.each(function(){ $(this).gridEditor(tinyEditor); });
        var textarea = $(this);
        // an editor built earlier for this field is only shown again: nothing to read, nothing to build
        var existing_editor = textarea.prev().hasClass("panel_grid_editor");
        // Content marked as a grid that cannot be read as one stays in the text editor: shown as an
        // empty grid, its first change would be auto-saved over the content nobody got to see.
        var saved_body = null;
        if(!existing_editor && $.fn.isGridEditorContent(textarea.val())){
            saved_body = parse_grid_body(textarea.val(), true);
            if(!saved_body){
                content_unreadable();
                return textarea;
            }
        }
        gridEditor_id ++;
        var tinymce_panel = $(tinyEditor.editorContainer).hide();
        var editor_id = "grid_editor_"+gridEditor_id;
        if(existing_editor){ textarea.prev().show(); return textarea; }
        var tpl_rows = "";
        $.each({6: 50, 4: 33, 3: 25, 2: 16, 8: 66, 9: 75, 12: 100}, function(k, val){ tpl_rows += '<div class="" data-col="'+k+'" title="Insert a column block with '+val+'% of width." data-col_title="'+val+'%"><div class="grid_sortable_items"></div></div>'; });

        // break line
        tpl_rows += '<div class="clearfix" title="Insert a break line to have ordered column blocks." data-col_title="Break Line" data-col="12"></div>' + $.fn.gridEditor_extra_rows.join("");

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
            save_template_entry = '<li class="'+(can_manage_templates ? '' : 'hidden')+'"><a class="new_template" title="New Template" href = "'+root_url+'/admin/plugins/camaleon_editor/grid_editor/new" >'+I18n("grid_editor.save_tpl")+'</a></li >';
        }

        // template grid editor
        var editor = $("<div class='panel_grid_editor' id='"+editor_id+"'>"+
            "<div class='grid_editor_menu'>"+
            "<ul class='nav nav-tabs'>"+
            "<li class='active'><a href='#grid_columns_"+gridEditor_id+"' role='tab' data-toggle='tab'><i class='fa fa-th-list'></i> "+I18n("grid_editor.blocks")+"</a></li>"+
            "<li class=''><a href='#grid_contents_"+gridEditor_id+"' role='tab' data-toggle='tab'><i class='fa fa-table'></i> "+I18n("grid_editor.contents")+"</a></li>"+
            '<li>' +
            '<a class="dropdown-toggle" href="#" type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false">'+I18n("grid_editor.templates")+' <span class="caret"></span> </a>'+
            '<ul class="dropdown-menu" aria-labelledby="dropdownMenu1"> ' +
            '<li><a class="list_templates" title="Grid Templates" href = "'+root_url+'admin/plugins/camaleon_editor/grid_editor" >'+I18n("grid_editor.list")+'</a></li >'+
            save_template_entry+
            "<li><a class='grid_style_settings' title='Style Settings' href='#'><i class='fa fa-paint-brush'></i> "+I18n("button.settings")+"</a></li>"+
            '</ul> ' +
            '</li>'+
            "<li class=''><a href='#' class='clear'><i class='fa fa-trash'></i>  "+I18n("grid_editor.clear")+"</a></li>"+
            "<li class=''><a href='#' class='toggle_panel_grid'><i class='fa fa-share'></i>  "+I18n("grid_editor.text_editor")+"</a></li>"+
            "<li class='pull-right'><label style='margin: 0px;'><input class='toggle_preview_grid' type='checkbox'/> "+I18n("grid_editor.preview")+"</label><br><label style='margin: 0px;'><input class='toggle_fullscreen_grid' type='checkbox'/> "+I18n("grid_editor.fullscreen")+"</label></li>"+
            "</ul>"+
            "<div class='tab-content'>"+
            "<div role='tabpanel' class='tab-pane active' id='grid_columns_"+gridEditor_id+"'> "+
            '<p class="text-info">Drag and drop this blocks(Column Blocks) in the area below. </p>'+
            tpl_rows+
            " </div>"+
            "<div role='tabpanel' class='tab-pane' id='grid_contents_"+gridEditor_id+"'>"+
            '<p class="text-info">Drag and drop this blocks(Content Blocks) in any Column Block. </p>'+
            tpl_options+
            "</div>"+
            "</div>"+
            "</div>"+
            "<div class='panel_grid_body_w'><div class='panel_grid_body row'></div></div>"+
            "</div>");

        // The editor's grid: the root its own wrapper holds, and that one alone. A block may hold grid
        // markup of its own - pasted in, or applied with a template - which is that block's content:
        // found by class anywhere under the editor, it would be parsed, styled, emptied and made
        // sortable along with the grid, and saved with the editor's chrome in it.
        var GRID_ROOT = "#"+editor_id+" > .panel_grid_body_w > .panel_grid_body"; // for the widgets that take a selector
        function grid_root(editor){ return $(editor).children(".panel_grid_body_w").children(".panel_grid_body"); }

        // grid editor export
        function export_content(editor){
            var container = grid_root(editor).clone();
            container.children().each(function(){
                var col = $(this).removeClass("drg_column grid-col-built btn-default btn ui-draggable ui-draggable-handle ui-draggable-dragging ui-sortable-handle");
                col.children(".header_box").remove();
                // the column's own area and blocks: what a block holds is content, chrome-like names included
                col.children(".grid_sortable_items").removeClass("ui-sortable").children().each(function(){ //contents
                    $(this).removeClass("drg_item btn-default grid-item-built btn ui-draggable ui-draggable-dragging ui-sortable-handle ui-draggable-handle").children(".header_box").remove();
                });
            });
            var res = container[0].outerHTML;
            container.remove();
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
                if(!body.length) body = elements.filter(function(){ return $(this).children("[data-col]").length > 0; }).first();
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
        // save. Now that the editor keeps its own root, those are carried over to it.
        function keep_root_attributes(grid, root){
            $.each(root[0].attributes, function(_index, attribute){
                // the saved classes as they are - a root saved without "row" does not get it back - plus
                // the one the editor finds its grid by
                if(attribute.name === "class") grid.attr("class", attribute.value).addClass("panel_grid_body");
                else if($.inArray(attribute.name, GRID_STYLE_ATTRIBUTES) < 0) grid.attr(attribute.name, attribute.value);
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

        // parse column editor
        // column: content element
        // skip_options: boolean to add drodown options
        function parse_content_column(column, skip_options){
            // the title comes from stored content: it goes in as text, never as markup
            var html = $('<div class="header_box"><a><i class="fa fa-stop"></i> </a></div>');
            html.children("a").append(document.createTextNode(column.attr("data-col_title") || ""));
            var options = "<div class='dropdown'>" +
                "<a class='dropdown-toggle' data-toggle='dropdown'>&nbsp; <span class='caret'></span></a>" +
                "<ul class='dropdown-menu auto_with pull-right' role='menu'>"+
                "<li><a class='grid_col_remove' title='Remove' href='#'><i class='fa fa-trash-o'></i> "+I18n("button.delete")+"</a></li>"+
                "<li><a class='grid_col_clone' title='Clone' href='#'><i class='fa fa-copy'></i> "+I18n("button.clone")+"</a></li>"+
                "<li><a class='grid_style_settings' title='Style Settings' href='#'><i class='fa fa-paint-brush'></i> "+I18n("button.settings")+"</a></li>"+
                "</ul>"+
                "</div>" ;
            column.addClass("drg_column btn btn-default");
            if(column.children(".header_box").length == 0) column.prepend(html);
            if(!skip_options){
                // the column's own header, area and blocks: a block may hold grid markup of its own
                column.children('.header_box').append(options);
                grid_content_manager(column.children(".grid_sortable_items"));
                column.children(".grid_sortable_items").children().each(function(){ //contents
                    parse_content_content($(this));
                });
            }
            column;
        }

        // parse column editor
        // content: content element
        // skip_options: boolean to add drodown options
        function parse_content_content(content, skip_options){
            var t = "unknown";
            try{ t = $.fn.gridEditor_options[content.attr("data-kind")].title }catch(e){}
            var html = '<div class="header_box">'+
                '<a><i class="fa fa-keyboard-o"></i> '+ t +'</a>'+
                '</div>';
            var options = "<div class='dropdown'>" +
                "<a class='dropdown-toggle' data-toggle='dropdown'>&nbsp; <span class='caret'></span></a>" +
                "<ul class='dropdown-menu auto_with pull-right' role='menu'>"+
                "<li><a class='grid_content_remove' title='Remove' href='#'><i class='fa fa-trash-o'></i> "+I18n("button.delete")+"</a></li>"+
                "<li><a class='grid_content_clone' title='Clone' href='#'><i class='fa fa-copy'></i> "+I18n("button.clone")+"</a></li>"+
                "<li><a class='grid_content_edit' title='Edit' href='#'><i class='fa fa-pencil'></i> "+I18n("button.edit")+"</a></li>"+
                "<li><a class='grid_style_settings' title='Style Settings' href='#'><i class='fa fa-paint-brush'></i> "+I18n("button.settings")+"</a></li>"+
                "</ul>"+
                "</div>";
            content.addClass("drg_item btn btn-default");
            if(content.children(".header_box").length == 0) content.prepend(html);
            if(!skip_options){
                content.children('.header_box').append(options);
            }
            // save used libraries
            $.fn.gridEditor_libraries = $.merge($.fn.gridEditor_libraries, $.fn.gridEditor_options[content.attr("data-kind")] || {})
            content;
        }

        // add editor menu actions
        function do_editor_menus(editor){
            // toggle editor menus
            editor.find(".grid_editor_menu .toggle_panel_grid").click(function(){
                if(!confirm(I18n("grid_editor.toggle_editor"))) return false;
                editor.hide();
                if(editor.data("tiny_backup")) tinyEditor.setContent(editor.data("tiny_backup"));
                tinymce_panel.show();
                return false;
            });
            editor.find(".grid_editor_menu .clear").click(function(){
                if(!confirm(I18n("grid_editor.clear_editor"))) return false;
                grid_root(editor).html("");
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
                grid_style_setting(grid_root(editor), editor, grid_root(editor));
                e.preventDefault();
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
                            // the current grid is set aside as nodes, handlers included, in case the rebuild fails
                            previous = {contents: grid.contents().detach(), grid_style: grid_style(grid)};
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
                                    set_grid_style(grid, previous.grid_style);
                                    grid.empty().append(previous.contents);
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
                        // Past the guard, where nothing can send the applied template back any more. The grid set
                        // aside with its handlers and widgets for a rollback that did not come is released for good,
                        // or jQuery's data store would hold every replaced grid for the life of the page; and only
                        // now does the list close: every failure leaves it open. A listener of the modal's that
                        // throws is no failure of the apply.
                        previous.contents.remove();
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
                // filled rather than swapped in as live nodes, which would run the saved content's scripts
                keep_root_attributes(grid_root(editor), saved_body);
                fill_grid(grid_root(editor), saved_body);
                parse_content(editor); // recover saved content
            }else{
                editor.data("tiny_backup", tinyEditor.getContent())
            }

            // trigger auto save changes
            editor.bind("auto_save", function(){
                var txt = "<div>[grid_editor data='"+$.fn.gridEditor_libraries.join(",")+"']</div>"+export_content($(this));
                tinyEditor.setContent(txt);
                textarea.val(txt).trigger("change_in");
            });

            // content dropdown options
            grid_root(editor).on("click", '.drg_item .grid_content_remove', function (e) {
                if(confirm(I18n("grid_editor.del_block"))) {
                    jQuery(this).closest(".drg_item").fadeDestroy();
                    editor.trigger("auto_save");
                }
                e.preventDefault();
            }).on("click", '.drg_item .grid_content_clone', function (e) {
                var widget = jQuery(this).closest(".drg_item");
                var widget_clone = widget.clone();
                widget.after(widget_clone);
                editor.trigger("auto_save");
                e.preventDefault();
            }).on("click", '.drg_item .grid_content_edit', function (e) {
                var panel_content = $(this).closest(".drg_item");
                var key = panel_content.attr("data-kind");
                $.fn.gridEditor_options[key]["callback"](panel_content.children(".grid_item_content"), editor);
                e.preventDefault();
            }).on("click", "a.grid_style_settings", function(e){
                grid_style_setting($(this), editor);
                e.preventDefault();
            });

            // column dropdown options
            grid_root(editor).on("click", '.grid_col_remove', function (e) {
                if(confirm(I18n("grid_editor.del_block"))){
                    jQuery(this).closest(".drg_column").fadeDestroy();
                    editor.trigger("auto_save");
                }
                e.preventDefault();
            }).on("click", '.grid_col_clone', function (e) {
                var widget = jQuery(this).closest(".drg_column");
                var widget_clone = widget.clone();
                widget.after(widget_clone);
                grid_content_manager(widget_clone.children(".grid_sortable_items"));
                editor.trigger("auto_save");
                e.preventDefault();
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
            editor.remove();
            tinymce_panel.show();
            if(window.console) console.error(error);
            if(saved_body) content_unreadable(); else editor_failed();
            return textarea;
        }
        // inserted natively: jQuery's before() would run the scripts of the grid just rebuilt from saved content
        // like jQuery's before(), nothing to do for a field that is not in a document yet
        if(textarea[0].parentNode) textarea[0].parentNode.insertBefore(editor[0], textarea[0]);

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
                ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).gridEditorInertHtml(ui.helper.html()).fadeTo("fast", 0.4);
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
                if(!jQuery(ui.item).hasClass('grid-col-built')) parse_content_column(ui.item)
                ui.item.addClass('grid-col-built');
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
                    ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).gridEditorInertHtml(ui.helper.html()).fadeTo("fast", 0.4);
                },
                over: function (e, ui) {
                    $(this).addClass("hover-grid");
                },
                out: function (e, ui) {
                    $(this).removeClass("hover-grid");
                },
                stop: function (e, ui) {
                    ui.item.removeClass('col-md-12').css({left: "", opacity: "", right: "", bottom: "", top: "", position: ""}).removeAttr("data-original-title").removeAttr("aria-describedby");
                    if(!jQuery(ui.item).hasClass('grid-item-built')) parse_content_content(ui.item)
                    ui.item.addClass('grid-item-built');
                    editor.trigger("auto_save");
                }
            });
        }

        return textarea;
    }

    // init all required actions for grid editor availability
    function init_grid_editor(){
        //auto switch on grid editor detected
        var auto_switch_editor = function(editor){
            if($.fn.isGridEditorContent($(editor.targetElm).val()))
                $(editor.targetElm).gridEditor(editor);
        }
        tinymce_global_settings["init"].push(auto_switch_editor);
        tinymce_global_settings["custom_toolbar"].push("grid_editor");

        // grid editor button
        var grid_editor_button = function(editor){
            editor.addButton('grid_editor', {
                text: 'Grid Editor',
                icon: false,
                onclick: function(){
                    if(!confirm("Are you sure to change the editor?")) return false;
                    var area = $(editor.targetElm).gridEditor(editor);
                }
            });
        }
        tinymce_global_settings["setups"].push(grid_editor_button);
    }
});