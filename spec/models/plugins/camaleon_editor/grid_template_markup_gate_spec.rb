# frozen_string_literal: true

# Outside a request there is no signed-in author, so the template markup gate treats the author as
# untrusted. A server-side pipeline that owns its markup (a seed, an import) opts out explicitly.
RSpec.describe Plugins::CamaleonEditor::GridTemplate do
  init_site

  let(:embed) { grid_with_block('<iframe src="https://www.youtube.com/embed/abc"></iframe>') }

  before { CurrentRequest.reset }

  it 'refuses an embed when nobody is signed in' do
    template = @site.grid_templates.new(name: 'Seeded', slug: 'seeded', description: embed)

    expect(template).not_to be_valid
    expect(template.errors[:description]).to be_present
  end

  it 'stores an embed from a pipeline that opted out of the scan' do
    template = @site.grid_templates.new(name: 'Seeded', slug: 'seeded', description: embed)

    expect(template.unfiltered_description!.save).to be(true)
    expect(template.reload.description).to eq(embed)
  end

  it 'keeps the opt-out away from mass assignment' do
    expect { @site.grid_templates.new(unfiltered_description: true) }
      .to raise_error(ActiveModel::UnknownAttributeError)
  end
end
