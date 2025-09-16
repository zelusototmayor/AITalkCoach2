require 'rails_helper'

RSpec.describe Ai::Cache do
  let(:test_key) { 'test_cache_key' }
  let(:test_value) { { data: 'test', number: 42 } }
  
  before do
    # Clear any existing cache entries
    AiCache.delete_all
  end
  
  describe '.get' do
    context 'with existing cache entry' do
      before do
        described_class.set(test_key, test_value)
      end
      
      it 'returns the cached value' do
        result = described_class.get(test_key)
        expect(result).to eq(test_value.stringify_keys)
      end
      
      it 'returns nil for non-existent key' do
        result = described_class.get('non_existent_key')
        expect(result).to be_nil
      end
    end
    
    context 'with expired cache entry' do
      before do
        described_class.set(test_key, test_value)
        cache_entry = AiCache.find_by(key: test_key)
        cache_entry.update(created_at: 2.days.ago)
      end
      
      it 'returns nil and deletes expired entry' do
        expect { described_class.get(test_key, ttl: 1.day) }
          .to change(AiCache, :count).by(-1)
        
        result = described_class.get(test_key, ttl: 1.day)
        expect(result).to be_nil
      end
    end
    
    context 'with cache errors' do
      before do
        allow(AiCache).to receive(:find_by).and_raise(StandardError.new('Database error'))
        allow(Rails.logger).to receive(:warn)
      end
      
      it 'logs warning and returns nil on error' do
        result = described_class.get(test_key)
        expect(result).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/AI Cache get error/)
      end
    end
  end
  
  describe '.set' do
    it 'stores value in cache' do
      result = described_class.set(test_key, test_value)
      expect(result).to eq(test_value)
      
      cache_entry = AiCache.find_by(key: test_key)
      expect(cache_entry).to be_present
      expect(cache_entry.value).to be_present
    end
    
    it 'updates existing cache entry' do
      described_class.set(test_key, test_value)
      new_value = { updated: true }
      
      expect { described_class.set(test_key, new_value) }
        .not_to change(AiCache, :count)
      
      result = described_class.get(test_key)
      expect(result).to eq(new_value.stringify_keys)
    end
    
    context 'with cache errors' do
      before do
        allow(AiCache).to receive(:find_or_initialize_by).and_raise(StandardError.new('Database error'))
        allow(Rails.logger).to receive(:error)
      end
      
      it 'logs error and returns original value' do
        result = described_class.set(test_key, test_value)
        expect(result).to eq(test_value)
        expect(Rails.logger).to have_received(:error).with(/AI Cache set error/)
      end
    end
  end
  
  describe '.delete' do
    before do
      described_class.set(test_key, test_value)
    end
    
    it 'removes cache entry' do
      expect { described_class.delete(test_key) }
        .to change(AiCache, :count).by(-1)
      
      result = described_class.get(test_key)
      expect(result).to be_nil
    end
    
    it 'returns true for successful deletion' do
      result = described_class.delete(test_key)
      expect(result).to be true
    end
    
    it 'returns true for non-existent key' do
      result = described_class.delete('non_existent_key')
      expect(result).to be true
    end
  end
  
  describe '.exists?' do
    context 'with existing cache entry' do
      before do
        described_class.set(test_key, test_value)
      end
      
      it 'returns true for existing key' do
        expect(described_class.exists?(test_key)).to be true
      end
      
      it 'returns false for non-existent key' do
        expect(described_class.exists?('non_existent_key')).to be false
      end
    end
    
    context 'with expired cache entry' do
      before do
        described_class.set(test_key, test_value)
        cache_entry = AiCache.find_by(key: test_key)
        cache_entry.update(created_at: 2.days.ago)
      end
      
      it 'returns false for expired entry' do
        result = described_class.exists?(test_key, ttl: 1.day)
        expect(result).to be false
      end
    end
  end
  
  describe '.fetch' do
    context 'with existing cache entry' do
      before do
        described_class.set(test_key, test_value)
      end
      
      it 'returns cached value without calling block' do
        block_called = false
        result = described_class.fetch(test_key) do
          block_called = true
          'fresh_value'
        end
        
        expect(result).to eq(test_value.stringify_keys)
        expect(block_called).to be false
      end
    end
    
    context 'without existing cache entry' do
      it 'calls block and caches result' do
        fresh_value = 'fresh_value'
        result = described_class.fetch(test_key) do
          fresh_value
        end
        
        expect(result).to eq(fresh_value)
        
        cached_result = described_class.get(test_key)
        expect(cached_result).to eq(fresh_value)
      end
      
      it 'returns nil if no block given' do
        result = described_class.fetch(test_key)
        expect(result).to be_nil
      end
    end
  end
  
  describe '.clear_expired' do
    before do
      # Create fresh entries
      described_class.set('key1', 'value1')
      described_class.set('key2', 'value2')
      
      # Make one entry expired
      cache_entry = AiCache.find_by(key: 'key1')
      cache_entry.update(created_at: 2.days.ago)
      
      allow(Rails.logger).to receive(:info)
    end
    
    it 'removes only expired entries' do
      expect { described_class.clear_expired(ttl: 1.day) }
        .to change(AiCache, :count).by(-1)
      
      expect(described_class.exists?('key1')).to be false
      expect(described_class.exists?('key2')).to be true
    end
    
    it 'returns count of cleared entries' do
      result = described_class.clear_expired(ttl: 1.day)
      expect(result).to eq(1)
    end
    
    it 'logs cleanup information' do
      described_class.clear_expired(ttl: 1.day)
      expect(Rails.logger).to have_received(:info).with(/AI Cache: Cleared 1 expired entries/)
    end
  end
  
  describe '.clear_all' do
    before do
      described_class.set('key1', 'value1')
      described_class.set('key2', 'value2')
      allow(Rails.logger).to receive(:info)
    end
    
    it 'removes all cache entries' do
      expect { described_class.clear_all }
        .to change(AiCache, :count).to(0)
    end
    
    it 'returns count of cleared entries' do
      result = described_class.clear_all
      expect(result).to eq(2)
    end
    
    it 'logs clear all information' do
      described_class.clear_all
      expect(Rails.logger).to have_received(:info).with(/AI Cache: Cleared all 2 entries/)
    end
  end
  
  describe '.stats' do
    before do
      described_class.set('key1', 'value1')
      described_class.set('key2', 'longer_value_for_testing')
    end
    
    it 'returns cache statistics' do
      stats = described_class.stats
      
      expect(stats[:total_entries]).to eq(2)
      expect(stats[:oldest_entry]).to be_a(Time)
      expect(stats[:newest_entry]).to be_a(Time)
      expect(stats[:total_size_bytes]).to be > 0
    end
    
    context 'with database error' do
      before do
        allow(AiCache).to receive(:count).and_raise(StandardError.new('Database error'))
        allow(Rails.logger).to receive(:error)
      end
      
      it 'returns error information' do
        stats = described_class.stats
        expect(stats[:error]).to be_present
        expect(Rails.logger).to have_received(:error).with(/AI Cache stats error/)
      end
    end
  end
  
  describe 'cache key generators' do
    describe '.transcription_cache_key' do
      it 'generates consistent keys for same input' do
        key1 = described_class.transcription_cache_key('file_hash', { lang: 'en' })
        key2 = described_class.transcription_cache_key('file_hash', { lang: 'en' })
        expect(key1).to eq(key2)
      end
      
      it 'generates different keys for different input' do
        key1 = described_class.transcription_cache_key('file_hash1', { lang: 'en' })
        key2 = described_class.transcription_cache_key('file_hash2', { lang: 'en' })
        expect(key1).not_to eq(key2)
      end
    end
    
    describe '.analysis_cache_key' do
      it 'includes transcript hash and context' do
        key = described_class.analysis_cache_key('transcript_hash', { model: 'gpt-4' })
        expect(key).to include('analysis:')
        expect(key).to include('transcript_hash')
      end
    end
    
    describe '.embedding_cache_key' do
      it 'includes model name' do
        key = described_class.embedding_cache_key('text_hash', 'text-embedding-3-large')
        expect(key).to include('text-embedding-3-large')
      end
      
      it 'uses default model when not specified' do
        key = described_class.embedding_cache_key('text_hash')
        expect(key).to include('text-embedding-3-small')
      end
    end
  end
  
  describe 'private methods' do
    describe '.generate_cache_key' do
      it 'handles long keys by hashing them' do
        long_key = 'a' * 300
        normalized_key = described_class.send(:generate_cache_key, long_key)
        
        expect(normalized_key.length).to be <= 255
        expect(normalized_key).to include(Digest::MD5.hexdigest(long_key))
      end
      
      it 'returns short keys unchanged' do
        short_key = 'short_key'
        normalized_key = described_class.send(:generate_cache_key, short_key)
        expect(normalized_key).to eq(short_key)
      end
    end
    
    describe '.serialize_value and .parse_cached_value' do
      it 'roundtrips values correctly' do
        original_value = { test: 'data', number: 42, array: [1, 2, 3] }
        serialized = described_class.send(:serialize_value, original_value)
        parsed = described_class.send(:parse_cached_value, serialized)
        
        expect(parsed).to eq(original_value.stringify_keys)
      end
      
      it 'handles legacy plain string values' do
        legacy_value = 'plain_string'
        parsed = described_class.send(:parse_cached_value, legacy_value)
        expect(parsed).to eq(legacy_value)
      end
    end
  end
end