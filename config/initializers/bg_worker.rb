$redis_conn = Redis.new(host: RedisConfig['host'], port: RedisConfig['port'], db: RedisConfig['db'])
$redis_bg = Redis::Namespace.new(:bgworker, :redis => $redis_conn, :warning => true)

BgWorker.config = {
  store: $redis_bg
}


# Worker pool
# Thread safe variables
