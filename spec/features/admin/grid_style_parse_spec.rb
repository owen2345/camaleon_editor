# frozen_string_literal: true

# Security: the grid editor recovers a saved element's style from a `data-style` attribute that
# rides along in a stored grid-template `description`. It must be parsed as data, never executed:
# the pre-fix code ran `eval("(" + data-style + ")")`, so a crafted value was arbitrary JavaScript
# in the editing admin's browser. The producer (grid_editor_style.js submit) is `JSON.stringify`,
# so valid values are always JSON.
RSpec.describe 'the grid editor style recovery', :js do
  init_site

  # Reuse the post editor: it loads editor-manifest.js, which includes grid_editor_style.js and so
  # defines the global parser under test.
  before do
    store_current_site(@site)
    plugin_install('camaleon_editor')
    admin_sign_in
    post_type = CamaleonCms::Site.first.post_types.first
    visit "#{cama_root_relative_path}/admin/post_type/#{post_type.id}/posts/new"
  end

  it 'parses a JSON style blob into an object' do
    result = page.evaluate_script('JSON.stringify(cama_editor_parse_style(\'{"color":"red","m-l":"5"}\'))')

    expect(JSON.parse(result)).to eq('color' => 'red', 'm-l' => '5')
  end

  it 'returns an empty object for a blank or missing value' do
    expect(page.evaluate_script('JSON.stringify(cama_editor_parse_style(""))')).to eq('{}')
    expect(page.evaluate_script('JSON.stringify(cama_editor_parse_style(null))')).to eq('{}')
  end

  it 'does not execute a crafted data-style payload' do
    # Under the old eval("(" + value + ")") this assignment ran and set the global; JSON.parse
    # rejects it as malformed and returns {}, so the flag stays undefined.
    page.execute_script('window.__cama_editor_pwned = false')
    result = page.evaluate_script(
      'JSON.stringify(cama_editor_parse_style("window.__cama_editor_pwned = true"))'
    )

    expect(result).to eq('{}')
    expect(page.evaluate_script('window.__cama_editor_pwned')).to be(false)
  end

  # Pin the call site, not just the helper: drive grid_style_setting on an element whose data-style
  # is a code payload and prove the recovery path parses it instead of eval-ing it. open_modal is
  # stubbed to run its callback synchronously so the recover step executes without the ajax modal.
  # If the recovery ever reverts to eval (even with the safe helper still defined), this goes red.
  it 'recovers a grid block style through the safe parser, never eval' do
    pwned = page.evaluate_script(<<~JS)
      (function(){
        window.__cama_editor_call_site_pwned = false;
        var saved = window.open_modal;
        window.open_modal = function(opts){ try { if(opts.callback) opts.callback($('<div></div>')); } catch(e){} };
        try {
          var el = $('<div class="btn" data-style="window.__cama_editor_call_site_pwned = true"></div>');
          grid_style_setting(el, $('<div></div>'), el);
        } catch(e){}
        window.open_modal = saved;
        return window.__cama_editor_call_site_pwned;
      })()
    JS

    expect(pwned).to be(false)
  end
end
