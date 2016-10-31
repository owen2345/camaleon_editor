# grid content tab builder
window.grid_slider_builder = (panel, editor)->
  id_accor = panel.attr("id") || "slider_" + Math.floor((Math.random() * 100000) + 1)
  panel.attr("id", id_accor)
  tpl = $('<div><table class="table table-hover">' +
      '<thead><th></th><th>Image</th><th></th></thead>' +
      '<tbody></tbody>' +
      '</table>'+
      '<a class="btn btn-default add_item">Add Item <i class="fa fa-plus-circle"></i></a></div>');

  # link buttons
  tpl.find(".add_item").click(->
    show_form(add_item())
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
  add_item = (media, caption)->
    tr = $("<tr><td><i class='fa fa-arrows' style='cursor: move;'></i></td><td class='name'></td><td class='text-right'><textarea class='descr hidden'></textarea> <input class='media hidden' /> <a href='#' class='edit_item' title='Edit'><i class='fa fa-pencil'></i></a> <a href='#' class='del_item' title='Destroy'><i class='fa fa-trash'></i></a></td></tr>")
    tpl.find("tbody").append(tr)
    return update_item(tr, media, caption)

  # update info for a row
  update_item = (tr, media, caption)->
    tr.find("td.name").html(media)
    tr.find(".descr").val(caption)
    return tr

  # recover current items
  panel.find(" > .carousel-inner > .item").each( (index, item)->
    add_item($(this).children("img").attr("src"), panel.find("> .carousel-caption").html())
  )

  # show form for each accordion
  show_form = (tr)->
    form = $('<form>'+
        '<div class="form-group"><label class="control-label">Image</label>
            <div class="group-input-fields-content input-group">
              <input placeholder="Upload your image or paste an URL" type="url" class="form-control url_file" />
              <span class="input-group-addon btn_upload"><i class="fa fa-upload"></i> </span>
            </div>
        </div>'+
        '<div class="form-group"><label class="control-label">Caption</label><textarea class="form-control descr"></textarea></div>'+
        '</form>');
    form.find(".url_file").val(tr.find("td.name").html())
    form.find(".descr").val(tr.find(".descr").val())

    form_callback = (modal)->
      form.find(".btn_upload").click ->
        $.fn.upload_filemanager({
          formats: "image",
          selected: (file) ->
            form.find('.url_file').val(file.url);
        })
        return false
      setTimeout(->
        form.find("textarea").tinymce(cama_get_tinymce_settings({height: '120px'}));
      , 500)

    submit_form_callback = (modal) ->
      update_item(tr, form.find(".url_file").val(), form.find(".descr").val())
      modal.modal("hide")

    open_modal({id: 'cama_editor_modal2', title: "Slide Form", type: "primary", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, content: form, callback: form_callback, on_submit: submit_form_callback })

  # save information in editor
  submit_callback = (modal)->
    res1 = ""
    res2 = ""
    controls = '<a class="left carousel-control" href="#'+id_accor+'" role="button" data-slide="prev">
                  <span class="glyphicon glyphicon-chevron-left" aria-hidden="true"></span>
                  <span class="sr-only">Previous</span>
                </a>
                <a class="right carousel-control" href="#'+id_accor+'" role="button" data-slide="next">
                  <span class="glyphicon glyphicon-chevron-right" aria-hidden="true"></span>
                  <span class="sr-only">Next</span>
                </a>'

    tpl.find("tbody tr").each (index, item)->
      res1 += '<li data-target="#'+id_accor+'" data-slide-to="'+index+'" class="'+(if index == 0 then "active" else "")+'"></li>'
      res2 += '<div class="item '+(if index == 0 then "active" else "")+'"><img src="'+$(this).find("td.name").html()+'" alt=""/> <div class="carousel-caption">'+$(this).find("textarea").val()+'</div></div>'
    res = '<ol class="carousel-indicators">'+res1+'</ol><div class="carousel-inner" role="listbox"> '+res2+' </div>'+controls
    panel.addClass("carousel slide").attr("data-ride", "carousel").html(res)
    modal.modal("hide")
    editor.trigger("auto_save")

  open_modal({title: "Slider Panel", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, content: tpl, on_submit: submit_callback })
