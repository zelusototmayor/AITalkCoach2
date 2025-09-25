class NormalizeMetricsToDecimalFormat < ActiveRecord::Migration[8.0]
  def up
    say "Normalizing metrics to consistent decimal format (0.85 = 85%)"

    # Update sessions with analysis data
    sessions_updated = 0

    Session.where.not(analysis_json: [nil, "", "{}"]).find_each do |session|
      begin
        data = session.analysis_data
        updated = false

        # Convert percentage metrics to decimals (if > 1, divide by 100)
        percentage_metrics = %w[
          clarity_score fluency_score engagement_score pace_consistency
          overall_score pause_quality_score
        ]

        percentage_metrics.each do |metric|
          if data[metric].present? && data[metric].is_a?(Numeric) && data[metric] > 1
            data[metric] = data[metric] / 100.0
            updated = true
          end
        end

        # Convert filler_rate to decimal if it's > 1 (assuming it was stored as percentage)
        if data['filler_rate'].present? && data['filler_rate'].is_a?(Numeric) && data['filler_rate'] > 1
          data['filler_rate'] = data['filler_rate'] / 100.0
          updated = true
        end

        # Also check nested metrics structure for backward compatibility
        if data['metrics'].present?
          metrics = data['metrics']

          # Handle nested structure
          if metrics['clarity_metrics'].present?
            clarity = metrics['clarity_metrics']
            if clarity['clarity_score'].present? && clarity['clarity_score'] > 1
              clarity['clarity_score'] = clarity['clarity_score'] / 100.0
              updated = true
            end
          end

          if metrics['overall_scores'].present?
            overall = metrics['overall_scores']
            if overall['overall_score'].present? && overall['overall_score'] > 1
              overall['overall_score'] = overall['overall_score'] / 100.0
              updated = true
            end

            if overall['component_scores'].present?
              overall['component_scores'].each do |component, score|
                if score.present? && score.is_a?(Numeric) && score > 1
                  overall['component_scores'][component] = score / 100.0
                  updated = true
                end
              end
            end
          end

          if metrics['fluency_metrics'].present?
            fluency = metrics['fluency_metrics']
            if fluency['fluency_score'].present? && fluency['fluency_score'] > 1
              fluency['fluency_score'] = fluency['fluency_score'] / 100.0
              updated = true
            end
          end

          if metrics['engagement_metrics'].present?
            engagement = metrics['engagement_metrics']
            if engagement['engagement_score'].present? && engagement['engagement_score'] > 1
              engagement['engagement_score'] = engagement['engagement_score'] / 100.0
              updated = true
            end
          end
        end

        # Save if we made changes
        if updated
          session.analysis_data = data
          session.save!
          sessions_updated += 1

          if sessions_updated % 10 == 0
            say "Updated #{sessions_updated} sessions..."
          end
        end

      rescue => e
        say "Error updating session #{session.id}: #{e.message}", subitem: true
      end
    end

    say "✓ Normalized metrics for #{sessions_updated} sessions"

    # Add validation constraint to ensure future consistency
    # Note: This is informational - the actual validation will be in the model
    say "Remember to update Analysis::Metrics to store decimals consistently", subitem: true
  end

  def down
    say "Converting metrics back to mixed format (not recommended)"

    sessions_updated = 0

    Session.where.not(analysis_json: [nil, "", "{}"]).find_each do |session|
      begin
        data = session.analysis_data
        updated = false

        # Convert decimal metrics back to percentages
        percentage_metrics = %w[
          clarity_score fluency_score engagement_score pace_consistency
          overall_score pause_quality_score
        ]

        percentage_metrics.each do |metric|
          if data[metric].present? && data[metric].is_a?(Numeric) && data[metric] <= 1
            data[metric] = data[metric] * 100.0
            updated = true
          end
        end

        # Convert filler_rate back to percentage if needed
        if data['filler_rate'].present? && data['filler_rate'].is_a?(Numeric) && data['filler_rate'] <= 1
          data['filler_rate'] = data['filler_rate'] * 100.0
          updated = true
        end

        if updated
          session.analysis_data = data
          session.save!
          sessions_updated += 1
        end

      rescue => e
        say "Error reverting session #{session.id}: #{e.message}", subitem: true
      end
    end

    say "✓ Reverted #{sessions_updated} sessions to mixed format"
  end
end
