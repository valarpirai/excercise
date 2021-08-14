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
                BgWorker::Worker.new.perform(data) if data
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
      def enqueue(queue, data = {})
        BgWorker.config.increase_counter
        add_queue(queue)
        BgWorker.config.store.rpush(queue, data)
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

  class Worker
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
