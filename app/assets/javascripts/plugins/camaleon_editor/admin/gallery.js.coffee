# grid content tab builder
window.grid_gallery_builder = (panel, editor)->
  tpl = $('<div><table class="table table-hover">' +
      '<thead><th></th><th>Title</th><th class="hidden"></th></thead>' +
      '<tbody></tbody>' +
      '</table>'+
      '<a class="btn btn-default add_item">Add Item <i class="fa fa-plus-circle"></i></a></div>');



  # link buttons
  tpl.find(".add_item").click(->
    show_form(add_item("Title sample"))
    return false;
  )
  tpl.on("click", "a.edit_item", ->
    show_form($(this).closest("tr"))
    return false
  ).on("click", "a.del_item", ->
    return false if(!confirm(I18n("msg.confirm_del")))
    $(this).closest("tr").fadeDestroy();
    return false
  )

  # sortable
  tpl.find("tbody").sortable({handle: ".fa-arrows"});

  # add a row in the table
  add_item = (title, text)->
    fields = "<input type='hidden' class='url'>"
    tr = $("<tr><td><i class='fa fa-arrows' style='cursor: move;'></i></td><td class='name'></td><td class='text-right'>"+fields+" <a href='#' class='edit_item' title='Edit'><i class='fa fa-pencil'></i></a> <a href='#' class='del_item' title='Destroy'><i class='fa fa-trash'></i></a></td></tr>")
    tpl.find("tbody").append(tr)
    return update_item(tr, title, text)

  # update info for a row
  update_item = (tr, title, text)->
    tr.find("td.name").html(title)
    tr.find(".url").val(text)
    return tr

  # recover current items
  panel.children(".gallery-item").each( ->
    add_item($(this).children(".g-title").text(), $(this).attr("data-url"))
  )

  # show form for each accordion
  show_form = (tr)->
    form = $('<form>'+
            '<div class="form-group"><label class="control-label">Title</label><input class="form-control name"></div>'+
            '<div class="form-group"><label class="control-label">Media</label>
             <div class="group-input-fields-content input-group">
                <input type="url" class="form-control url_file" />
                <span class="input-group-addon btn_upload"><i class="fa fa-upload"></i> </span>
            </div>
            </div>'+
        '</form>');
    form.find(".name").val(tr.find("td.name").html())
    form.find(".url_file").val(tr.find(".url").val())

    form_callback = (modal)->
      form.find(".btn_upload").click ->
        $.fn.upload_filemanager({
          formats: 'image',
          selected: (file) ->
            form.find('.url_file').val(file.url);
        })
        return false

    submit_form_callback = (modal) ->
      update_item(tr, form.find(".name").val(), form.find(".url_file").val())
      modal.modal("hide")

    open_modal({id: 'cama_editor_modal2', title: "Gallery Item Form", type: "primary", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, content: form, callback: form_callback, on_submit: submit_form_callback })

  # save information in editor
  submit_callback = (modal)->
    res = ""
    tpl.find("tbody tr").each ->
      u = $(this).find(".url").val()
      media = ""
      switch $.file_formats[u.split(".").pop().toLowerCase()]
        when "image"
          media = "<img src='"+u+"'>"
        when "audio"
          media = "<audio controls src='"+u+"'>"
        when "video"
          media = '<video width="320" height="240" controls><source src="'+u+'" type="video/mp4"></video>'

      res += '<div class="gallery-item" data-url="'+($(this).find(".url").val())+'">
                  <div class="g-title">
                      '+($(this).find(".name").text())+'
                  </div>
                  <div class="g-content">
                      '+media+'
                  </div>
              </div>';

    panel.html(res)
    modal.modal("hide")
    editor.trigger("auto_save")

  open_modal({title: "Gallery Panel", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, content: tpl, on_submit: submit_callback })
