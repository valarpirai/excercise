def config_file(file_name, env = false)
    config = YAML.load_file(File.join(Rails.root, 'config', file_name))
    env ? config[Rails.env] : config
end

redis_config = config_file('redis.yml')
RedisConfig = redis_config['main'][Rails.env]
RateLimitConfig = redis_config['rate_limit'][Rails.env]
