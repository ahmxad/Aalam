require "minitest/mock"

# Rate limits count requests in the Rails cache, and the cache of the test environment is a null store
# that counts nothing, so no limit would ever apply. A test wrapped in with_rate_limits gets a real
# counter, fresh for that test, so the limits behave as they do in production.
module RateLimitHelpers
  def with_rate_limits
    counter = ActiveSupport::Cache::MemoryStore.new
    count = ->(name, amount = 1, **options) { counter.increment(name, amount, **options) }

    ApplicationController.cache_store.stub(:increment, count) do
      yield
    end
  end
end
