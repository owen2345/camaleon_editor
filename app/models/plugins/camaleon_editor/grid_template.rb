# frozen_string_literal: true

# A named, reusable grid-editor layout stored as a term taxonomy of the site: name is the title,
# description holds the grid content, slug is the template key.
class Plugins::CamaleonEditor::GridTemplate < CamaleonCms::TermTaxonomy
  default_scope { where(taxonomy: :grid_template) }

  # What the editor's own Tabs, Accordion, Slider, Video and Audio blocks write beyond core's post
  # content allowlist, none of which runs script: ARIA roles, and media elements whose urls the scan
  # holds to the same schemes as an image's. Without them the scan would refuse the stock blocks of
  # the editor the template was built in. An iframe stays an embed: refused from an untrusted author.
  GRID_EXTRA_TAGS = %w[audio video source].freeze
  GRID_EXTRA_ATTRIBUTES = %w[role controls type].freeze

  validate :reject_untrusted_dangerous_description

  # True when the scan would refuse this markup from an untrusted author. Also what the
  # camaleon_editor:security:scan_templates task lists stored templates by.
  def self.unsafe_description?(markup)
    CamaleonCms::UnsafeMarkup.unsafe_html?(markup,
                                           tags: CamaleonCms::Post::CONTENT_ALLOWED_TAGS + GRID_EXTRA_TAGS,
                                           attributes: CamaleonCms::Post::CONTENT_ALLOWED_ATTRIBUTES +
                                                       GRID_EXTRA_ATTRIBUTES)
  end

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
    return false unless new_record? || description_changed?

    description.present? && !description_author_trusted?
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
