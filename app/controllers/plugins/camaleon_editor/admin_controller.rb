class Plugins::CamaleonEditor::AdminController < CamaleonCms::Apps::PluginsAdminController
  include Plugins::CamaleonEditor::MainHelper
  def settings
    # actions for admin panel
  end

  # return all grid templates
  def index
    @grid_templates = current_site.grid_templates
    render "index", layout: false
  end

  # return new grid editor template form
  def new
    @grid_template ||= current_site.grid_templates.new
    render "form", layout: false
  end

  # return edit grid editor template form
  def edit
    @grid_template = current_site.grid_templates.find(params[:id])
    new
  end

  # update a grid editor template
  def update
    current_site.grid_templates.find(params[:id]).update(params.require(:grid_template).permit(:name, :description))
    index
  end

  # return grid template value
  def show
    render inline: current_site.grid_templates.find(params[:id]).description
  end

  # destroy a grid editor template
  def destroy
    current_site.grid_templates.find(params[:id]).destroy
    index
  end

  # show style settings for a element
  def style_settings
    render layout: false
  end

  # create a new grid editor template
  def create
    params[:grid_template][:slug] = Time.now.to_i
    if current_site.grid_templates.create(params.require(:grid_template).permit(:name, :slug, :description))
      index
    else
      render inline: "<div class='alert alert-danger'>#{t("admin.message.form_error")}</div>"
    end
  end
end
