# frozen_string_literal: true

# The languages the plugin's own locale file ships.
SHIPPED_LOCALES = %i[en es it].freeze

# Every key under the scope resolves from the locale file in every shipped language: a missing or
# misnested key surfaces as a translation-missing string rather than being silently absorbed.
def expect_shipped_translations(scope, keys)
  SHIPPED_LOCALES.product(keys).each do |locale, key|
    value = I18n.t("#{scope}.#{key}", locale: locale)
    expect(value).to be_present
    expect(value).not_to match(/translation missing/i)
  end
end
