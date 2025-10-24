require 'test_helper'

class EnhancedProgressTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in @user
  end

  test "session show page uses enhanced progress for pending sessions" do
    session = @user.sessions.create!(
      title: "Test Session",
      language: "en",
      media_kind: "audio",
      processing_state: "pending"
    )

    get session_path(session)
    assert_response :success

    # Should render enhanced processing status partial
    assert_select '.enhanced-processing-container'
    assert_select '.processing-timeline'
    assert_select '.progressive-metrics-area'
    assert_select '.coaching-tips-carousel'
  end

  test "session show page uses enhanced progress for processing sessions" do
    session = @user.sessions.create!(
      title: "Test Session",
      language: "en",
      media_kind: "audio",
      processing_state: "processing"
    )

    get session_path(session)
    assert_response :success

    assert_select '.enhanced-processing-container'
  end

  test "session show page shows regular content for completed sessions" do
    session = @user.sessions.create!(
      title: "Test Session",
      language: "en",
      media_kind: "audio",
      processing_state: "completed",
      completed: true,
      analysis_data: {
        "wpm" => 150,
        "clarity_score" => 0.85,
        "filler_rate" => 0.03
      }
    )

    get session_path(session)
    assert_response :success

    # Should show regular analysis content, not processing UI
    assert_select '.enhanced-processing-container', count: 0
    assert_select '.session-title-main'
  end

  test "API status endpoint returns progressive metrics" do
    session = @user.sessions.create!(
      title: "Test Session",
      language: "en",
      media_kind: "audio",
      processing_state: "processing",
      analysis_data: {
        "processing_stage" => "transcription",
        "processing_progress" => 35,
        "interim_metrics" => {
          "duration_seconds" => 45,
          "word_count" => 120,
          "estimated_wpm" => 160
        }
      }
    )

    get api_session_status_path(session), as: :json
    assert_response :success

    json = JSON.parse(response.body)

    # Check basic fields
    assert_equal session.id, json['id']
    assert_equal 'processing', json['processing_state']

    # Check progress info
    assert json['progress_info'].present?
    assert_equal 35, json['progress_info']['progress']
    assert_equal 'transcription', json['progress_info']['current_stage']

    # Check interim metrics
    assert json['interim_metrics'].present?
    assert_equal 45, json['interim_metrics']['duration_seconds']
    assert_equal 120, json['interim_metrics']['word_count']
    assert_equal 160, json['interim_metrics']['estimated_wpm']

    # Check processing stage
    assert_equal 'transcription', json['processing_stage']
    assert_equal 35, json['processing_progress']
  end

  test "API status endpoint handles sessions without interim metrics" do
    session = @user.sessions.create!(
      title: "Test Session",
      language: "en",
      media_kind: "audio",
      processing_state: "pending"
    )

    get api_session_status_path(session), as: :json
    assert_response :success

    json = JSON.parse(response.body)

    # Should return empty interim metrics
    assert_equal({}, json['interim_metrics'])
  end

  test "estimated time calculation" do
    session = @user.sessions.create!(
      title: "Test Session",
      language: "en",
      media_kind: "audio",
      processing_state: "processing",
      analysis_data: {
        "processing_stage" => "analysis",
        "processing_progress" => 60
      }
    )

    get api_session_status_path(session), as: :json
    json = JSON.parse(response.body)

    # At 60% progress, should show remaining time
    assert_match(/\d+s remaining/, json['progress_info']['estimated_time'])
  end

  test "stage completion detection" do
    session = @user.sessions.create!(
      title: "Test Session",
      language: "en",
      media_kind: "audio",
      processing_state: "completed",
      completed: true
    )

    get api_session_status_path(session), as: :json
    json = JSON.parse(response.body)

    assert_equal 'completed', json['processing_state']
    assert_equal 100, json['progress_info']['progress']
    assert_equal 'Done', json['progress_info']['estimated_time']
  end
end
