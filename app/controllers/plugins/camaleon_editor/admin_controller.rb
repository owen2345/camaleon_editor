# frozen_string_literal: true

# Admin endpoints of the plugin: grid-template CRUD and the style-settings panel, all answered as
# AJAX partials for the grid editor UI.
class Plugins::CamaleonEditor::AdminController < CamaleonCms::Apps::PluginsAdminController
  include Plugins::CamaleonEditor::MainHelper

  def settings
    # actions for admin panel
  end

  # return all grid templates
  def index
    @grid_templates = current_site.grid_templates
    render 'index', layout: false
  end

  # return grid template value
  def show
    # html, not inline: the stored description is grid HTML the editor inserts verbatim -- an inline
    # render would evaluate it as an ERB template, i.e. server-side Ruby execution. html_safe keeps
    # the pre-existing trust model (authored markup served unescaped to its authors), minus the
    # code execution.
    render html: current_site.grid_templates.find(params[:id]).description.to_s.html_safe # rubocop:disable Rails/OutputSafety
  end

  # return new grid editor template form
  def new
    @grid_template ||= current_site.grid_templates.new
    render 'form', layout: false
  end

  # return edit grid editor template form
  def edit
    @grid_template = current_site.grid_templates.find(params[:id])
    new
  end

  # create a new grid editor template
  def create
    params[:grid_template][:slug] = Time.now.to_i
    if current_site.grid_templates.create(params.require(:grid_template).permit(:name, :slug, :description))
      index
    else
      render html: "<div class='alert alert-danger'>#{t('admin.message.form_error')}</div>".html_safe
    end
  end

  # update a grid editor template
  def update
    current_site.grid_templates.find(params[:id]).update(params.require(:grid_template).permit(:name, :description))
    index
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
end
