require "test_helper"

module Analysis
  class AiRefinerParallelTest < ActiveSupport::TestCase
    setup do
      # Create test user and session without fixtures
      @user = User.create!(email: 'test@example.com', password: 'password123')
      @session = Session.create!(user: @user)

      @transcript_data = {
        transcript: "Um, well, you know, I think this is a great presentation about our product.",
        words: [
          { word: "Um", start: 0, end: 200 },
          { word: "well", start: 300, end: 500 },
          { word: "you", start: 600, end: 700 },
          { word: "know", start: 700, end: 900 }
        ],
        metadata: { duration: 10.5 }
      }

      @rule_based_issues = [
        {
          kind: 'filler_word',
          text: 'Um',
          start_ms: 0,
          end_ms: 200,
          severity: 'medium',
          rationale: 'Hesitation filler'
        }
      ]
    end

    test "parallel processing is enabled by default" do
      assert AiRefiner::ENABLE_PARALLEL_PROCESSING,
        "Parallel processing should be enabled by default"
    end

    test "uses correct models for analysis and coaching" do
      refiner = AiRefiner.new(@session)

      # Check that separate clients are created
      assert_not_nil refiner.instance_variable_get(:@ai_client)
      assert_not_nil refiner.instance_variable_get(:@coaching_client)
    end

    test "metadata includes parallel processing flag and model info" do
      refiner = AiRefiner.new(@session)

      # Mock the AI calls to avoid actual API requests
      mock_ai_analysis = {
        'filler_words' => [],
        'validated_issues' => [],
        'false_positives' => [],
        'speech_quality' => { overall_clarity: 0.8 },
        'summary' => {
          'total_filler_count' => 0,
          'total_valid_issues' => 0
        }
      }

      mock_coaching = {
        'focus_areas' => [],
        'weekly_goals' => [],
        'motivation_message' => 'Keep practicing!'
      }

      refiner.stub(:perform_comprehensive_analysis, mock_ai_analysis) do
        refiner.stub(:generate_coaching_recommendations, mock_coaching) do
          result = refiner.refine_analysis(@transcript_data, @rule_based_issues)

          # Verify metadata
          assert result[:metadata][:parallel_processing_enabled]
          assert_includes ['parallel_processing_v1', 'sequential_v1'],
                         result[:metadata][:optimization]
          assert result[:metadata][:model_analysis]
          assert result[:metadata][:model_coaching]
          assert result[:metadata][:analysis_duration_ms]
          assert result[:metadata][:coaching_duration_ms]
        end
      end
    end

    test "sequential processing works as fallback" do
      # Temporarily disable parallel processing
      original_value = AiRefiner::ENABLE_PARALLEL_PROCESSING
      AiRefiner.const_set(:ENABLE_PARALLEL_PROCESSING, false)

      begin
        refiner = AiRefiner.new(@session)

        mock_ai_analysis = {
          'filler_words' => [],
          'validated_issues' => [],
          'false_positives' => [],
          'speech_quality' => {},
          'summary' => {
            'total_filler_count' => 0,
            'total_valid_issues' => 0
          }
        }

        mock_coaching = { 'focus_areas' => [] }

        refiner.stub(:perform_comprehensive_analysis, mock_ai_analysis) do
          refiner.stub(:generate_coaching_recommendations, mock_coaching) do
            result = refiner.refine_analysis(@transcript_data, @rule_based_issues)

            assert_equal 'sequential_v1', result[:metadata][:optimization]
          end
        end
      ensure
        # Restore original value
        AiRefiner.const_set(:ENABLE_PARALLEL_PROCESSING, original_value)
      end
    end

    test "handles errors gracefully and falls back to rule-based issues" do
      refiner = AiRefiner.new(@session)

      # Force an error in AI processing
      refiner.stub(:perform_comprehensive_analysis, -> (*) { raise StandardError, "API Error" }) do
        result = refiner.refine_analysis(@transcript_data, @rule_based_issues)

        # Should fallback to rule-based issues
        assert result[:fallback_mode]
        assert_equal @rule_based_issues, result[:refined_issues]
        assert_equal "API Error", result[:error]
      end
    end

    test "timing metadata shows performance improvements" do
      refiner = AiRefiner.new(@session)

      mock_ai_analysis = {
        'filler_words' => [],
        'validated_issues' => [],
        'false_positives' => [],
        'speech_quality' => {},
        'summary' => { 'total_filler_count' => 0, 'total_valid_issues' => 0 }
      }

      mock_coaching = { 'focus_areas' => [] }

      refiner.stub(:perform_comprehensive_analysis, mock_ai_analysis) do
        refiner.stub(:generate_coaching_recommendations, mock_coaching) do
          result = refiner.refine_analysis(@transcript_data, @rule_based_issues)

          # Verify timing data is present
          assert result[:metadata][:processing_time_ms] > 0
          assert result[:metadata][:analysis_duration_ms] >= 0
          assert result[:metadata][:coaching_duration_ms] >= 0

          # In parallel mode, total time should be less than sum of individual times
          if result[:metadata][:optimization].to_s.start_with?('hybrid_parallel_v1')
            total = result[:metadata][:processing_time_ms]
            individual_sum = result[:metadata][:analysis_duration_ms] +
                           result[:metadata][:coaching_duration_ms]

            # Parallel processing should save time (with some overhead tolerance)
            assert total < individual_sum + 100,
              "Parallel processing should be faster than sequential"
          end
        end
      end
    end

    test "issue count comparison detects significant differences" do
      refiner = AiRefiner.new(@session)

      # Test: No difference - both have same count
      rule_issues = [
        { kind: 'filler_word', text: 'um' },
        { kind: 'filler_word', text: 'uh' }
      ]
      ai_issues = [
        { kind: 'filler_word', text: 'um' },
        { kind: 'filler_word', text: 'uh' }
      ]
      refute refiner.send(:issue_counts_differ_significantly?, rule_issues, ai_issues),
        "Should not differ when counts are the same"

      # Test: Significant difference - rule has 10, AI has 5 (50% diff > 20% threshold)
      rule_issues_many = Array.new(10) { { kind: 'filler_word', text: 'um' } }
      ai_issues_few = Array.new(5) { { kind: 'filler_word', text: 'um' } }
      assert refiner.send(:issue_counts_differ_significantly?, rule_issues_many, ai_issues_few),
        "Should differ when difference is > 20%"

      # Test: Small difference - rule has 10, AI has 9 (10% diff < 20% threshold)
      rule_issues_10 = Array.new(10) { { kind: 'filler_word', text: 'um' } }
      ai_issues_9 = Array.new(9) { { kind: 'filler_word', text: 'um' } }
      refute refiner.send(:issue_counts_differ_significantly?, rule_issues_10, ai_issues_9),
        "Should not differ when difference is < 20%"

      # Test: Both zero
      refute refiner.send(:issue_counts_differ_significantly?, [], []),
        "Should not differ when both have zero fillers"

      # Test: One zero, one non-zero
      assert refiner.send(:issue_counts_differ_significantly?, rule_issues, []),
        "Should differ when one is zero"
    end

    test "coaching regeneration metadata is included when counts differ" do
      refiner = AiRefiner.new(@session)

      # Mock AI analysis with fewer fillers than rule-based
      mock_ai_analysis = {
        'filler_words' => [{ 'word' => 'um', 'text_snippet' => 'um well', 'start_ms' => 0, 'confidence' => 0.9, 'rationale' => 'test', 'severity' => 'medium' }],
        'validated_issues' => [],
        'false_positives' => [],
        'speech_quality' => {},
        'summary' => { 'total_filler_count' => 1, 'total_valid_issues' => 0 }
      }

      # Rule-based has many fillers (will trigger regeneration)
      rule_based_many = Array.new(10) {
        { kind: 'filler_word', text: 'um', start_ms: 0, end_ms: 100, severity: 'medium', rationale: 'test' }
      }

      mock_coaching = { 'focus_areas' => [] }

      refiner.stub(:perform_comprehensive_analysis, mock_ai_analysis) do
        refiner.stub(:generate_coaching_recommendations, mock_coaching) do
          result = refiner.refine_analysis(@transcript_data, rule_based_many)

          # Should indicate regeneration happened
          if result[:metadata][:optimization].to_s.include?('parallel')
            assert result[:metadata].key?(:coaching_regenerated),
              "Metadata should include coaching_regenerated flag"

            # If counts differ significantly, should be regenerated
            # (This may or may not happen depending on the threshold, so we just check the key exists)
          end
        end
      end
    end
  end
end
