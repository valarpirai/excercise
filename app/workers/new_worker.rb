
class NewWorker
  include BgWorker::Worker

  bg_options queue: :hello, retry: 2

  def perform(args)
    puts "Thread #{Thread.current.object_id} is #{self.class.name} #{args.inspect}"
    
  end
end