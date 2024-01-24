// grid content tab builder
window.grid_tab_builder = function(panel, editor){
  const id_accor = panel.attr("id") || ("tab_" + Math.floor((Math.random() * 100000) + 1));
  panel.attr("id", id_accor);
  const tpl = $('<div><table class="table table-hover">' +
      '<thead><th></th><th>Title</th><th class="hidden">Content</th><th></th></thead>' +
      '<tbody></tbody>' +
      '</table>'+
      '<a class="btn btn-default add_item">Add Item <i class="fa fa-plus-circle"></i></a></div>');

  // link buttons
  tpl.find(".add_item").click(function() {
    show_form(add_item("Title sample"));
    return false;
  });
  tpl.on("click", "a.edit_item", function() {
    show_form($(this).closest("tr"));
    return false;
  }).on("click", "a.del_item", function() {
    if(!confirm(I18n("msg.confirm_del")))
      { return false; }
    $(this).closest("tr").fadeDestroy();
    return false;
  });

  // sortable
  tpl.find("tbody").sortable({handle: ".fa-arrows"});

  // add a row in the table
  var add_item = function(title, text){
    const tr = $("<tr>" +
                   "<td><i class='fa fa-arrows' style='cursor: move;'></i></td>" +
                   "<td class='name'></td>" +
                   "<td class='hidden'><textarea class='descr hidden'></textarea></td>" +
                   "<td class='text-right'>" +
                     "<a href='#' class='edit_item' title='Edit'><i class='fa fa-pencil'></i></a> " +
                     "<a href='#' class='del_item' title='Destroy'><i class='fa fa-trash'></i></a>" +
                   "</td>" +
                 "</tr>");
    tpl.find("tbody").append(tr);
    return update_item(tr, title, text);
  };

  // update info for a row
  var update_item = function(tr, title, text){
    tr.find("td.name").html(title);
    tr.find(".descr").val(text);
    return tr;
  };

  // recover current items
  panel.find("> .nav-tabs > li").each( function(index, item){
    add_item($(this).text(), panel.find("> .tab-content > .tab-pane").eq(index).html());
  });

  // show form for each accordion
  var show_form = function(tr){
    const form = $('<form>' +
                   '<div class="form-group">' +
                     '<label class="control-label">Title</label>' +
                     '<input class="form-control name">' +
                   '</div>' +
                   '<div class="form-group">' +
                     '<label class="control-label">Content</label>' +
                     '<textarea class="form-control descr"></textarea>' +
                   '</div>' +
                 '</form>');
    form.find(".name").val(tr.find("td.name").html());
    form.find(".descr").val(tr.find(".descr").val());

    const form_callback = () => setTimeout(
        () => form.find("textarea").tinymce(cama_get_tinymce_settings({height: '120px'})), 500
    );

    const submit_form_callback = function(modal) {
      update_item(tr, form.find(".name").val(), form.find(".descr").val());
      modal.modal("hide");
    };

    open_modal({
      id: 'cama_editor_modal2',
      title: "Tab Form",
      type: "primary",
      modal_size: "modal-lg",
      modal_settings: { keyboard: false, backdrop: "static" },
      content: form,
      callback: form_callback,
      on_submit: submit_form_callback
    });
  };

  // save information in editor
  const submit_callback = function(modal){
    let res1 = "";
    let res2 = "";
    tpl.find("tbody tr").each(function(index, item){
      const _in  = index === 0 ? 'active' : "";
      res1 +=
          '<li role="presentation" class="'+_in+'">' +
            '<a href="#'+id_accor+index+'" ' +
               'aria-controls="home" role="tab" data-toggle="tab">'+($(this).find(".name").text()) +
            '</a>' +
          '</li>';
      res2 += '<div role="tabpanel" class="tab-pane '+_in+'" id="'+id_accor+index+'">'+($(this).find("textarea").val())+
              '</div>';
    });
    const res = '<ul class="nav nav-tabs" role="tablist">'+res1+'</ul><div class="tab-content"> '+res2+' </div>';
    panel.addClass("panel-group").html(res);
    modal.modal("hide");
    editor.trigger("auto_save");
  };

  open_modal({
    title: "Tab Panel",
    modal_size: "modal-lg",
    modal_settings: { keyboard: false, backdrop: "static" },
    content: tpl,
    on_submit: submit_callback
  });
};
