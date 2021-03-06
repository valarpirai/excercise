require_relative "boot"

require "rails/all"

require_relative '../lib/middleware/rate_limitter'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Blog
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("lib")
    # config.autoload_paths << Rails.root.join("lib/")
    config.autoload_paths << Rails.root.join("app", "workers")

    config.middleware.use Middleware::RateLimitter

    # Load all modules inside /lib
    Dir["#{Rails.root}/lib/**/*"].each do |file|
      require file if file.end_with?('.rb')
    end
  end
end
