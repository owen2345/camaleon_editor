# frozen_string_literal: true

namespace :camaleon_editor do
  namespace :security do
    # The template scan refuses markup at save and never rewrites what is stored, and it only looks
    # at a description that changed: a template stored before the scan existed, or by an author the
    # scan trusts, stays as it is. This task lists the stored templates the scan would refuse today,
    # so an operator can review them by hand. Read-only: it changes nothing.
    desc 'List stored grid templates whose markup the template scan would refuse'
    task scan_templates: :environment do
      report = CamaleonCms::TaskReporter
      report.call 'Scanning stored grid templates against the template scan (read-only)...'
      flagged = 0

      Plugins::CamaleonEditor::GridTemplate.where.not(description: [nil, '']).find_each do |template|
        next unless Plugins::CamaleonEditor::GridTemplate.unsafe_description?(template.description)

        flagged += 1
        report.call "✗ Grid template id=#{template.id} site=#{template.parent_id} " \
                    "'#{template.name.to_s.truncate(60)}': markup would be refused"
      end

      report.call "Done. #{flagged} stored template(s) would be refused by today's scan."
      report.call 'Nothing was modified; review the listed templates by hand.'
    end
  end
end
