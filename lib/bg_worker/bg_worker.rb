require 'concurrent-ruby'

class BgWorker
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
          if BgWorker.config.count > 0
            begin
              BgWorker.client.get_queues.each do |queue_name|
                data = BgWorker.client.dequeue(queue_name)
                if data
                  klass = Object.const_get(data[:klass])
                  klass.new.perform(data[:args])
                end
              end
            rescue => e
              puts "Error occurred-> #{e.message}"
            end
          else
            # puts 'sleeping..'
            sleep 1
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
      store: nil,
      count: 0
    }

    @config.each do |key, _value|
      define_singleton_method key do
        @config[key]
      end
    end

    def self.increase_counter
      @config[:count] += 1
    end

    def self.decrease_counter
      @config[:count] -= 1
    end

    def self.update(opts = {})
      @config = @config.deep_merge(opts)
      @config
    end
  end

  class Client
    QUEUE = 'queues'.freeze
    @queues = []

    class << self
      def enqueue(klass, args = {})
        BgWorker.config.increase_counter
        add_queue(klass.queue)
        args = { args: args, klass: klass.name }
        BgWorker.config.store.rpush(klass.queue, args)
      end

      def dequeue(queue)
        BgWorker.config.decrease_counter
        data = BgWorker.config.store.lpop(queue)
        data ? eval(data) : data
      end

      def add_queue(queue_name)
        BgWorker.config.store.sadd(QUEUE, queue_name)
        @queues << queue_name
      end

      def get_queues
        @queues ||= BgWorker.config.store.smembers(QUEUE)
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

# BgWorker.client.enqueue(NewWorker, { hello: :world })