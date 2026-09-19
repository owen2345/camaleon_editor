jQuery(function(){
    init_grid_editor();

    $.fn.fadeDestroy = function(speed){ $(this).fadeOut(speed, function(){ $(this).remove(); }) }
    $.fn.isGridEditorContent = function(str){ return str.match(/^\<div\>\[grid_editor/); } // verify is text is a content for grid editor
    $.fn.skipGridEditorLibraries = function(str){ return str.replace(/^\<div\>\[grid_editor (.*)\]\<\/div\>/, ""); } // remove libraries shortcode text from grid editor
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

    // grid editor plugin
    var gridEditor_id = 0;
    $.fn.gridEditor = function(tinyEditor){
        gridEditor_id ++;
        var tinymce_panel = $(tinyEditor.editorContainer).hide();
        var editor_id = "grid_editor_"+gridEditor_id;
        var textarea = $(this);
        if(textarea.prev().hasClass("panel_grid_editor")){ textarea.prev().show(); return textarea; }
        var tpl_rows = "";
        $.each({6: 50, 4: 33, 3: 25, 2: 16, 8: 66, 9: 75, 12: 100}, function(k, val){ tpl_rows += '<div class="" data-col="'+k+'" title="Insert a column block with '+val+'% of width." data-col_title="'+val+'%"><div class="grid_sortable_items"></div></div>'; });

        // break line
        tpl_rows += '<div class="clearfix" title="Insert a break line to have ordered column blocks." data-col_title="Break Line" data-col="12"></div>' + $.fn.gridEditor_extra_rows.join("");

        // tpl options
        var tpl_options = "";
        $.each($.fn.gridEditor_options, function(key, item){ tpl_options += '<div class="" data-kind="'+key+'" title="'+item["description"]+'"><div class="grid_item_content grid_item_'+key+'"></div></div>'; });

        // Saving a template needs the template-management permission, and the page says who lacks it.
        // A page that loaded the editor without saying keeps the entry: hiding it is a courtesy, the
        // server is what refuses, and an administrator must not lose the action to a missing variable.
        var can_manage_templates = window.cama_grid_editor_can_manage_templates !== false;

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
            (can_manage_templates ? '<li><a class="new_template" title="New Template" href = "'+root_url+'/admin/plugins/camaleon_editor/grid_editor/new" >'+I18n("grid_editor.save_tpl")+'</a></li >' : '')+
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

        // grid editor export
        function export_content(editor){
            var container = $('.panel_grid_body', editor).clone();
            container.children().each(function(){
                var col = $(this).removeClass("drg_column grid-col-built btn-default btn ui-draggable ui-draggable-handle ui-draggable-dragging ui-sortable-handle");
                col.children(".header_box").remove();
                col.find(".grid_sortable_items").removeClass("ui-sortable").children().each(function(){ //contents
                    $(this).removeClass("drg_item btn-default grid-item-built btn ui-draggable ui-draggable-dragging ui-sortable-handle ui-draggable-handle").children(".header_box").remove();
                });
            });
            var res = container[0].outerHTML;
            container.remove();
            return res;
        }

        // the grid body of a fetched template, or null when the response is not one. A refused or signed
        // out request is redirected, and the request follows it to a 200: without this check the
        // dashboard or login page would be written into the grid and auto-saved over the post content.
        // Parsed in a document of its own, where nothing loads or runs, and with its scripts kept: a
        // template's embed blocks carry them, and they belong to the grid as much as the markup does.
        function template_grid_body(res){
            var inert_document = document.implementation.createHTMLDocument("");
            var nodes = $.parseHTML($.trim($.fn.skipGridEditorLibraries(String(res))), inert_document, true) || [];
            var elements = $(nodes).filter(function(){ return this.nodeType === 1; });
            var body = elements.filter(".panel_grid_body").first();
            // A template stored by other means may wrap its columns in a plain div. A page never parses to
            // a lone div: its head leaves title, meta and link elements at the top level.
            if(!body.length && elements.length === 1 && elements.is("div")) body = elements;
            return body.length ? body : null;
        }

        // grid editor parser to recover from saved content
        function parse_content(editor){
            editor.find(".panel_grid_body").children("div").each(function(){ var col = parse_content_column($(this)); });
            return editor;
        }

        // parse column editor
        // column: content element
        // skip_options: boolean to add drodown options
        function parse_content_column(column, skip_options){
            var html = '<div class="header_box">'+
                '<a><i class="fa fa-stop"></i> '+column.attr("data-col_title")+'</a>'+
                '</div>';
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
                column.find('.header_box').append(options);
                grid_content_manager(column.find(".grid_sortable_items"));
                column.find(".grid_sortable_items").children().each(function(){ //contents
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
                content.find('.header_box').append(options);
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
                editor.find(".panel_grid_body").html("");
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
                grid_style_setting(editor.find(".panel_grid_body"), editor, editor.find(".panel_grid_body"));
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
            editor.find(".grid_editor_menu .list_templates").ajax_modal({callback: function(modal){
                modal.on("click", ".import_item", function(e){
                    // the template url is request data, never a place to go: leaving the page drops the unsaved post
                    e.preventDefault();
                    if(!confirm($(this).attr("data-message"))) return false;
                    showLoading();
                    // the list stays open on a failure, so another template can be picked
                    var import_failed = function(){
                        $.fn.alert({type: "error", title: I18n("grid_editor.import_failed", "The template could not be loaded.")});
                    };
                    $.get($(this).attr("data-url"), function(res){
                        var template_body = template_grid_body(res);
                        if(!template_body) return import_failed();
                        modal.modal("hide");
                        var grid = editor.find(".panel_grid_body");
                        // the style of the whole grid (Templates > Settings) lives on the root, not inside it
                        var set_grid_style = function(style){
                            $.each(style, function(name, value){
                                if(value === undefined) grid.removeAttr(name); else grid.attr(name, value);
                            });
                        };
                        // the current grid is set aside as nodes, handlers included, in case the rebuild fails
                        var previous = {contents: grid.contents().detach(), style: {"style": grid.attr("style"), "data-style": grid.attr("data-style")}};
                        try {
                            set_grid_style({"style": template_body.attr("style"), "data-style": template_body.attr("data-style")});
                            grid.html(template_body.html());
                            parse_content(editor); // recover saved content
                            editor.trigger("auto_save");
                        } catch(error) {
                            // A parser or an auto_save listener threw part-way: a half-built grid that the post content
                            // may not match is worse than no template, so the grid goes back to what it was.
                            set_grid_style(previous.style);
                            grid.empty().append(previous.contents);
                            try { editor.trigger("auto_save"); } catch(resync_error) {}
                            if(window.console) console.error(error);
                            import_failed();
                        } finally {
                            // the list is gone by now, so nothing may keep the overlay up
                            hideLoading();
                        }
                    }).fail(import_failed);
                    return false;
                });
            }});

            // save as a new template
            editor.find(".grid_editor_menu .new_template").ajax_modal({callback: function(modal){
                modal.find("textarea").val(export_content(editor));
            }});

            // parse menu options
            editor.find("#grid_columns_"+gridEditor_id).children("div").each(function(){ parse_content_column($(this), true) });
            editor.find("#grid_contents_"+gridEditor_id).children("div").each(function(){ parse_content_content($(this), true) });

            // tooltips
            editor.find(".grid_editor_menu .drg_item, .grid_editor_menu .drg_column").tooltip();

            // if saved content is a grid_editor content, then rebuilt or recover this content
            if($.fn.isGridEditorContent(textarea.val())){
                //editor.find(".panel_grid_body").html($($.fn.skipGridEditorLibraries(textarea.val())).html());
                editor.find(".panel_grid_body").replaceWith($($.fn.skipGridEditorLibraries(textarea.val())));
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
            jQuery('.panel_grid_body ', editor).on("click", '.drg_item .grid_content_remove', function (e) {
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
            jQuery('.panel_grid_body ', editor).on("click", '.grid_col_remove', function (e) {
                if(confirm(I18n("grid_editor.del_block"))){
                    jQuery(this).closest(".drg_column").fadeDestroy();
                    editor.trigger("auto_save");
                }
                e.preventDefault();
            }).on("click", '.grid_col_clone', function (e) {
                var widget = jQuery(this).closest(".drg_column");
                var widget_clone = widget.clone();
                widget.after(widget_clone);
                grid_content_manager(widget_clone.find(".grid_sortable_items"));
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

        do_editor_menus(editor);
        textarea.before(editor);

        // drag columns
        jQuery(".grid_editor_menu .drg_column", editor).draggable({
            connectToSortable: "#"+editor_id+" .panel_grid_body",
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
        jQuery(".panel_grid_body", editor).sortable({
            tolerance: "pointer",
            cursor: "move",
            revert: false,
            delay: 150,
            dropOnEmpty: true,
            items: ".drg_column",
            connectWith: "#"+editor_id+" .panel_grid_body",
            placeholder: "placeholder",
            start: function (e, ui) {
                ui.helper.css({'width': '' , 'height': ''}).addClass('col-md-' + jQuery(ui.helper).attr('data-col'));
                ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).html(ui.helper.html()).fadeTo("fast", 0.4);
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
                    ui.placeholder.attr('class', jQuery(ui.helper).attr("class")).html(ui.helper.html()).fadeTo("fast", 0.4);
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