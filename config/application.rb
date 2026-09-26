# frozen_string_literal: true

require_relative 'boot'
require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Defined here, not in an initializer: config/environments/*.rb run
# before config/initializers/*, and production.rb calls ENV.true?.
# --- ENV.true? helper ------------------------------------------------------
# Previously provided by the `env-tweaks` gem, which we dropped because it was
# abandoned (last release 2020) and pinned activesupport to < 7.0.
# Used by config/environments/production.rb and spec/api/v2/cors/cors_spec.rb.
module EnvTrueHelper
  def true?(key)
    %w[true 1 yes on].include?(self[key].to_s.strip.downcase)
  end

  def false?(key)
    !true?(key)
  end
end
ENV.singleton_class.prepend(EnvTrueHelper)

# production.rb uses JSONLogFormatter before autoloading is available,
# so load it explicitly and keep Zeitwerk away from it (see ignore below).
require_relative '../lib/barong/json_log_formatter'

module Barong
  class Application < Rails::Application
    Rails.autoloaders.main.ignore(File.expand_path('../lib/barong/json_log_formatter.rb', __dir__))
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0
    # Deliberate override of the 7.2 default (same as Peatio): YJIT's memory
    # cost is unmeasured; enable later with RUBY_YJIT_ENABLE=1 after measuring.
    config.yjit = false


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
    # load_path: true keeps `require 'barong/...'` working; Rails 7.1 no longer
    # adds autoload paths to $LOAD_PATH (add_autoload_paths_to_load_path = false).
    config.paths.add 'lib', eager_load: false, autoload: true, load_path: true

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.
  end
end
