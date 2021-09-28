require 'concurrent-ruby'
require "connection_pool"
require "redis"

# Reuse code for BgWorker Server and Client
# Read configs from yml file
module BgWorker
  class << self
    def client
      Client
    end

    def config
      Config
    end

    def config=(opts)
      Config.update(opts)
      init
    end

    def init
      @workers.each { |worker| worker.terminate } if @workers

      @workers = []
      config = {

      }
      BgWorker.config.concurrency.times do
        @workers << JobProcessor.new(config)
      end
    end

    def redis_connection_pool(options = {})
      @connection_pool ||= begin
        pool_timeout = options[:timeout] || 10
        size = options[:concurrency].to_i + 5

        ConnectionPool.new(timeout: pool_timeout, size: size) do
          namespace = options[:namespace]
          client = Redis.new(host: options['host'], port: options['port'], db: options['db'])
          if namespace
            begin
              require "redis/namespace"
              Redis::Namespace.new(namespace, redis: client)
            rescue LoadError
              Sidekiq.logger.error("Your Redis configuration uses the namespace '#{namespace}' but the redis-namespace gem is not included in the Gemfile." \
                                  "Add the gem to your Gemfile to continue using a namespace. Otherwise, remove the namespace parameter.")
              exit(-127)
            end
          else
            client
          end
        end
      end
    end

    def redis
      redis_connection_pool(config.redis).with do |conn|
        yield conn block_given?
      end
    end

    def start
      @workers.each { |worker| worker.start }
    end

    def stop
      @workers.each { |worker| worker.stop }
    end
  end

  class Config
    @config = {
      redis: nil,
      concurrency: 5
    }

    @config.each do |key, _value|
      define_singleton_method key do
        @config[key]
      end
    end

    def self.update(opts = {})
      @config = @config.deep_merge(opts)
      @config
    end
  end

  class Client
    QUEUE = 'queues'.freeze
    JOB_COUNT = 'job_count'.freeze
    @queues = []

    class << self
      def enqueue(klass, args = {})
        BgWorker.redis { |conn| conn.incr(JOB_COUNT) }
        add_queue(klass.queue)
        args = { args: args, klass: klass.name }
        BgWorker.redis { |conn| conn.lpush(klass.queue, args) }
      end

      def dequeue(queue)
        return nil if BgWorker.redis { |conn| conn.decr(JOB_COUNT).to_i < 0 }
        # brpop
        data = BgWorker.redis { |conn| conn.brpop(queue) }
        data ? eval(data) : data
      end

      def add_queue(queue_name)
        BgWorker.redis { |conn| conn.sadd(QUEUE, queue_name) }
        @queues << queue_name
      end

      def get_queues
        @queues ||= BgWorker.redis { |conn| conn.smembers(QUEUE) }
      end

      def job_count
        BgWorker.redis { |conn| conn.get(JOB_COUNT) }
      end
    end
  end

  class Shutdown < Interrupt; end
end

# Thread pool
# Stats
# Retry
# Enqueue classes
#

# USAGE:
# BgWorker.client.enqueue(NewWorker, { hello: :world })
# BgWorker.start