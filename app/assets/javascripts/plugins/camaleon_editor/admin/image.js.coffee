# grid content tab builder
window.grid_image_builder = (panel, editor)->
    form = $('<form>'+
        '<div class="form-group"><label class="control-label">Media</label>
         <div class="group-input-fields-content input-group">
            <input type="url" class="form-control url_file" />
            <span class="input-group-addon btn_upload"><i class="fa fa-upload"></i> </span>
        </div>
        </div>'+
        '</form>');
    form.find(".url_file").val(panel.attr("data-url"))

    form_callback = (modal)->
        form.find(".btn_upload").click ->
          $.fn.upload_filemanager({
                formats: "image",
                selected: (file) ->
                    form.find('.url_file').val(file.url);
          })
          return false

    submit_form_callback = (modal) ->
        panel.attr("data-url", modal.find(".url_file").val())
        url = modal.find(".url_file").val()
        res = ''
        if url
            res = '<img src="'+url+'" style="width: 100%;">'
        panel.html(res)
        modal.modal("hide")
        editor.trigger("auto_save")

    open_modal({title: "Image Form", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, content: form, callback: form_callback, on_submit: submit_form_callback })
