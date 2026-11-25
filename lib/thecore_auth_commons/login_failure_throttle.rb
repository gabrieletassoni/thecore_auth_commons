require "ipaddr"

module ThecoreAuthCommons
  # Per-IP limit on failed logins (host Odoo #6052, R6 of host
  # docs/research/admin-access-strong-security.md; release/3, so backward compatible).
  #
  # Only failures count: users behind one NAT, or an integration that signs in often, never meet
  # the limit with the right password. After THECORE_LOGIN_FAILURES_PER_MINUTE (default 20, 0 turns
  # it off) failed attempts within the current minute from one IP, every login attempt from that IP
  # answers 429 until the minute is over. Nothing else changes: no per-account suspension and no
  # uniform error messages, which are release/4 (host ADR 0040).
  #
  # The IP is the connection's peer, unless that peer is a trusted proxy
  # (config.action_dispatch.trusted_proxies, private networks by default): only then is it
  # ActionDispatch's remote_ip, read from X-Forwarded-For. remote_ip alone would believe an
  # X-Forwarded-For sent straight to Puma by anyone, so each forged address would get its own count. A failure is only known from the
  # response, which is why this is a middleware and not a rack-attack rule.
  #
  # Counters live in a Redis store of their own (THECORE_LOGIN_THROTTLE_REDIS_URL, else REDIS_URL),
  # shared by every process; without Redis, in memory per process; in the test environment nowhere. If Redis is down the limit
  # fails open: logins go on as before.
  class LoginFailureThrottle
    DEFAULT_LIMIT = 20
    PERIOD = 60 # seconds

    # POST /users/sign_in and /api/vN/authenticate, any method on the OAuth callbacks.
    LOGIN_POST_PATH = %r{\A/(users/sign_in|api/v\d+/authenticate)(\.json)?/?\z}
    OAUTH_CALLBACK_PATH = %r{\A/users/auth/[^/]+/callback/?\z}
    SIGN_IN_REDIRECT_PATH = %r{/users/sign_in/?\z}

    class << self
      attr_writer :store

      def store
        @store ||= build_store
      end

      def limit
        value = Integer(ENV.fetch("THECORE_LOGIN_FAILURES_PER_MINUTE", DEFAULT_LIMIT.to_s), exception: false)
        value.nil? || value.negative? ? DEFAULT_LIMIT : value
      end

      private

      def build_store
        # Test suites of host apps and ATOMs sign in and fail many times a minute from 127.0.0.1:
        # there nothing is counted unless a test sets a store (as this gem's own tests do).
        return ActiveSupport::Cache::NullStore.new if Rails.env.test?

        url = ENV["THECORE_LOGIN_THROTTLE_REDIS_URL"].presence || ENV["REDIS_URL"].presence
        return ActiveSupport::Cache::MemoryStore.new if url.nil?

        require "redis"
        ActiveSupport::Cache::RedisCacheStore.new(
          url: url, namespace: "thecore:login_failures",
          connect_timeout: 0.5, read_timeout: 0.5, write_timeout: 0.5, reconnect_attempts: 0,
          error_handler: ->(method:, returning:, exception:) {
            Rails.logger.warn("[LoginFailureThrottle] Redis #{method} failed, not limiting: #{exception.class}: #{exception.message}")
          }
        )
      rescue LoadError
        Rails.logger.warn("[LoginFailureThrottle] the redis gem is missing: counting in memory, per process")
        ActiveSupport::Cache::MemoryStore.new
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      limit = self.class.limit
      return @app.call(env) unless limit.positive? && login_attempt?(env)

      request = ActionDispatch::Request.new(env)
      key = "#{client_ip(request)}:#{Time.now.to_i / PERIOD}"
      return too_many(request) if store.read(key, raw: true).to_i >= limit

      # Read before the call: Warden's failure app rewrites PATH_INFO to /unauthenticated.
      oauth_callback = OAUTH_CALLBACK_PATH.match?(env["PATH_INFO"].to_s)
      status, headers, body = @app.call(env)
      store.increment(key, 1, expires_in: PERIOD * 2) if failed?(env, status, headers, oauth_callback)
      [status, headers, body]
    end

    private

    def store
      self.class.store
    end

    def client_ip(request)
      peer = request.remote_addr.to_s
      trusted_proxy?(peer) ? request.remote_ip : peer
    end

    def trusted_proxy?(address)
      ip = IPAddr.new(address)
      proxies = Rails.application.config.action_dispatch.trusted_proxies || ActionDispatch::RemoteIp::TRUSTED_PROXIES
      Array(proxies).any? { |proxy| proxy.is_a?(IPAddr) ? proxy.include?(ip) : proxy.to_s == address }
    rescue IPAddr::InvalidAddressError
      false
    end

    def login_attempt?(env)
      path = env["PATH_INFO"].to_s
      (env["REQUEST_METHOD"] == "POST" && LOGIN_POST_PATH.match?(path)) || OAUTH_CALLBACK_PATH.match?(path)
    end

    # 401: a wrong password or a refused (locked) user, on the web form and on the API. An OAuth
    # callback fails through OmniAuth (omniauth.error) or by sending the user back to the sign-in form.
    def failed?(env, status, headers, oauth_callback)
      return true if status.to_i == 401
      return false unless oauth_callback

      location = headers["location"] || headers["Location"]
      env["omniauth.error"].present? || env["omniauth.error.type"].present? ||
        (status.to_i.between?(300, 399) && SIGN_IN_REDIRECT_PATH.match?(URI.parse(location.to_s).path.to_s))
    rescue URI::InvalidURIError
      false
    end

    def too_many(request)
      retry_after = (PERIOD - (Time.now.to_i % PERIOD)).to_s
      Rails.logger.warn("[LoginFailureThrottle] #{client_ip(request)} over #{self.class.limit} failed logins a minute: 429 on #{request.path}")
      message = "Too many failed login attempts: retry in #{retry_after} seconds."
      if request.path.start_with?("/api/")
        [429, { "content-type" => "application/json", "retry-after" => retry_after }, [{ error: message }.to_json]]
      else
        [429, { "content-type" => "text/plain; charset=utf-8", "retry-after" => retry_after }, [message]]
      end
    end
  end
end
