# grid content tab builder
window.grid_accordion_builder = (panel, editor)->
  id_accor = panel.attr("id") || "accordion_" + Math.floor((Math.random() * 100000) + 1)
  settings = '<div class="form-group pull-right" style="width: 150px;">
                  <div class="input-group">
                      <span class="input-group-addon" style="border: 0;">Style: </span>
                      <select class="style-accordion form-control" style="display: inline-block;"><option value="default">Default</option><option value="primary">Blue</option><option value="success">Green</option><option value="warning">Yellow</option><option value="danger">Red</option></select>
                  </div>
              </div>'

  panel.attr("id", id_accor)
  tpl = $('<div><table class="table table-hover">' +
          '<thead><th></th><th>Title</th><th class="hidden">Content</th><th></th></thead>' +
          '<tbody></tbody>' +
      '</table>'+
      '<a class="btn btn-default add_item">Add Item <i class="fa fa-plus-circle"></i></a> '+settings+' </div>');

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
      tr = $("<tr><td><i class='fa fa-arrows' style='cursor: move;'></i></td><td class='name'></td><td class='hidden'><textarea class='descr hidden'></textarea></td><td class='text-right'><a href='#' class='edit_item' title='Edit'><i class='fa fa-pencil'></i></a> <a href='#' class='del_item' title='Destroy'><i class='fa fa-trash'></i></a></td></tr>")
      tpl.find("tbody").append(tr)
      return update_item(tr, title, text)

  # update info for a row
  update_item = (tr, title, text)->
      tr.find("td.name").html(title)
      tr.find(".descr").val(text)
      return tr

  # recover current items
  panel.children(".panel").each( ->
    add_item($(this).children(".panel-heading").text(), $(this).find("> div > .panel-body").html())
  )
  tpl.find(".style-accordion").val(panel.attr("data-style"));

  # show form for each accordion
  show_form = (tr)->
      form = $('<form>'+
                  '<div class="form-group"><label class="control-label">Title</label><input class="form-control name"></div>'+
                  '<div class="form-group"><label class="control-label">Content</label><textarea class="form-control descr"></textarea></div>'+
              '</form>');
      form.find(".name").val(tr.find("td.name").html())
      form.find(".descr").val(tr.find(".descr").val())

      form_callback = (modal)->
          setTimeout(->
            form.find("textarea").tinymce(cama_get_tinymce_settings({height: '120px'}));
          , 500)

      submit_form_callback = (modal) ->
          update_item(tr, form.find(".name").val(), form.find(".descr").val())
          modal.modal("hide")

      open_modal({id: 'cama_editor_modal2', title: "Accordion Form", type: "primary", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, content: form, callback: form_callback, on_submit: submit_form_callback })

  # save information in editor
  submit_callback = (modal)->
      res = ""
      panel.attr("data-style", tpl.find(".style-accordion").val());
      tpl.find("tbody tr").each (index, item)->
        res += '<div class="panel panel-'+tpl.find(".style-accordion").val()+'">
                    <div class="panel-heading" role="tab" id="headingOne">
                      <h4 class="panel-title">
                        <a role="button" data-toggle="collapse" data-parent="#'+id_accor+'" href="#'+id_accor+index+'" aria-expanded="false" aria-controls="collapseOne" class="collapsed">
                          '+($(this).find(".name").text())+'
                          <i class="glyphicon glyphicon-chevron-up pull-right"></i>
                        </a>
                      </h4>
                    </div>
                    <div class="panel-collapse collapse" id="'+id_accor+index+'" role="tabpanel" aria-labelledby="headingOne" aria-expanded="false">
                      <div class="panel-body">
                        '+($(this).find("textarea").val())+'
                      </div>
                    </div>
                </div>'
      panel.addClass("panel-group").html(res)
      modal.modal("hide")
      editor.trigger("auto_save")

  open_modal({title: "Accordion Panel", modal_size: "modal-lg", modal_settings: { keyboard: false, backdrop: "static" }, content: tpl, on_submit: submit_callback })
