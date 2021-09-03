require 'concurrent-ruby'

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
        BgWorker.config.store.incr(JOB_COUNT)
        add_queue(klass.queue)
        args = { args: args, klass: klass.name }
        BgWorker.config.store.lpush(klass.queue, args)
      end

      def dequeue(queue)
        return nil if BgWorker.config.store.decr(JOB_COUNT).to_i < 0
        # brpop
        data = BgWorker.config.store.brpop(queue)
        data ? eval(data) : data
      end

      def add_queue(queue_name)
        BgWorker.config.store.sadd(QUEUE, queue_name)
        @queues << queue_name
      end

      def get_queues
        @queues ||= BgWorker.config.store.smembers(QUEUE)
      end

      def job_count
        BgWorker.config.store.get(JOB_COUNT)
      end
    end
  end

  module Worker
    @queue = :default
    @retry = 0

    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def bg_options(args = {})
        @queue ||= args[:queue]
        @retry ||= args[:retry]
      end

      def queue
        @queue
      end

      def retry
        @retry
      end
    end

    def perform(args)
      puts 'Performing..'
      puts args.inspect
      if args[:sleep]
        sleep 5
      end
      puts 'End..'
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