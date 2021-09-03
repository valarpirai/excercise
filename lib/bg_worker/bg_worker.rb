require 'concurrent-ruby'
require "connection_pool"
require "redis"

# Reuse code for BgWorker Server and Client
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
      redis_connection_pool.with do |conn|
        yield conn
      end
    end

    def start
      @@thread = Thread.new do
        puts 'started..'
        while true
          # Iterate all the queue
          begin
            data = BgWorker.client.dequeue(*BgWorker.client.get_queues)
            @@pool.post do
              if data
                klass = Object.const_get(data[:klass])
                klass.new.perform(data[:args])
              end
            end
          rescue => e
            puts "Error occurred-> #{e.message}"
          end
        end
      end
    end

    def stop
      @@thread.join
    end
  end

  class Config
    @config = {
      store: nil
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

end

# Thread pool
# Stats
# Retry
# Enqueue classes
#

# USAGE:
# BgWorker.client.enqueue(NewWorker, { hello: :world })
# BgWorker.start