
class NewWorker
  include BgWorker::Worker

  bg_options queue: :hello, retry: 2

  def perform(args)
    puts "this is #{self.class.name}"
  end
end