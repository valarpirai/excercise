module BgWorker
  class JobProcessor
    def initialize(config = {})
      @queues = config[:queues]
      @completed = false
    end
    
    def start
      Thread.new do
        run until @completed
      end
    rescue BgWorker::Shutdown
      raise
    end

    def stop
      @completed = true
    end

    alias_method :terminate, :stop

    def run
      job = get_job

      if job
        klass = Object.const_get(job[:klass])
        klass.new.perform(job[:args])
      end
      # If failed, add to retry queue
    end

    def get_job
      BgWorker.redis.with do |conn|
        data = conn.brpop(queue)
        data ? eval(data) : data
      end
    end
  end
end