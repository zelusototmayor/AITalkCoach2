class ChangeUserSpeakingGoalToArray < ActiveRecord::Migration[8.0]
  def up
    # Convert existing data to array format
    User.where.not(speaking_goal: nil).find_each do |user|
      user.update_column(:speaking_goal, [user.speaking_goal].to_json)
    end

    # Change column type to text to store JSON array
    change_column :users, :speaking_goal, :text, default: '[]'
  end

  def down
    # Convert back to single value (take first element)
    User.where.not(speaking_goal: nil).find_each do |user|
      goals = JSON.parse(user.speaking_goal) rescue []
      user.update_column(:speaking_goal, goals.first)
    end

    # Change column type back to string
    change_column :users, :speaking_goal, :string
  end
end
