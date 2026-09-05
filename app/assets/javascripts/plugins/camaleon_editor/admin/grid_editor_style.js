// Recover a saved element's style. data-style is written by the submit handler below via
// JSON.stringify, and rides along in a stored grid-template description -- so parse it as data,
// never eval it (a crafted value would otherwise run as JavaScript in the editor's browser).
// Malformed input yields an empty style rather than throwing, keeping the panel usable.
window.cama_editor_parse_style = function(raw){
    if(!raw) return {};
    try { return JSON.parse(raw); } catch(e){ return {}; }
}

// manage style settings for an item
function grid_style_setting(item, editor, parent_item){
    var parent_item = parent_item || (item.closest(".btn"));
    var modal_callback = function(modal){
        var c_style = parent_item.attr("data-style");
        var recover_style = window.cama_editor_parse_style(c_style);
        // A block saved while colour and width shared name="bo-c" kept only the width, filed
        // under the colour key. Move such a value to its own field so the width is restored and
        // the colour slot is freed; the next save then persists the healed shape.
        if(recover_style["bo-c"] && !recover_style["bo-w"] && /^-?\d+(\.\d+)?$/.test(recover_style["bo-c"])){
            recover_style["bo-w"] = recover_style["bo-c"];
            delete recover_style["bo-c"];
        }
        for(var k in recover_style){
            // Keys are data from a stored template, not selector fragments: a key that isn't
            // shaped like a field name would make the selector below throw or match elsewhere.
            if(!/^[\w-]+$/.test(k)) continue;
            var i = modal.find("[name='"+k+"']").val(recover_style[k]);
            var p = i.parent();
            // Prime jQuery's data cache with the string form as well: the colorpicker reads
            // data('color'), and reading it from the attribute alone coerces numeric-looking
            // values to Numbers, which the widget's colour parser cannot take.
            if(p.hasClass("color") && i.val()) p.attr("data-color", recover_style[k]).data("color", String(recover_style[k]));
        }
        // Init each field independently: this callback runs inside show.bs.modal, so a throw here
        // would abort Bootstrap's show and leave the panel unopened. Degrade the one field and say
        // so instead of failing the whole panel silently.
        modal.find(".panel_color").each(function(){
            try { $(this).colorpicker(); } catch(e){ console.warn("camaleon_editor: colorpicker init failed", e); }
        });
        try { modal.find(".file_upload").input_upload_field(); } catch(e){ console.warn("camaleon_editor: upload field init failed", e); }
    }

    var submit_callback = function(modal){
        var form = modal.find("form");
        var res = {};
        var img_url = form.find("[name='b-img']").val();
        var width_field = modal.find(".border_width");
        // border-width rejects a non-positive length: the declaration is dropped and the computed
        // width falls back to 'medium' (a thicker border), so treat it as no border at all.
        if(!(parseFloat(width_field.val()) > 0)) width_field.val("");
        var b_width = width_field.val() + (width_field.val() ? "px" : "");
        form.find("input, select").each(function(){ if($(this).val()){ res[$(this).attr("name")] = $(this).val(); } });
        parent_item.attr("data-style", JSON.stringify(res));
        parent_item.css({
            "background-color": modal.find(".color_bg").val(),
            "background-position": modal.find(".pos_bg").val(),
            "background-repeat": modal.find(".repeat_bg").val(),
            "background-size": modal.find(".size_bg").val(),
            "background-attachment": modal.find(".attach_bg").val(),
            "background-image": (img_url ? "url("+img_url+")" : ""),
            "color": modal.find(".text_bg").val(),

            "border-style": b_width ? "solid" : "",
            "border-color": modal.find(".color_border").val(),
            "border-width": b_width,

            "margin-left": modal.find("[name='m-l']").val() + (modal.find("[name='m-l']").val() ? "px" : ""),
            "margin-top": modal.find("[name='m-t']").val() + (modal.find("[name='m-t']").val() ? "px" : ""),
            "margin-right": modal.find("[name='m-r']").val() + (modal.find("[name='m-r']").val() ? "px" : ""),
            "margin-bottom": modal.find("[name='m-b']").val() + (modal.find("[name='m-b']").val() ? "px" : ""),

            "padding-left": modal.find("[name='p-l']").val() + (modal.find("[name='p-l']").val() ? "px" : ""),
            "padding-top": modal.find("[name='p-t']").val() + (modal.find("[name='p-t']").val() ? "px" : ""),
            "padding-right": modal.find("[name='p-r']").val() + (modal.find("[name='p-r']").val() ? "px" : ""),
            "padding-bottom": modal.find("[name='p-b']").val() + (modal.find("[name='p-b']").val() ? "px" : ""),
        });
        modal.modal("hide")
        editor.trigger("auto_save");
    }

    //var bg_color = parent_item.css("background-color");
    //var color_border = parent_item.css("border-left-color");
    // The item-form builders (tabs, slider, gallery, accordion) share id cama_editor_modal2; the
    // style panel needs its own, or open_modal's existing-id short-circuit re-shows their modal
    // (with their callbacks) when a style gear is clicked inside a nested grid.
    open_modal({id: 'cama_editor_style_modal', title: "Style Settings", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, mode: "ajax", url: root_url+"admin/plugins/camaleon_editor/style-settings", callback: modal_callback, on_submit: submit_callback })
}