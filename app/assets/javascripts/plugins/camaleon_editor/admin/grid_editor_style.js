// manage style settings for an item
function grid_style_setting(item, editor, parent_item){
    var parent_item = parent_item || (item.closest(".btn"));
    var modal_callback = function(modal){
        var c_style = parent_item.attr("data-style");
        var recover_style = eval("("+(c_style ? c_style : "{}")+")");
        for(var k in recover_style){
            var i = modal.find("[name='"+k+"']").val(recover_style[k]);
            var p = i.parent();
            if(p.hasClass("color") && i.val()) p.attr("data-color", recover_style[k]);
        }
        modal.find(".panel_color").colorpicker();
        modal.find(".file_upload").input_upload_field();
    }

    var submit_callback = function(modal){
        var form = modal.find("form");
        var res = {};
        var img_url = form.find("[name='b-img']").val();
        var b_width = modal.find(".border_width").val() + (modal.find(".border_width").val() ? "px" : "");
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
    open_modal({id: 'cama_editor_modal2', title: "Style Settings", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, mode: "ajax", url: root_url+"admin/plugins/camaleon_editor/style-settings", callback: modal_callback, on_submit: submit_callback })
}