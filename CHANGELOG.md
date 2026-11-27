# Change Log

## Unreleased

### Fix: an undo keeps the text of a script as it was

An undo while the text editor shows invisible characters no longer puts markup into the text of a script. [#28](https://github.com/owen2345/camaleon_editor/pull/28).

### Fix: the text editors stay safe from jQuery's tinymce()

The block forms no longer install the jQuery plugin of TinyMCE, so the caret of the author stays in place. A grid node with the id of a text editor no longer removes that text editor or writes into it. A column or a block from the palette also goes into a grid node with that id. A save of a block form before its text editor is ready no longer empties the block. A block form no longer shows the markup of the block while its text editor loads. [#27](https://github.com/owen2345/camaleon_editor/pull/27).

### Fix: a grid editor stays after a sort of its custom field group

An author can sort a custom field group that has a grid editor. The grid editor stays, and a later grid change is stored. The grid editor also works with a text editor that a page sets up again for its field. [#26](https://github.com/owen2345/camaleon_editor/pull/26).

### Tooling: the browser specs pass on Chrome 158

Chrome 158 refuses the call that Capybara 3.40.0 sends to clear the cookies after each example. The specs now clear the cookies and the local storage in a different way. Development tooling only. [#25](https://github.com/owen2345/camaleon_editor/pull/25).

### Security: Ruby 3.4.13, Rails 8.1.4.1 and a Rails floor

The gem now declares `rails >= 6.1`, the floor of camaleon_cms. The development Ruby moves to 3.4.13, because Ruby 3.4.12 and earlier has CVE-2026-132825. `Gemfile.lock` moves to Rails 8.1.4.1 and to fixed releases of the other gems with an open advisory. [#24](https://github.com/owen2345/camaleon_editor/pull/24).

### Tooling: CI runs the suite against Camaleon master

An advisory check runs the suite against the `master` branch of camaleon_cms, on each pull request and each push to `master`. The RSpec check of CI shows the camaleon_cms version that it tests. Development tooling only. [#23](https://github.com/owen2345/camaleon_editor/pull/23).

### Tooling: the specs install the plugin one time

The suite installs the plugin on its shared site, so an example does not draw the routes again for its own install. Development tooling only. [#22](https://github.com/owen2345/camaleon_editor/pull/22).

### Fix: a block form leaves a deleted item out of the saved block

A tab, slide or accordion panel deleted just before Save is no longer in the saved block. The Edit link of an item does not send the page to "#" when its form cannot open. [#21](https://github.com/owen2345/camaleon_editor/pull/21).

### Fix: a post keeps its grid and its scripts after a save from either editor

Text editors keep scripts and do not rewrite the grid at a save or a cancelled unload. A grid shown again follows the text editor. A deleted block or column stays deleted. [#20](https://github.com/owen2345/camaleon_editor/pull/20).

**Notes for upgraders**
- Requires tinymce-rails 4.7.4 or later.
- Without unfiltered HTML, core refuses changed content with a script.
- Grid posts keep the export's `<b>` and `rgb()`.

### Tooling: the grid specs read the grid's own export

The feature specs read what the grid exported from a record of their own, not from the post's textarea, which the text editor rewrites in its own serialization when it loses focus: they no longer fail on that timing. Development tooling only. [#18](https://github.com/owen2345/camaleon_editor/pull/18).

### Fix: the grid editor shows its translated labels and prompts

The editor's menu, prompts, tooltips, hints, blocks and style settings panel showed titleized keys or hard-coded English. They now follow the admin language, in English where untranslated, and the templates modals' headings no longer open empty. [#16](https://github.com/owen2345/camaleon_editor/pull/16).

**Notes for upgraders**
- Overrides under `admin.js.grid_editor` move to `camaleon_cms.admin.js.grid_editor`.

### Tooling: the suite can run against an unreleased camaleon_cms

A callable **Core compatibility** workflow runs the suite against a given camaleon_cms commit; core calls it from its own pipeline, so a core change that breaks the plugin shows on the core pull request. Setting `CAMALEON_CMS_PATH` makes the Gemfile source the core from a local checkout; unset, nothing changes. Development tooling only. [#15](https://github.com/owen2345/camaleon_editor/pull/15).

### Security: grid scripts stay inert in the editor, template markup is scanned

Grid scripts no longer run in the admin editor. A template holding scripts, event handlers or embedded objects is refused unless its author is an administrator or a role trusted with unfiltered HTML. [#14](https://github.com/owen2345/camaleon_editor/pull/14).

**Notes for upgraders**
- The gem requires camaleon_cms >= 2.9.3.
- Stored templates are untouched; `rake camaleon_editor:security:scan_templates` lists the ones now refused.
- Seeds and imports opt out with `unfiltered_description!`.

### Fix: applying a grid template can no longer lose the unsaved post

Cancelling, a failed or redirected request and an expired session now leave the post and its grid as they were. The action is a green "Apply template" check that warns the grid is replaced; a template brings its grid-wide style when it has one. Only template managers see Delete, Edit and "Save as template". Unreadable grid content stays in the text editor. [#14](https://github.com/owen2345/camaleon_editor/pull/14).

### Fix: editing a Slider block keeps its captions

Each slide's caption is read from the slide; saving an edited Slider block used to empty them all. [#14](https://github.com/owen2345/camaleon_editor/pull/14).

### Tooling: RuboCop runs with its default formatter in CI

The CI RuboCop step runs without `-f github`, so the job log lists the offenses and the summary. Development tooling only. [#13](https://github.com/owen2345/camaleon_editor/pull/13).

### Fix: plugin config parses under json 3

`config/camaleon_plugin.json` carried a `//` comment, which the json gem no longer accepts by default as of 3.0, so a host app resolving json 3.x raised `JSON::ParserError` at boot. The file is now plain JSON. [#12](https://github.com/owen2345/camaleon_editor/pull/12).

### Fix: plugin stylesheets reach the host's precompile set

The gem's asset manifest linked the raw `.css.scss` sources instead of the compiled stylesheets, so rendering a grid post on the public site (or its draft Preview) raised `AssetNotPrecompiledError` in host apps. The manifest now links every stylesheet by its compiled path. [#11](https://github.com/owen2345/camaleon_editor/pull/11).

### Fix: border color and width no longer share a form field name

The style panel's border Color and Width inputs shared a field name: a saved border kept only the width, and reopening the block's Style Settings crashed before the panel appeared. Each input now has its own name, and legacy blocks heal on reopen (width restored, the stray value cleared on the next save). The panel also survives malformed stored styles, rejects negative widths with an inline error, and no longer forces `background-repeat` on every save. [#10](https://github.com/owen2345/camaleon_editor/pull/10).

### Security: parse saved element styles as JSON, never eval

The grid editor recovered a block's saved style by running `eval()` on its `data-style` attribute, which rides along in a stored grid-template — so a crafted value ran as JavaScript in the editing user's browser. The value is now parsed with `JSON.parse` (it is written with `JSON.stringify`), and malformed input yields an empty style instead of executing. The accordion builder no longer shares that `data-style` name (it stored a plain panel class there): it uses `data-accordion-style`, falling back to the legacy attribute so existing accordions keep their style. [#9](https://github.com/owen2345/camaleon_editor/pull/9).

### Release pipeline

Adds the manually dispatched Release workflow (same pipeline as cama_contact_form and camaleon_cms): it verifies the requested version against `lib/camaleon_editor/version.rb`, RubyGems and existing tags, requires a green CI run for the released commit, builds the gem with `--strict`, audits the packaged files, publishes to RubyGems, then tags and creates the GitHub release with the version's CHANGELOG section as notes. Development tooling only. [#8](https://github.com/owen2345/camaleon_editor/pull/8).

### Security: editor permissions, and no ERB evaluation of templates

Stored grid-template values were ERB-evaluated as server-side code; they now come back verbatim. The editor is gated by two new default-off permissions, **Grid Editor** and **Grid templates**; admins pass. [#7](https://github.com/owen2345/camaleon_editor/pull/7).

**Breaking changes**
- Non-admin roles need the new permissions (Admin > Users > Roles); the plugins permission alone no longer opens it.

### RuboCop and CI

Adds RuboCop (same plugin set as camaleon_cms), lint-cleans the codebase with behavior-preserving fixes, and adds a CI workflow running the RSpec suite and RuboCop on every push and pull request. Also documents the development setup in the README. Development tooling only — the packaged gem's behavior is unchanged. [#6](https://github.com/owen2345/camaleon_editor/pull/6).

### The gem loads standalone; modern tooling and a spec harness

`MainHelper` included a helper constant defined nowhere in the gem, so the published gem raised `NameError` at host-app boot; its methods are now part of the gem. Also modernizes the gemspec and Gemfile (`required_ruby_version >= 3.0`, `camaleon_cms >= 2.9.4`, Ruby 3.4.10 toolchain) and adds a camaleon_cms-backed RSpec suite covering boot, activation, grid-template CRUD, the hooks and the admin editor UI. [#5](https://github.com/owen2345/camaleon_editor/pull/5).
