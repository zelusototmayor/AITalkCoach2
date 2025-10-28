class AddOnboardingToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :speaking_goal, :string
    add_column :users, :speaking_style, :string
    add_column :users, :age_range, :string
    add_column :users, :profession, :string
    add_column :users, :preferred_pronouns, :string
    add_column :users, :onboarding_completed_at, :datetime
    add_column :users, :onboarding_demo_session_id, :integer
  end
end
