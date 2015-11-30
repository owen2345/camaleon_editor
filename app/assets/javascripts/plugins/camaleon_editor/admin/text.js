// grid content text builder
function grid_text_builder(panel, editor){
    open_modal({title: "Enter Your Text", modal_settings: { keyboard: false, backdrop: "static" }, show_footer: true, content: "<textarea rows='10' class='form-control'></textarea>", callback: function(modal){
        modal.find("textarea").val(panel.html());
    }, on_submit: function(modal){
        panel.html(modal.find("textarea").val());
        modal.modal("hide");
        editor.trigger("auto_save");
    }});
}