# frozen_string_literal: true

class Postmaster < ApplicationMailer
  layout 'mailer'

  # Template paths in config/mailer.yml are written as full file names with a
  # locale segment, e.g. "email_confirmation.ru.html.erb". Rails 7 expects a
  # bare template name plus a locale, so we split them apart here and let
  # Rails resolve the right file through its own locale lookup.
  TEMPLATE_NAME_PATTERN = /\A(?<name>.+?)(?:\.(?<locale>[a-z]{2}))?(?:\.html\.erb)?\z/.freeze

  def process_payload(params)
    @record  = params[:record]
    @changes = params[:changes]
    @user    = params[:user]
    @logo    = params[:logo]

    sender = "#{Barong::App.config.sender_name} <#{Barong::App.config.sender_email}>"

    match  = TEMPLATE_NAME_PATTERN.match(params[:template_name].to_s)
    name   = match[:name]
    locale = match[:locale] || I18n.default_locale

    email_options = {
      subject: params[:subject],
      template_name: name,
      from: sender,
      to: @user.email
    }

    I18n.with_locale(locale) { mail(email_options) }
  end
end
