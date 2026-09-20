# frozen_string_literal: true

# The template scan looks only at a description that changes, so what was stored before it existed
# stays stored. The task is how an operator finds those templates; it must list them and touch nothing.
RSpec.describe 'camaleon_editor:security:scan_templates Rake task', type: :task do
  init_site

  before(:all) { Rails.application.load_tasks } # rubocop:disable RSpec/BeforeAfterAll

  after(:all) { Rake::Task['camaleon_editor:security:scan_templates'].clear } # rubocop:disable RSpec/BeforeAfterAll

  let(:task) { Rake::Task['camaleon_editor:security:scan_templates'] }

  before do
    task.reenable
    allow(Rails.env).to receive(:test?).and_return(false) # TaskReporter is silent under test
  end

  it 'lists a stored template the scan would refuse, and only that one' do
    clean = @site.grid_templates.create!(name: 'Clean', slug: 'clean', description: grid_with_block('<p>fine</p>'))
    stored = @site.grid_templates.create!(name: 'Old', slug: 'old', description: grid_body_markup)
    store_template_markup(stored, grid_with_block('<img src="x" onerror="alert(1)">'))

    listed = satisfy do |output|
      output.match?(/Grid template id=#{stored.id}\b.*would be refused/) && !output.match?(/id=#{clean.id}\b/)
    end
    expect { task.invoke }.to output(listed).to_stdout
    expect(stored.reload.description).to include('onerror')
  end
end
