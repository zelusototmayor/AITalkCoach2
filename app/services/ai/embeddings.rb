module Ai
  class Embeddings
    class EmbeddingError < StandardError; end
    class DimensionMismatchError < EmbeddingError; end
    class ModelNotSupportedError < EmbeddingError; end
    
    # Supported embedding models and their dimensions
    SUPPORTED_MODELS = {
      'text-embedding-3-small' => { dimensions: 1536, cost_per_token: 0.00002, max_tokens: 8191 },
      'text-embedding-3-large' => { dimensions: 3072, cost_per_token: 0.00013, max_tokens: 8191 },
      'text-embedding-ada-002' => { dimensions: 1536, cost_per_token: 0.0001, max_tokens: 8191 }
    }.freeze
    
    DEFAULT_MODEL = 'text-embedding-3-small'
    DEFAULT_CACHE_TTL = 7.days
    BATCH_SIZE = 100 # Process embeddings in batches
    
    def initialize(model: DEFAULT_MODEL, options: {})
      @model = model
      @options = options
      @ai_client = Client.new
      @cache_ttl = options[:cache_ttl] || DEFAULT_CACHE_TTL
      
      unless SUPPORTED_MODELS.key?(@model)
        raise ModelNotSupportedError, "Model #{@model} is not supported"
      end
    end
    
    def generate_embedding(text, options = {})
      raise ArgumentError, 'Text cannot be blank' if text.blank?
      
      # Validate text length
      validate_text_length(text)
      
      # Check cache first
      cache_key = Cache.embedding_cache_key(
        Digest::MD5.hexdigest(text.strip.downcase),
        @model
      )
      
      cached_embedding = Cache.get(cache_key, ttl: @cache_ttl)
      return cached_embedding if cached_embedding
      
      begin
        result = @ai_client.create_embedding(text, model: @model)
        embedding_data = {
          vector: result[:embedding],
          model: @model,
          dimensions: SUPPORTED_MODELS[@model][:dimensions],
          text_hash: Digest::MD5.hexdigest(text.strip.downcase),
          created_at: Time.current.iso8601,
          usage: result[:usage]
        }
        
        # Cache the result
        Cache.set(cache_key, embedding_data, ttl: @cache_ttl)
        
        embedding_data
      rescue => e
        Rails.logger.error "Embedding generation failed for model #{@model}: #{e.message}"
        raise EmbeddingError, "Failed to generate embedding: #{e.message}"
      end
    end
    
    def generate_batch_embeddings(texts, options = {})
      raise ArgumentError, 'Texts array cannot be empty' if texts.empty?
      
      results = []
      errors = []
      
      texts.each_slice(BATCH_SIZE) do |batch|
        batch.each_with_index do |text, index|
          begin
            embedding = generate_embedding(text, options)
            results << {
              index: index,
              text: text,
              embedding: embedding,
              success: true
            }
          rescue => e
            Rails.logger.warn "Failed to generate embedding for text at index #{index}: #{e.message}"
            errors << {
              index: index,
              text: text.truncate(100),
              error: e.message,
              success: false
            }
          end
        end
        
        # Add small delay between batches to respect rate limits
        sleep(0.1) if batch.length == BATCH_SIZE
      end
      
      {
        successful_embeddings: results,
        failed_embeddings: errors,
        success_count: results.length,
        error_count: errors.length
      }
    end
    
    def generate_session_embeddings(session)
      embeddings_data = {
        session_id: session.id,
        embeddings: {},
        metadata: {
          model: @model,
          generated_at: Time.current.iso8601,
          total_vectors: 0
        }
      }
      
      begin
        # 1. Generate transcript embedding
        if session.analysis_data['transcript']
          transcript_embedding = generate_transcript_embedding(session.analysis_data['transcript'])
          embeddings_data[:embeddings][:full_transcript] = transcript_embedding
        end
        
        # 2. Generate issue-specific embeddings
        if session.issues.any?
          issue_embeddings = generate_issue_embeddings(session.issues)
          embeddings_data[:embeddings][:issues] = issue_embeddings
        end
        
        # 3. Generate segment embeddings for key segments
        if session.analysis_data['key_segments']
          segment_embeddings = generate_segment_embeddings(session.analysis_data['key_segments'])
          embeddings_data[:embeddings][:segments] = segment_embeddings
        end
        
        # 4. Generate summary embedding
        summary_text = build_session_summary_text(session)
        if summary_text.present?
          summary_embedding = generate_embedding(summary_text)
          embeddings_data[:embeddings][:session_summary] = summary_embedding
        end
        
        # Update metadata
        embeddings_data[:metadata][:total_vectors] = count_total_vectors(embeddings_data[:embeddings])
        
        embeddings_data
      rescue => e
        Rails.logger.error "Failed to generate session embeddings for session #{session.id}: #{e.message}"
        raise EmbeddingError, "Session embedding generation failed: #{e.message}"
      end
    end
    
    def calculate_similarity(embedding1, embedding2)
      validate_embeddings_compatibility(embedding1, embedding2)
      
      vector1 = extract_vector(embedding1)
      vector2 = extract_vector(embedding2)
      
      cosine_similarity(vector1, vector2)
    end
    
    def find_similar_sessions(target_session_id, limit: 10, similarity_threshold: 0.7)
      target_embedding = UserIssueEmbedding.find_by(
        session_id: target_session_id,
        embedding_type: 'session_summary'
      )
      
      return [] unless target_embedding
      
      similar_sessions = []
      
      UserIssueEmbedding.where(embedding_type: 'session_summary')
                       .where.not(session_id: target_session_id)
                       .find_each do |embedding|
        similarity = calculate_similarity(target_embedding.vector_data, embedding.vector_data)
        
        if similarity >= similarity_threshold
          similar_sessions << {
            session_id: embedding.session_id,
            similarity_score: similarity,
            embedding_id: embedding.id
          }
        end
      end
      
      similar_sessions
        .sort_by { |s| -s[:similarity_score] }
        .first(limit)
    end
    
    def find_similar_issues(target_issue_text, user_id: nil, limit: 5, similarity_threshold: 0.8)
      target_embedding = generate_embedding(target_issue_text)
      target_vector = target_embedding[:vector]
      
      similar_issues = []
      
      scope = UserIssueEmbedding.where(embedding_type: 'issue')
      scope = scope.joins(:session).where(sessions: { user_id: user_id }) if user_id
      
      scope.find_each do |embedding|
        similarity = cosine_similarity(target_vector, embedding.vector_data['vector'])
        
        if similarity >= similarity_threshold
          similar_issues << {
            issue_id: embedding.reference_id,
            session_id: embedding.session_id,
            similarity_score: similarity,
            issue_text: embedding.metadata['text']&.truncate(100)
          }
        end
      end
      
      similar_issues
        .sort_by { |i| -i[:similarity_score] }
        .first(limit)
    end
    
    def cluster_user_issues(user_id, min_cluster_size: 3)
      user_issue_embeddings = UserIssueEmbedding
        .joins(:session)
        .where(sessions: { user_id: user_id }, embedding_type: 'issue')
        .includes(:session)
      
      return [] if user_issue_embeddings.count < min_cluster_size
      
      # Simple clustering using similarity threshold
      clusters = []
      processed = Set.new
      
      user_issue_embeddings.each do |embedding|
        next if processed.include?(embedding.id)
        
        cluster = [embedding]
        processed.add(embedding.id)
        
        # Find similar embeddings
        user_issue_embeddings.each do |other_embedding|
          next if processed.include?(other_embedding.id)
          
          similarity = calculate_similarity(
            embedding.vector_data,
            other_embedding.vector_data
          )
          
          if similarity >= 0.75 # High similarity threshold for clustering
            cluster << other_embedding
            processed.add(other_embedding.id)
          end
        end
        
        if cluster.length >= min_cluster_size
          clusters << {
            cluster_id: clusters.length + 1,
            embeddings: cluster,
            size: cluster.length,
            representative_issue: find_cluster_centroid(cluster),
            issue_types: cluster.map { |e| e.metadata['issue_kind'] }.uniq,
            sessions_affected: cluster.map(&:session_id).uniq.length
          }
        end
      end
      
      clusters.sort_by { |c| -c[:size] }
    end
    
    def generate_user_profile_embedding(user)
      profile_components = []
      
      # Collect recent session data
      recent_sessions = user.sessions.where('created_at > ?', 30.days.ago).limit(10)
      
      # Aggregate issue patterns
      issue_summary = recent_sessions
        .joins(:issues)
        .group('issues.kind')
        .count
        .map { |kind, count| "#{count} #{kind} issues" }
        .join(', ')
      
      profile_components << "Recent speech patterns: #{issue_summary}" if issue_summary.present?
      
      # Add speaking metrics summary
      recent_metrics = recent_sessions.map do |session|
        analysis = session.analysis_data
        if analysis['overall_score']
          "Session score: #{analysis['overall_score']}"
        end
      end.compact
      
      profile_components << "Performance trend: #{recent_metrics.join(', ')}" if recent_metrics.any?
      
      # Add speaking goals (if available)
      # This could be extended with user preference data
      profile_components << "Focus areas: clarity, confidence, pace control"
      
      profile_text = profile_components.join('. ')
      
      if profile_text.present?
        generate_embedding(profile_text)
      else
        nil
      end
    end
    
    def store_session_embeddings(session, embeddings_data)
      return unless embeddings_data[:embeddings].any?
      
      embeddings_data[:embeddings].each do |type, embedding_info|
        case type
        when :full_transcript
          store_embedding(session, 'transcript', nil, embedding_info)
        when :session_summary
          store_embedding(session, 'session_summary', nil, embedding_info)
        when :issues
          embedding_info.each do |issue_id, issue_embedding|
            store_embedding(session, 'issue', issue_id, issue_embedding)
          end
        when :segments
          embedding_info.each_with_index do |segment_embedding, index|
            store_embedding(session, 'segment', index, segment_embedding)
          end
        end
      end
    end
    
    private
    
    def validate_text_length(text)
      model_info = SUPPORTED_MODELS[@model]
      # Rough estimation: 4 characters per token
      estimated_tokens = text.length / 4
      
      if estimated_tokens > model_info[:max_tokens]
        raise EmbeddingError, "Text too long for model #{@model}. Estimated #{estimated_tokens} tokens, max #{model_info[:max_tokens]}"
      end
    end
    
    def validate_embeddings_compatibility(embedding1, embedding2)
      dim1 = extract_dimensions(embedding1)
      dim2 = extract_dimensions(embedding2)
      
      unless dim1 == dim2
        raise DimensionMismatchError, "Embedding dimensions don't match: #{dim1} vs #{dim2}"
      end
    end
    
    def extract_vector(embedding)
      case embedding
      when Hash
        embedding[:vector] || embedding['vector']
      when Array
        embedding
      else
        raise EmbeddingError, "Invalid embedding format: #{embedding.class}"
      end
    end
    
    def extract_dimensions(embedding)
      vector = extract_vector(embedding)
      vector.length
    end
    
    def cosine_similarity(vector1, vector2)
      raise ArgumentError, "Vectors must have same length" unless vector1.length == vector2.length
      
      dot_product = vector1.zip(vector2).sum { |a, b| a * b }
      magnitude1 = Math.sqrt(vector1.sum { |x| x * x })
      magnitude2 = Math.sqrt(vector2.sum { |x| x * x })
      
      return 0.0 if magnitude1 == 0 || magnitude2 == 0
      
      dot_product / (magnitude1 * magnitude2)
    end
    
    def generate_transcript_embedding(transcript)
      # Clean and prepare transcript
      cleaned_transcript = clean_transcript_for_embedding(transcript)
      generate_embedding(cleaned_transcript)
    end
    
    def generate_issue_embeddings(issues)
      issue_embeddings = {}
      
      issues.each do |issue|
        issue_text = build_issue_context_text(issue)
        if issue_text.present?
          embedding = generate_embedding(issue_text)
          issue_embeddings[issue.id] = embedding
        end
      end
      
      issue_embeddings
    end
    
    def generate_segment_embeddings(segments)
      segment_embeddings = []
      
      segments.each do |segment|
        if segment['text'].present?
          embedding = generate_embedding(segment['text'])
          segment_embeddings << embedding.merge(segment_info: segment)
        end
      end
      
      segment_embeddings
    end
    
    def build_session_summary_text(session)
      components = []
      
      # Add transcript summary
      transcript = session.analysis_data['transcript']
      if transcript.present?
        # Take first and last parts of transcript for summary
        words = transcript.split
        if words.length > 50
          summary_text = words.first(25).join(' ') + ' ... ' + words.last(25).join(' ')
        else
          summary_text = transcript
        end
        components << "Transcript: #{summary_text}"
      end
      
      # Add key issues
      top_issues = session.issues.order(:start_ms).limit(5)
      if top_issues.any?
        issue_summary = top_issues.map { |i| "#{i.kind}: #{i.text.truncate(50)}" }.join('; ')
        components << "Key issues: #{issue_summary}"
      end
      
      # Add metrics summary
      if session.analysis_data['overall_score']
        components << "Overall score: #{session.analysis_data['overall_score']}"
      end
      
      components.join('. ')
    end
    
    def clean_transcript_for_embedding(transcript)
      # Remove excessive punctuation and normalize
      cleaned = transcript.gsub(/[.]{3,}/, '...')  # Normalize ellipses
      cleaned = cleaned.gsub(/[-]{2,}/, '--')       # Normalize dashes
      cleaned = cleaned.squeeze(' ')                # Remove extra spaces
      cleaned.strip
    end
    
    def build_issue_context_text(issue)
      components = []
      
      components << "Issue type: #{issue.kind}"
      components << "Text: #{issue.text}" if issue.text.present?
      components << "Rationale: #{issue.rationale}" if issue.rationale.present?
      components << "Severity: #{issue.severity}" if issue.severity.present?
      
      components.join('. ')
    end
    
    def count_total_vectors(embeddings_hash)
      count = 0
      
      embeddings_hash.each do |type, data|
        case type
        when :issues
          count += data.keys.length
        when :segments
          count += data.length
        else
          count += 1
        end
      end
      
      count
    end
    
    def find_cluster_centroid(cluster)
      # Find the embedding closest to the average of all embeddings in cluster
      return cluster.first if cluster.length == 1
      
      vectors = cluster.map { |e| e.vector_data['vector'] }
      centroid = calculate_centroid(vectors)
      
      best_match = nil
      best_similarity = -1
      
      cluster.each do |embedding|
        similarity = cosine_similarity(centroid, embedding.vector_data['vector'])
        if similarity > best_similarity
          best_similarity = similarity
          best_match = embedding
        end
      end
      
      best_match
    end
    
    def calculate_centroid(vectors)
      return vectors.first if vectors.length == 1
      
      dimensions = vectors.first.length
      centroid = Array.new(dimensions, 0.0)
      
      vectors.each do |vector|
        vector.each_with_index do |value, index|
          centroid[index] += value
        end
      end
      
      # Average each dimension
      centroid.map { |sum| sum / vectors.length }
    end
    
    def store_embedding(session, embedding_type, reference_id, embedding_data)
      user_embedding = UserIssueEmbedding.find_or_create_by(
        session_id: session.id,
        embedding_type: embedding_type,
        reference_id: reference_id
      )

      metadata_hash = build_embedding_metadata(session, embedding_type, reference_id, embedding_data)
      payload_hash = build_embedding_payload(session, embedding_type, reference_id, embedding_data)

      user_embedding.update!(
        user_id: session.user_id,
        vector_data: embedding_data,
        payload: payload_hash.to_json,
        ai_model_name: @model,
        dimensions: SUPPORTED_MODELS[@model][:dimensions],
        metadata_json: metadata_hash.to_json
      )

      user_embedding
    end
    
    def build_embedding_metadata(session, embedding_type, reference_id, embedding_data)
      metadata = {
        created_at: Time.current.iso8601,
        session_date: session.created_at.iso8601,
        model: @model,
        embedding_type: embedding_type
      }

      case embedding_type
      when 'issue'
        issue = session.issues.find_by(id: reference_id)
        if issue
          metadata.merge!(
            issue_kind: issue.kind,
            text: issue.text,
            severity: issue.severity
          )
        end
      when 'transcript'
        metadata[:transcript_length] = session.analysis_data['transcript']&.length
      when 'session_summary'
        metadata[:overall_score] = session.analysis_data['overall_score']
      end

      metadata
    end

    def build_embedding_payload(session, embedding_type, reference_id, embedding_data)
      payload = {
        session_id: session.id,
        user_id: session.user_id,
        embedding_type: embedding_type
      }

      case embedding_type
      when 'issue'
        issue = session.issues.find_by(id: reference_id)
        if issue
          payload.merge!(
            issue_type: issue.kind,
            description: issue.rationale,
            context: issue.text,
            micro_tip: issue.tip,
            severity: issue.severity,
            category: issue.category,
            start_ms: issue.start_ms,
            end_ms: issue.end_ms
          )
        end
      when 'transcript'
        payload.merge!(
          transcript: session.analysis_data['transcript'],
          word_count: session.analysis_data['transcript']&.split&.length || 0,
          duration_seconds: session.duration_seconds
        )
      when 'session_summary'
        payload.merge!(
          title: session.title,
          overall_score: session.analysis_data['overall_score'],
          grade: session.analysis_data['grade'],
          wpm: session.analysis_data['wpm'],
          filler_rate: session.analysis_data['filler_rate'],
          summary_text: build_session_summary_text(session)
        )
      when 'segment'
        # For segments, reference_id is the segment index
        key_segments = session.analysis_data['key_segments']
        if key_segments && key_segments[reference_id.to_i]
          segment = key_segments[reference_id.to_i]
          payload.merge!(
            segment_index: reference_id,
            text: segment['text'],
            start_ms: segment['start_ms'],
            end_ms: segment['end_ms'],
            segment_type: segment['type']
          )
        end
      end

      payload
    end
    
    # Model information helpers
    
    def self.supported_models
      SUPPORTED_MODELS.keys
    end
    
    def self.model_info(model)
      SUPPORTED_MODELS[model]
    end
    
    def self.default_model
      DEFAULT_MODEL
    end
    
    def self.estimate_cost(text_length, model = DEFAULT_MODEL)
      model_info = SUPPORTED_MODELS[model]
      return 0 unless model_info
      
      estimated_tokens = text_length / 4 # Rough estimation
      estimated_tokens * model_info[:cost_per_token]
    end
  end
end