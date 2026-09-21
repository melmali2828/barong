# frozen_string_literal: true

require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Barong
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0


    # Configure Sentry as early as possible.
    if ENV["BARONG_SENTRY_DSN_BACKEND"].present?
      require "sentry-raven"
      Raven.configure { |config| config.dsn = ENV["BARONG_SENTRY_DSN_BACKEND"] }
    end

    # Adding Grape API
    # Eager loading all app/ folder

    # Setup the logger
    config.logger = Logger.new(STDOUT)

    # Load lib folder files to be visible in specs
    config.paths.add 'lib', eager_load: false, autoload: true

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
