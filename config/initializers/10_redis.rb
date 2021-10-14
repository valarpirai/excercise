$redis_conn = Redis.new(host: RedisConfig['host'], port: RedisConfig['port'], db: RedisConfig['db'])

$rate_limitter = Redis::Namespace.new('ratelimit', :redis => $redis_conn, :warning => true)

$redis_bg = Redis::Namespace.new(:bgworker, :redis => $redis_conn, :warning => true)
