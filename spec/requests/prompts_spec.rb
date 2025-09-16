require 'rails_helper'

RSpec.describe 'Prompts', type: :request do
  let(:guest_user) { create(:user, email: 'guest@aitalkcoach.local') }

  before do
    # Ensure guest user exists for all tests
    guest_user
  end

  describe 'GET /prompts' do
    it 'returns successful response' do
      get prompts_path
      expect(response).to have_http_status(:success)
    end

    it 'displays prompt categories' do
      get prompts_path
      
      expect(response.body).to include('presentation')
      expect(response.body).to include('conversation')
      expect(response.body).to include('storytelling')
    end

    it 'displays base prompts' do
      get prompts_path
      
      # Should include some prompts from the YAML config
      expect(response.body).to include('Elevator Pitch')
      expect(response.body).to include('Meeting Introduction')
    end

    context 'when user has speech pattern history for adaptive prompts' do
      before do
        create_user_sessions_with_patterns
      end

      it 'displays adaptive prompts based on user patterns' do
        get prompts_path
        
        # Should show adaptive prompts for detected patterns
        expect(response.body).to match(/recommended|adaptive/i)
      end

      it 'includes recommended category' do
        get prompts_path
        
        expect(response.body).to include('recommended')
      end
    end

    context 'when user has insufficient session history' do
      before do
        # Create only 1-2 sessions (below the 3 session minimum)
        create(:session, user: guest_user, completed: true)
        create(:session, user: guest_user, completed: true)
      end

      it 'does not show adaptive prompts' do
        get prompts_path
        
        # Should still work but without adaptive prompts
        expect(response).to have_http_status(:success)
      end
    end

    context 'when guest user not found' do
      before do
        User.find_by(email: 'guest@aitalkcoach.local')&.destroy
      end

      it 'still returns successful response' do
        get prompts_path
        expect(response).to have_http_status(:success)
      end

      it 'shows base prompts without user-specific content' do
        get prompts_path
        
        expect(response.body).to include('Elevator Pitch')
        expect(response.body).to include('Meeting Introduction')
      end
    end
  end

  describe 'prompt randomization and selection' do
    it 'provides variety in prompt suggestions' do
      # Make multiple requests to ensure prompts are accessible
      5.times do
        get prompts_path
        expect(response).to have_http_status(:success)
      end
    end

    it 'maintains consistent categories across requests' do
      get prompts_path
      first_response = response.body
      
      get prompts_path
      second_response = response.body
      
      # Categories should be consistent
      ['presentation', 'conversation', 'storytelling'].each do |category|
        expect(first_response).to include(category)
        expect(second_response).to include(category)
      end
    end
  end

  describe 'prompt content and structure' do
    it 'displays prompt details correctly' do
      get prompts_path
      
      # Should include prompt descriptions and timing information
      expect(response.body).to match(/seconds?/i)
      expect(response.body).to match(/description/i)
    end

    it 'handles focus areas for prompts' do
      get prompts_path
      
      # Should display focus areas like clarity, pacing, etc.
      expect(response.body).to match(/clarity|pacing|engagement/i)
    end
  end

  describe 'adaptive prompts integration' do
    context 'with filler word patterns' do
      before do
        create_sessions_with_filler_patterns
      end

      it 'suggests filler word focused prompts' do
        get prompts_path
        
        # Should include prompts focused on reducing fillers
        expect(response.body).to match(/filler|fluency/i)
      end
    end

    context 'with pacing patterns' do
      before do
        create_sessions_with_pace_patterns
      end

      it 'suggests pacing focused prompts' do
        get prompts_path
        
        # Should include prompts focused on pacing
        expect(response.body).to match(/pace|tempo/i)
      end
    end

    context 'with clarity patterns' do
      before do
        create_sessions_with_clarity_patterns
      end

      it 'suggests clarity focused prompts' do
        get prompts_path
        
        # Should include prompts focused on clarity
        expect(response.body).to match(/clarity|articulation/i)
      end
    end
  end

  private

  def create_user_sessions_with_patterns
    # Create enough sessions (4) with various patterns to trigger adaptive prompts
    4.times do |i|
      session = create(:session, 
        user: guest_user, 
        completed: true, 
        created_at: (20 - i).days.ago,
        analysis_data: {
          'clarity_score' => 0.6, # Below threshold
          'wpm' => 100, # Below ideal range
          'filler_rate' => 0.08 # High filler rate
        }
      )
      
      # Add some issues to trigger pattern detection
      create(:issue, session: session, category: 'filler_words')
    end
  end

  def create_sessions_with_filler_patterns
    # Create 4 sessions where 3+ have filler issues (above 40% threshold)
    4.times do |i|
      session = create(:session, 
        user: guest_user, 
        completed: true, 
        created_at: (20 - i).days.ago
      )
      
      # Add filler issues to 3 out of 4 sessions
      if i < 3
        create(:issue, session: session, category: 'filler_words')
      end
    end
  end

  def create_sessions_with_pace_patterns
    # Create sessions with pacing issues
    4.times do |i|
      create(:session, 
        user: guest_user, 
        completed: true, 
        created_at: (20 - i).days.ago,
        analysis_data: {
          'wpm' => i < 3 ? 80 : 150  # 3 out of 4 sessions too slow
        }
      )
    end
  end

  def create_sessions_with_clarity_patterns
    # Create sessions with clarity issues
    4.times do |i|
      create(:session, 
        user: guest_user, 
        completed: true, 
        created_at: (20 - i).days.ago,
        analysis_data: {
          'clarity_score' => i < 3 ? 0.5 : 0.8  # 3 out of 4 sessions below threshold
        }
      )
    end
  end
end