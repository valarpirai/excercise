module Middleware
  # Simple Rate limitter
  class RateLimitter
    TIME_PERIOD = 60 # no. of seconds
    LIMIT = 20 # no. of allowed requests per IP for unauthenticated user

    def initialize(app)
      @app = app
    end

    def call(env)
      if allow?(env)
        @app.call(env)
      else
        quota_execeeded
      end
    end

    # block anonymous users
    def allow?(env)
      return true if env['rack.session']['warden.user.user.key'].present?

      key = "IP:#{env['action_dispatch.remote_ip']}"

      $rate_limitter.set(key, 0, nx: true, ex: TIME_PERIOD)
      $rate_limitter.incr(key) > LIMIT ? false : true
    end

    def quota_execeeded
      [ 429, {}, ['Too many requests fired. Request quota exceeded!'] ]
    end
  end
end