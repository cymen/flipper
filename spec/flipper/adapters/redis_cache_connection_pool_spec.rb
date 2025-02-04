require 'flipper/adapters/operation_logger'
require 'flipper/adapters/redis_cache_connection_pool'
require 'connection_pool'

RSpec.describe Flipper::Adapters::RedisCacheConnectionPool do
  let(:client) do
    options = {}
    options[:url] = ENV['REDIS_URL'] if ENV['REDIS_URL']
    ConnectionPool.new(size: 1, timeout: 1) { Redis.new(options) }
  end

  let(:memory_adapter) do
    Flipper::Adapters::OperationLogger.new(Flipper::Adapters::Memory.new)
  end
  let(:adapter) { described_class.new(memory_adapter, client) }
  let(:flipper) { Flipper.new(adapter) }

  subject { adapter }

  before do
    skip_on_error(Redis::CannotConnectError, 'Redis not available') do
      client.with { |conn| conn.flushdb }
    end
  end

  it_should_behave_like 'a flipper adapter'

  describe '#remove' do
    it 'expires feature' do
      feature = flipper[:stats]
      adapter.get(feature)
      adapter.remove(feature)
      expect(client.with { |conn| conn.get("flipper/v1/feature/#{feature.key}") }).to be(nil)
    end
  end

  describe '#get' do
    it 'uses correct cache key' do
      stats = flipper[:stats]
      adapter.get(stats)
      expect(client.with { |conn| conn.get("flipper/v1/feature/#{stats.key}") }).not_to be_nil
    end
  end

  describe '#get_multi' do
    it 'warms uncached features' do
      stats = flipper[:stats]
      search = flipper[:search]
      other = flipper[:other]
      stats.enable
      search.enable

      memory_adapter.reset

      adapter.get(stats)
      expect(client.with { |conn| conn.get("flipper/v1/feature/#{search.key}") }).to be(nil)
      expect(client.with { |conn| conn.get("flipper/v1/feature/#{other.key}") }).to be(nil)

      adapter.get_multi([stats, search, other])

      search_cache_value, other_cache_value = [search, other].map do |f|
        Marshal.load(client.with { |conn| conn.get("flipper/v1/feature/#{f.key}") })
      end
      expect(search_cache_value[:boolean]).to eq('true')
      expect(other_cache_value[:boolean]).to be(nil)

      adapter.get_multi([stats, search, other])
      adapter.get_multi([stats, search, other])
      expect(memory_adapter.count(:get_multi)).to eq(1)
    end
  end

  describe '#get_all' do
    let(:stats) { flipper[:stats] }
    let(:search) { flipper[:search] }

    before do
      stats.enable
      search.add
    end

    it 'warms all features' do
      adapter.get_all
      expect(Marshal.load(client.with { |conn| conn.get("flipper/v1/feature/#{stats.key}") })[:boolean]).to eq('true')
      expect(Marshal.load(client.with { |conn| conn.get("flipper/v1/feature/#{search.key}") })[:boolean]).to be(nil)
      expect(client.with { |conn| conn.get("flipper/v1/get_all").to_i }).to be_within(2).of(Time.now.to_i)
    end

    it 'returns same result when already cached' do
      expect(adapter.get_all).to eq(adapter.get_all)
    end

    it 'only invokes one call to wrapped adapter' do
      memory_adapter.reset
      5.times { adapter.get_all }
      expect(memory_adapter.count(:get_all)).to eq(1)
    end
  end

  describe '#name' do
    it 'is redis_cache_connection_pool' do
      expect(subject.name).to be(:redis_cache_connection_pool)
    end
  end
end
