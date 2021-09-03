module BgWorker
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
