require "test_helper"

module Analysis
  class MicroTipGeneratorTest < ActiveSupport::TestCase
    def setup
      @metrics = {
        clarity_metrics: {
          pause_metrics: {
            pause_quality_score: 45,
            pause_distribution: {
              "optimal" => { percentage: 40 },
              "acceptable" => { percentage: 30 },
              "long" => { percentage: 20 },
              "very_long" => { percentage: 10 }
            },
            long_pause_count: 5
          },
          filler_metrics: {
            total_filler_count: 15,
            filler_rate_percentage: 8.5,
            filler_breakdown: { "um" => 10, "uh" => 5 }
          }
        },
        fluency_metrics: {
          speech_smoothness: 55,
          hesitation_count: 8,
          restart_count: 4
        }
      }

      @coaching_insights = {
        pause_patterns: {
          distribution: { optimal: 40, acceptable: 30, long: 20, very_long: 10 },
          quality_breakdown: "mostly_good_with_awkward_long_pauses",
          specific_issue: "5 pauses over 3 seconds",
          average_pause_ms: 1200,
          longest_pause_ms: 4500
        },
        pace_patterns: {
          trajectory: "starts_slow_rushes_middle_settles",
          consistency: 0.55,
          variation_type: "moderate_variance",
          wpm_range: [ 120, 180 ],
          average_wpm: 150
        },
        energy_patterns: {
          overall_level: 35,
          pattern: "low_energy_throughout",
          engagement_elements: [ "1 exclamations" ],
          needs_boost: true
        },
        smoothness_breakdown: {
          word_flow_score: 52,
          pause_consistency_score: 45,
          primary_issue: "frequent_hesitations",
          hesitation_count: 8,
          restart_count: 4
        },
        hesitation_analysis: {
          total_count: 15,
          rate_percentage: 8.5,
          most_common: "um",
          breakdown: { "um" => 10, "uh" => 5 },
          typical_locations: "mostly_at_sentence_starts",
          density: "high"
        }
      }
    end

    test "generates pause tips when quality is low" do
      generator = MicroTipGenerator.new(@metrics, @coaching_insights)
      tips = generator.generate_tips

      pause_tip = tips.find { |t| t[:category] == "pause_consistency" }
      assert_not_nil pause_tip, "Should generate a pause consistency tip"
      assert_equal "🔄", pause_tip[:icon]
      assert_includes pause_tip[:description], "erratic"
    end

    test "considers generating pace tips when consistency is low" do
      # Remove other high-priority issues to test pace tip generation
      metrics = @metrics.deep_dup
      insights = @coaching_insights.deep_dup
      insights[:energy_patterns][:needs_boost] = false
      insights[:energy_patterns][:overall_level] = 70
      insights[:hesitation_analysis][:rate_percentage] = 2

      generator = MicroTipGenerator.new(metrics, insights)
      tips = generator.generate_tips

      pace_tip = tips.find { |t| t[:category] == "pace_consistency" }
      assert_not_nil pace_tip, "Should generate a pace consistency tip when it's a priority"
      assert_equal "⚡", pace_tip[:icon]
      assert_includes pace_tip[:description].downcase, "slow"
    end

    test "generates energy tips when energy is low" do
      generator = MicroTipGenerator.new(@metrics, @coaching_insights)
      tips = generator.generate_tips

      energy_tip = tips.find { |t| t[:category] == "energy" }
      assert_not_nil energy_tip, "Should generate an energy tip"
      assert_equal "⚡", energy_tip[:icon]
      assert_includes energy_tip[:description].downcase, "energy"
    end

    test "generates filler tips when filler rate is high" do
      generator = MicroTipGenerator.new(@metrics, @coaching_insights)
      tips = generator.generate_tips

      filler_tip = tips.find { |t| t[:category] == "filler_words" }
      assert_not_nil filler_tip, "Should generate a filler words tip"
      assert_equal "🎤", filler_tip[:icon]
      assert_includes filler_tip[:description], "um"
    end

    test "considers generating fluency tips when there's a primary issue" do
      # Remove other higher-priority issues to test fluency tip generation
      metrics = @metrics.deep_dup
      insights = @coaching_insights.deep_dup
      insights[:energy_patterns][:needs_boost] = false
      insights[:energy_patterns][:overall_level] = 70
      insights[:hesitation_analysis][:rate_percentage] = 2
      metrics[:clarity_metrics][:pause_metrics][:pause_quality_score] = 85

      generator = MicroTipGenerator.new(metrics, insights)
      tips = generator.generate_tips

      fluency_tip = tips.find { |t| t[:category] == "fluency" }
      assert_not_nil fluency_tip, "Should generate a fluency tip when it's a priority"
      assert_equal "💬", fluency_tip[:icon]
    end

    test "limits tips to maximum of 3" do
      generator = MicroTipGenerator.new(@metrics, @coaching_insights)
      tips = generator.generate_tips

      assert_operator tips.length, :<=, 3, "Should not generate more than 3 tips"
    end

    test "prioritizes tips by impact/effort ratio" do
      generator = MicroTipGenerator.new(@metrics, @coaching_insights)
      tips = generator.generate_tips

      # Energy tip should be high priority (high impact, low effort)
      energy_tip = tips.find { |t| t[:category] == "energy" }
      if energy_tip
        assert_equal 3.0, energy_tip[:priority_score], "Energy tip should have highest priority score"
      end
    end

    test "does not generate tips for focus areas" do
      focus_areas = [ "Reduce Filler Words" ]
      generator = MicroTipGenerator.new(@metrics, @coaching_insights, focus_areas)
      tips = generator.generate_tips

      filler_tip = tips.find { |t| t[:category] == "filler_words" }
      assert_nil filler_tip, "Should not generate tip that duplicates focus area"
    end

    test "does not generate pause tips when quality is good" do
      good_metrics = @metrics.deep_dup
      good_metrics[:clarity_metrics][:pause_metrics][:pause_quality_score] = 85
      good_insights = @coaching_insights.deep_dup
      good_insights[:pause_patterns][:quality_breakdown] = "mostly_optimal"

      generator = MicroTipGenerator.new(good_metrics, good_insights)
      tips = generator.generate_tips

      pause_tip = tips.find { |t| t[:category] == "pause_consistency" }
      assert_nil pause_tip, "Should not generate pause tip when quality is good"
    end

    test "does not generate energy tips when energy is adequate" do
      adequate_metrics = @metrics.deep_dup
      adequate_insights = @coaching_insights.deep_dup
      adequate_insights[:energy_patterns][:overall_level] = 65
      adequate_insights[:energy_patterns][:needs_boost] = false

      generator = MicroTipGenerator.new(adequate_metrics, adequate_insights)
      tips = generator.generate_tips

      energy_tip = tips.find { |t| t[:category] == "energy" }
      assert_nil energy_tip, "Should not generate energy tip when energy is adequate"
    end

    test "includes actionable advice in tips" do
      generator = MicroTipGenerator.new(@metrics, @coaching_insights)
      tips = generator.generate_tips

      tips.each do |tip|
        assert_not_nil tip[:action], "Each tip should have an action"
        assert_operator tip[:action].length, :>, 10, "Action should be descriptive"
      end
    end

    test "includes relevant data in tips" do
      generator = MicroTipGenerator.new(@metrics, @coaching_insights)
      tips = generator.generate_tips

      tips.each do |tip|
        assert_not_nil tip[:data], "Each tip should include relevant data"
        assert_kind_of Hash, tip[:data], "Data should be a hash"
      end
    end

    test "normalizes focus area names correctly" do
      focus_areas = [ "Reduce Filler Words (Um, Uh)", "Pace & Speed", "Pause Quality" ]
      generator = MicroTipGenerator.new(@metrics, @coaching_insights, focus_areas)
      tips = generator.generate_tips

      # Should not generate tips for any of these categories
      assert_nil tips.find { |t| t[:category] == "filler_words" }
      assert_nil tips.find { |t| t[:category] == "pace_consistency" }
      assert_nil tips.find { |t| t[:category] == "pause_consistency" }
    end
  end
end
