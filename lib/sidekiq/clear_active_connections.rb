# I'm copying this middleware from Sidekiq because author said so
# https://github.com/mperham/sidekiq/issues/3588#issuecomment-326010318

module Sidekiq
  class ClearActiveConnections
    def call(*_args)
      yield
    ensure
      ::ActiveRecord::Base.clear_active_connections!
    end
  end
end
