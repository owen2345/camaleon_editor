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
    @grid_template = current_site.grid_templates.new(grid_template_params)
    @grid_template.slug = unique_grid_template_slug
    if @grid_template.save
      index
    else
      # Re-render the form, which lists @grid_template.errors via the form_error partial. Relation#create
      # returns the record whether or not it saved, so checking #save is what makes a refused save
      # (blank name, or a description the content-shortcode gate rejects) visible instead of a silent 200.
      render 'form', layout: false
    end
  end

  # update a grid editor template
  def update
    @grid_template = current_site.grid_templates.find(params[:id])
    if @grid_template.update(grid_template_params)
      index
    else
      render 'form', layout: false
    end
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

  private

  def grid_template_params
    params.require(:grid_template).permit(:name, :description)
  end

  # A collision-resistant, server-minted slug. The name alone can repeat, and a plain second-resolution
  # timestamp collides for two saves in the same second (TermTaxonomy's slug uniqueness then refuses
  # the second), so a random suffix is appended.
  def unique_grid_template_slug
    "grid-editor-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
  end

  # The base class gates on :manage, :plugins -- plugin administration. These endpoints are editor
  # usage, so they are gated by the plugin's own default-off permission instead (registered in the
  # roles form via camaleon_editor_available_user_roles_list; admins always pass).
  def authorize_plugin
    authorize! :manage, :camaleon_editor
  end
end
