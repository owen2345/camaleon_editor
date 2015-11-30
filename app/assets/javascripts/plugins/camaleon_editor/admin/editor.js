// grid content editor builder
function grid_editor_builder(panel, editor){
    open_modal({title: "Enter Your Content", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
        modal.find("textarea").val(panel.html());
        setTimeout(function(){ modal.find("textarea").tinymce(cama_get_tinymce_settings({height: 120})); }, 500);
    }, on_submit: function(modal){
        var area = modal.find("textarea");
        panel.html(area.tinymce().getContent());
        modal.modal("hide");
        editor.trigger("auto_save");
    }});
}