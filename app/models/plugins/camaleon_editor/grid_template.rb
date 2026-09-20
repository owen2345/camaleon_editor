# frozen_string_literal: true

# A named, reusable grid-editor layout stored as a term taxonomy of the site: name is the title,
# description holds the grid content, slug is the template key.
class Plugins::CamaleonEditor::GridTemplate < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :grid_template) }

  # What the editor's own Tabs, Accordion, Slider, Video and Audio blocks write beyond core's post
  # content allowlist: ARIA roles, media elements, and the frame a Video block embeds YouTube or Vimeo
  # in. None of it runs script in the page that holds it: the scan holds a frame's or a media
  # element's url to the same schemes as an image's, and srcdoc stays off the list. Whoever may save
  # a template holds the template permission, which is what a frame is allowed on.
  GRID_EXTRA_TAGS = %w[audio video source iframe].freeze
  GRID_EXTRA_ATTRIBUTES = %w[role controls type frameborder allowfullscreen].freeze

  # What the editor's Style Settings panel writes into a style attribute beyond what core's css
  # scrubber keeps: a background image and how it repeats, sizes and scrolls, in the values the panel
  # offers and the form the browser serializes them in. The scrubber drops these declarations, which
  # the scan reads as a removal, so a grid styled with the editor's own panel would be refused.
  PANEL_STYLE_URL = /(?:&quot;|')?((?:[^"'()\\<>\s;&]|&amp;)+)(?:&quot;|')?/
  PANEL_STYLE_DECLARATIONS = [
    /\Abackground-image:\s*url\(#{PANEL_STYLE_URL}\)\z/,
    /\Abackground-repeat:\s*(?:no-repeat|repeat)\z/,
    /\Abackground-size:\s*(?:contain|cover)\z/,
    /\Abackground-attachment:\s*fixed\z/
  ].freeze
  STYLE_ATTRIBUTE = /(\sstyle=")([^"]*)(")/
  # the end of a declaration, not of the character reference a quote or an ampersand is exported as
  DECLARATION_END = /(?<!&quot|&amp|&#39);/

  validate :reject_untrusted_dangerous_description

  # True when the scan would refuse this markup from an untrusted author. Also what the
  # camaleon_editor:security:scan_templates task lists stored templates by.
  def self.unsafe_description?(markup)
    CamaleonCms::UnsafeMarkup.unsafe_html?(without_panel_style(markup),
                                           tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS + GRID_EXTRA_TAGS,
                                           attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES +
                                                       GRID_EXTRA_ATTRIBUTES)
  end

  # The copy of the markup the scan reads: the declarations above taken out of its double-quoted
  # style attributes, the way the editor exports them. Only the scan sees the copy - what is stored is
  # what was written. It fails closed: a declaration that is not one of those to the letter, a url
  # that runs script, a style attribute written any other way, stays in and is refused as before.
  def self.without_panel_style(markup)
    markup.to_s.gsub(STYLE_ATTRIBUTE) do
      opening, style, closing = Regexp.last_match.captures
      kept = style.split(DECLARATION_END).reject { |declaration| panel_style_declaration?(declaration.strip) }
      "#{opening}#{kept.join(';')}#{closing}"
    end
  end

  def self.panel_style_declaration?(declaration)
    match = PANEL_STYLE_DECLARATIONS.lazy.filter_map { |pattern| pattern.match(declaration) }.first
    return false unless match

    match[1].nil? || !CamaleonCms::UnsafeMarkup.dangerous_uri?(CGI.unescapeHTML(match[1]))
  end
  private_class_method :without_panel_style, :panel_style_declaration?

  # Opt-out for trusted server-side pipelines (seeds, imports, a site duplication), which run with
  # no signed-in author and would otherwise be held to the scan. As on core's posts: a reader and a
  # bang enabler, no writer, so mass assignment cannot reach it; sticky for the life of the instance.
  attr_reader :unfiltered_description

  def unfiltered_description!
    @unfiltered_description = true
    self
  end

  private

  # Security (scan-and-reject policy): the description is markup the editor puts into the admin page
  # of whoever applies the template, and into the posts built from it. Administrators can do
  # anything; from any other author the markup core would refuse as post content - scripts, event
  # handlers, embeds - is refused here with the same message, never sanitized or rewritten, so a
  # stored template always equals what its author wrote. Stored templates stay editable: only a
  # changed description is scanned.
  def reject_untrusted_dangerous_description
    return unless scan_description?

    if CamaleonCms::UnsafeMarkup.too_large?(description)
      errors.add(:description, content_rejection_message('content_too_large'))
    elsif self.class.unsafe_description?(description)
      errors.add(:description, content_rejection_message('content_rejected'))
    end
  end

  def scan_description?
    return false unless new_record? || description_markup_changed?

    description.present? && !description_author_trusted?
  end

  # The template form sends the description back on every save, and a textarea round trip turns each
  # line break into CRLF: markup that differs by its line breaks alone was not changed by anyone, and
  # a name-only edit of a template stored with LF (a seed, the console) must not bring on the scan.
  def description_markup_changed?
    return false unless description_changed?

    before, after = description_change.map { |markup| markup.to_s.gsub("\r\n", "\n") }
    before != after
  end

  # The authors core trusts with unfiltered post content: administrators, and a role granted
  # post_content_unfiltered_html. A template belongs to no post type, so holding the grant for any
  # post type of the site counts - that author can already save the same grid as a post. Fails closed:
  # no request context (a job, a rake task, the console) means no trusted author.
  def description_author_trusted?
    return true if unfiltered_description

    user = CurrentRequest.user
    site = CurrentRequest.site
    return false if user.blank? || site.blank?
    return true if user.admin?

    ability = CamaleonCms::Ability.new(user, site)
    site.post_types.any? { |post_type| ability.can?(:post_content_unfiltered_html, post_type) }
  end

  # Core ships these messages in English only, while the locale follows the admin language.
  def content_rejection_message(key)
    full_key = "camaleon_cms.admin.post.message.#{key}"
    I18n.t(full_key, default: I18n.t(full_key, locale: :en))
  end
end
