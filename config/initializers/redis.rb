$redis = ConnectionPool::Wrapper.new(size: ENV['REDIS_POOL_SIZE'], timeout: 3) { Redis.connect(url: ENV['REDIS_URL']) }
