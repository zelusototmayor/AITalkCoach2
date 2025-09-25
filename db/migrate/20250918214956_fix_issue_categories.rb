class FixIssueCategories < ActiveRecord::Migration[8.0]
  def up
    # Update nil categories based on the kind field or set to 'uncategorized'
    Issue.where(category: nil).find_each do |issue|
      category = case issue.kind
      when /filler/i, /um/i, /uh/i
        'filler_words'
      when /pace/i, /speed/i, /rate/i
        'pace_issues'
      when /pause/i
        'clarity_issues'
      when /volume/i, /quiet/i, /loud/i
        'volume_issues'
      else
        'uncategorized'
      end

      issue.update_column(:category, category)
      Rails.logger.info "Updated issue #{issue.id} category to '#{category}' (was nil)"
    end

    # Add NOT NULL constraint after cleaning up data
    change_column_null :issues, :category, false, 'uncategorized'
  end

  def down
    # Remove the NOT NULL constraint
    change_column_null :issues, :category, true
  end
end
