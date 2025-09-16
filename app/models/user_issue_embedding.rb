class UserIssueEmbedding < ApplicationRecord
  belongs_to :user
  
  validates :embedding_json, presence: true
  validates :payload, presence: true
  
  # Parse the JSON embedding into an array of floats
  def embedding_vector
    return @embedding_vector if @embedding_vector
    
    @embedding_vector = JSON.parse(embedding_json)
  rescue JSON::ParserError
    []
  end
  
  # Set the embedding from an array of floats
  def embedding_vector=(vector)
    self.embedding_json = vector.to_json
    @embedding_vector = vector
  end
  
  # Parse the JSON payload
  def payload_data
    return @payload_data if @payload_data
    
    @payload_data = JSON.parse(payload)
  rescue JSON::ParserError
    {}
  end
  
  # Set the payload from a hash
  def payload_data=(data)
    self.payload = data.to_json
    @payload_data = data
  end
  
  # Calculate cosine similarity with another embedding
  def cosine_similarity(other_vector)
    return 0.0 if embedding_vector.empty? || other_vector.empty?
    return 0.0 if embedding_vector.length != other_vector.length
    
    dot_product = embedding_vector.zip(other_vector).sum { |a, b| a * b }
    magnitude_a = Math.sqrt(embedding_vector.sum { |a| a * a })
    magnitude_b = Math.sqrt(other_vector.sum { |b| b * b })
    
    return 0.0 if magnitude_a == 0.0 || magnitude_b == 0.0
    
    dot_product / (magnitude_a * magnitude_b)
  end
  
  # Find similar embeddings for a user
  def self.find_similar(user_id, target_vector, limit = 10, threshold = 0.5)
    embeddings = where(user_id: user_id)
    
    similarities = embeddings.map do |embedding|
      similarity = embedding.cosine_similarity(target_vector)
      { embedding: embedding, similarity: similarity }
    end
    
    similarities
      .select { |item| item[:similarity] >= threshold }
      .sort_by { |item| -item[:similarity] }
      .first(limit)
      .map { |item| item[:embedding] }
  end
end