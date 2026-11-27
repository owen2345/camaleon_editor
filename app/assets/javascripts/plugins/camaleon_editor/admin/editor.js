// grid content editor builder
function grid_editor_builder(panel, editor){
    open_modal({title: I18n("grid_editor.editor_form", "Enter Your Content"), modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
        modal.find("textarea").val(panel.html());
        setTimeout(function(){ modal.find("textarea").gridEditorFormEditor({height: 120}); }, 500);
    }, on_submit: function(modal){
        panel.gridEditorInertHtml(modal.find("textarea").gridEditorFormContent());
        modal.modal("hide");
        editor.trigger("auto_save");
    }});
}