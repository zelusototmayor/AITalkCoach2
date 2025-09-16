require 'rails_helper'

RSpec.describe AiCache, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:key) }
    it { should validate_presence_of(:value) }
    
    it 'validates uniqueness of key' do
      create(:ai_cache, key: 'test_key')
      duplicate = build(:ai_cache, key: 'test_key')
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:key]).to include('has already been taken')
    end
  end
  
  describe 'factory' do
    it 'creates a valid cache entry' do
      cache = create(:ai_cache)
      expect(cache).to be_valid
      expect(cache.key).to be_present
      expect(cache.value).to be_present
    end
    
    it 'creates an expired cache entry' do
      cache = create(:ai_cache, :expired)
      expect(cache.created_at).to be < 1.day.ago
    end
    
    it 'creates a JSON response cache' do
      cache = create(:ai_cache, :json_response)
      expect(JSON.parse(cache.value)).to be_a(Hash)
    end
  end
  
  describe '.get' do
    let!(:cache) { create(:ai_cache, key: 'test_key', value: 'test_value') }
    
    it 'returns value for existing key' do
      expect(AiCache.get('test_key')).to eq('test_value')
    end
    
    it 'returns nil for non-existent key' do
      expect(AiCache.get('non_existent')).to be_nil
    end
  end
  
  describe '.set' do
    it 'creates new cache entry' do
      result = AiCache.set('new_key', 'new_value')
      expect(result).to be_persisted
      expect(result.key).to eq('new_key')
      expect(result.value).to eq('new_value')
    end
    
    it 'updates existing cache entry' do
      create(:ai_cache, key: 'existing_key', value: 'old_value')
      result = AiCache.set('existing_key', 'updated_value')
      
      expect(result.value).to eq('updated_value')
      expect(AiCache.count).to eq(1)
    end
  end
  
  describe '.delete' do
    let!(:cache) { create(:ai_cache, key: 'delete_me') }
    
    it 'deletes existing cache entry' do
      expect { AiCache.delete('delete_me') }.to change(AiCache, :count).by(-1)
    end
    
    it 'does nothing for non-existent key' do
      expect { AiCache.delete('non_existent') }.not_to change(AiCache, :count)
    end
  end
  
  describe '#expired?' do
    let(:fresh_cache) { create(:ai_cache) }
    let(:old_cache) { create(:ai_cache, :expired) }
    
    it 'returns false for fresh cache' do
      expect(fresh_cache.expired?).to be false
    end
    
    it 'returns true for expired cache' do
      expect(old_cache.expired?).to be true
    end
    
    it 'respects custom TTL' do
      recent_cache = create(:ai_cache, created_at: 1.hour.ago)
      expect(recent_cache.expired?(30.minutes)).to be true
      expect(recent_cache.expired?(2.hours)).to be false
    end
    
    it 'returns false when ttl_seconds is nil' do
      expect(old_cache.expired?(nil)).to be false
    end
  end
end