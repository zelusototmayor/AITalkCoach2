require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    subject { build(:user) }

    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email) }
  end

  describe 'associations' do
    it { should have_many(:sessions).dependent(:destroy) }
    it { should have_many(:user_issue_embeddings).dependent(:destroy) }
    it { should have_many(:issues).through(:sessions) }
  end

  describe 'factory' do
    it 'creates a valid user' do
      user = create(:user)
      expect(user).to be_valid
      expect(user.email).to be_present
    end

    it 'creates a guest user' do
      guest = create(:user, :guest)
      expect(guest.email).to eq('guest@example.com')
    end

    it 'creates user with sessions' do
      user = create(:user, :with_sessions)
      expect(user.sessions.count).to eq(3)
    end
  end

  describe 'uniqueness' do
    it 'does not allow duplicate emails' do
      create(:user, email: 'test@example.com')
      duplicate_user = build(:user, email: 'test@example.com')

      expect(duplicate_user).not_to be_valid
      expect(duplicate_user.errors[:email]).to include('has already been taken')
    end
  end
end
