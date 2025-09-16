require 'rails_helper'

RSpec.describe UserIssueEmbedding, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:embedding_json) }
    it { should validate_presence_of(:payload) }
  end
  
  describe 'associations' do
    it { should belong_to(:user) }
  end
  
  describe 'factory' do
    it 'creates a valid embedding' do
      embedding = create(:user_issue_embedding)
      expect(embedding).to be_valid
      expect(embedding.user).to be_present
    end
    
    it 'creates embeddings with different similarity levels' do
      high_sim = create(:user_issue_embedding, :high_similarity)
      low_sim = create(:user_issue_embedding, :low_similarity)
      
      expect(high_sim.embedding_vector).not_to eq(low_sim.embedding_vector)
    end
    
    it 'creates embeddings for different issue types' do
      pace_embedding = create(:user_issue_embedding, :pace_issue)
      clarity_embedding = create(:user_issue_embedding, :clarity_issue)
      
      pace_data = pace_embedding.payload_data
      clarity_data = clarity_embedding.payload_data
      
      expect(pace_data['issue_type']).to eq('pace_too_fast')
      expect(clarity_data['issue_type']).to eq('unclear_speech')
    end
  end
  
  describe '#embedding_vector' do
    let(:embedding) { create(:user_issue_embedding) }
    
    it 'returns parsed embedding as array of floats' do
      vector = embedding.embedding_vector
      expect(vector).to be_an(Array)
      expect(vector.first).to be_a(Float)
      expect(vector.length).to eq(10)
    end
    
    it 'caches the parsed vector' do
      vector1 = embedding.embedding_vector
      vector2 = embedding.embedding_vector
      expect(vector1.object_id).to eq(vector2.object_id)
    end
    
    context 'with invalid JSON' do
      let(:embedding) { create(:user_issue_embedding, embedding_json: 'invalid json') }
      
      it 'returns empty array' do
        expect(embedding.embedding_vector).to eq([])
      end
    end
  end
  
  describe '#embedding_vector=' do
    let(:embedding) { build(:user_issue_embedding) }
    let(:vector) { [0.1, 0.2, 0.3, 0.4, 0.5] }
    
    it 'sets embedding_json from array' do
      embedding.embedding_vector = vector
      expect(embedding.embedding_json).to eq(vector.to_json)
      expect(embedding.embedding_vector).to eq(vector)
    end
  end
  
  describe '#payload_data' do
    let(:embedding) { create(:user_issue_embedding) }
    
    it 'returns parsed payload as hash' do
      data = embedding.payload_data
      expect(data).to be_a(Hash)
      expect(data).to have_key('issue_type')
      expect(data).to have_key('context')
    end
    
    it 'caches the parsed payload' do
      data1 = embedding.payload_data
      data2 = embedding.payload_data
      expect(data1.object_id).to eq(data2.object_id)
    end
    
    context 'with invalid JSON' do
      let(:embedding) { create(:user_issue_embedding, payload: 'invalid json') }
      
      it 'returns empty hash' do
        expect(embedding.payload_data).to eq({})
      end
    end
  end
  
  describe '#payload_data=' do
    let(:embedding) { build(:user_issue_embedding) }
    let(:data) { { issue_type: 'test', context: 'test context' } }
    
    it 'sets payload from hash' do
      embedding.payload_data = data
      expect(embedding.payload).to eq(data.to_json)
      expect(embedding.payload_data).to eq(data)
    end
  end
  
  describe '#cosine_similarity' do
    let(:embedding) { create(:user_issue_embedding, embedding_json: '[1.0, 0.0, 0.0]') }
    
    it 'calculates cosine similarity correctly' do
      identical_vector = [1.0, 0.0, 0.0]
      orthogonal_vector = [0.0, 1.0, 0.0]
      opposite_vector = [-1.0, 0.0, 0.0]
      
      expect(embedding.cosine_similarity(identical_vector)).to be_within(0.001).of(1.0)
      expect(embedding.cosine_similarity(orthogonal_vector)).to be_within(0.001).of(0.0)
      expect(embedding.cosine_similarity(opposite_vector)).to be_within(0.001).of(-1.0)
    end
    
    it 'returns 0 for empty vectors' do
      expect(embedding.cosine_similarity([])).to eq(0.0)
      
      empty_embedding = create(:user_issue_embedding, embedding_json: '[]')
      expect(empty_embedding.cosine_similarity([1.0, 2.0])).to eq(0.0)
    end
    
    it 'returns 0 for mismatched vector lengths' do
      short_vector = [1.0, 0.0]
      expect(embedding.cosine_similarity(short_vector)).to eq(0.0)
    end
    
    it 'returns 0 when magnitude is zero' do
      zero_vector = [0.0, 0.0, 0.0]
      expect(embedding.cosine_similarity(zero_vector)).to eq(0.0)
    end
  end
  
  describe '.find_similar' do
    let(:user) { create(:user) }
    let(:target_vector) { [1.0, 0.0, 0.0] }
    
    before do
      create(:user_issue_embedding, user: user, embedding_json: '[1.0, 0.0, 0.0]')    # similarity: 1.0
      create(:user_issue_embedding, user: user, embedding_json: '[0.8, 0.6, 0.0]')    # similarity: 0.8
      create(:user_issue_embedding, user: user, embedding_json: '[0.0, 1.0, 0.0]')    # similarity: 0.0
      create(:user_issue_embedding, user: user, embedding_json: '[0.6, 0.8, 0.0]')    # similarity: 0.6
      
      # Different user's embedding - should not be included
      other_user = create(:user)
      create(:user_issue_embedding, user: other_user, embedding_json: '[1.0, 0.0, 0.0]')
    end
    
    it 'returns similar embeddings above threshold' do
      similar = UserIssueEmbedding.find_similar(user.id, target_vector, 10, 0.7)
      expect(similar.length).to eq(2)
      
      similarities = similar.map { |e| e.cosine_similarity(target_vector) }
      expect(similarities).to all(be >= 0.7)
      expect(similarities).to eq(similarities.sort.reverse)
    end
    
    it 'respects limit parameter' do
      similar = UserIssueEmbedding.find_similar(user.id, target_vector, 1, 0.5)
      expect(similar.length).to eq(1)
    end
    
    it 'respects threshold parameter' do
      similar = UserIssueEmbedding.find_similar(user.id, target_vector, 10, 0.9)
      expect(similar.length).to eq(1)
    end
    
    it 'only returns embeddings for specified user' do
      similar = UserIssueEmbedding.find_similar(user.id, target_vector, 10, 0.0)
      expect(similar.all? { |e| e.user_id == user.id }).to be true
    end
  end
end