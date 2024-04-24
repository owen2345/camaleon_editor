// grid content tab builder
window.grid_audio_builder = function(panel, editor){
  const form =
      $('<form>'+
        `<div class="form-group"><label class="control-label">Media</label> \
          <div class="group-input-fields-content input-group"> \
            <input type="url" class="form-control url_file" /> \
            <span class="input-group-addon btn_upload"><i class="fa fa-upload"></i> </span> \
          </div> \
        </div>`+
      '</form>');

  form.find(".url_file").val(panel.attr("data-url"));

  const form_callback = () => form.find(".btn_upload").click(function() {
    $.fn.upload_filemanager({
      formats: "audio",
      selected(file) {
        form.find('.url_file').val(file.url);
      }
    });
    return false;
  });

  const submit_form_callback = function(modal) {
    panel.attr("data-url", modal.find(".url_file").val());
    const url = modal.find(".url_file").val();
    let res = '';
    if (url) {
        res = '<audio width="100%" controls src="'+url+'"></audio>';
      }
    panel.html(res);
    modal.modal("hide");
    editor.trigger("auto_save");
  };

  open_modal({
    title: "Audio Form",
    modal_size: "modal-lg",
    modal_settings: { keyboard: false, backdrop: "static" },
    content: form,
    callback: form_callback,
    on_submit: submit_form_callback
  });
};
