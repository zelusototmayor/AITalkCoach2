class Api::SessionsController < ApplicationController
  before_action :set_guest_user
  before_action :set_session, except: [:count]
  
  def timeline
    issues = @session.issues.order(:start_ms)
    
    timeline_data = issues.map do |issue|
      {
        id: issue.id,
        kind: issue.kind,
        start_ms: issue.start_ms,
        end_ms: issue.end_ms,
        text: issue.text,
        confidence: issue.label_confidence,
        source: issue.source
      }
    end
    
    render json: {
      session_id: @session.id,
      duration_ms: @session.duration_ms,
      issues: timeline_data
    }
  end
  
  def export
    case params[:format]
    when 'txt'
      transcript = generate_transcript_export
      render plain: transcript, content_type: 'text/plain'
    when 'csv'
      csv_data = generate_csv_export
      send_data csv_data, 
                filename: "#{@session.title.parameterize}-analysis.csv",
                type: 'text/csv'
    else
      export_data = {
        session: {
          id: @session.id,
          title: @session.title,
          language: @session.language,
          duration_ms: @session.duration_ms,
          created_at: @session.created_at,
          completed: @session.completed
        },
        analysis: @session.analysis_data,
        issues: @session.issues.map do |issue|
          {
            kind: issue.kind,
            category: issue.category,
            start_ms: issue.start_ms,
            end_ms: issue.end_ms,
            duration_ms: issue.duration_ms,
            text: issue.text,
            rationale: issue.rationale,
            source: issue.source,
            rewrite: issue.rewrite,
            tip: issue.tip,
            coaching_note: issue.coaching_note,
            confidence: issue.label_confidence,
            severity: issue.severity
          }
        end
      }
      render json: export_data
    end
  end
  
  def reprocess_ai
    # Allow reprocessing of completed or failed sessions, but not pending/processing ones
    if @session.processing_state.in?(['completed', 'failed'])
      # Store original state for logic
      was_failed = @session.processing_state == 'failed'
      
      # Clear any existing analysis data and issues for fresh reprocessing
      if was_failed
        @session.issues.destroy_all
        @session.update!(analysis_data: {})
      end
      
      # Reset session state for reprocessing
      @session.update!(
        processing_state: 'pending',
        incomplete_reason: nil,
        completed: false
      )
      
      # Enqueue reprocessing job
      Sessions::ProcessJob.perform_later(@session.id, { reprocess: true })
      
      render json: { 
        message: 'Reprocessing started successfully', 
        session_id: @session.id,
        new_state: 'pending'
      }, status: :accepted
    else
      current_state = @session.processing_state
      render json: { 
        error: "Cannot reprocess session in '#{current_state}' state. Please wait for current processing to complete or fail.",
        current_state: current_state
      }, status: :unprocessable_content
    end
  end
  
  def insights
    timeframe = params[:timeframe] || '30d'
    
    # Calculate date range
    days = case timeframe
    when '7d' then 7
    when '30d' then 30
    when '90d' then 90
    else 30
    end
    
    user_sessions = @current_user.sessions
      .where(completed: true)
      .where('created_at >= ?', days.days.ago)
      .includes(:issues)
      .order(:created_at)
      .limit(100) # Limit to prevent huge payloads
      .map do |session|
        {
          id: session.id,
          title: session.title,
          created_at: session.created_at,
          duration: session.duration_ms,
          metrics: extract_session_metrics(session)
        }
      end
    
    render json: {
      sessions: user_sessions,
      timeframe: timeframe,
      total_count: @current_user.sessions.where(completed: true).count
    }
  end
  
  def status
    render json: {
      id: @session.id,
      processing_state: @session.processing_state,
      completed: @session.completed,
      incomplete_reason: @session.incomplete_reason,
      updated_at: @session.updated_at,
      progress_info: get_progress_info(@session)
    }
  end

  def count
    total_count = @current_user.sessions.count
    render json: { count: total_count }
  end
  
  private
  
  def set_session
    return if @current_user.nil?
    @session = @current_user.sessions.find(params[:id])
  end
  
  def set_guest_user
    @current_user = User.find_by(email: 'guest@aitalkcoach.local')
    
    unless @current_user
      render json: { error: 'Guest user not found' }, status: :unauthorized
      return false
    end
  end
  
  def generate_transcript_export
    # Safely access analysis_data to avoid circular references
    analysis_data = @session.analysis_data || {}
    transcript = analysis_data['transcript'] || 'No transcript available'
    issues_count = @session.issues.count
    
    # Safely handle duration calculation
    duration_ms = @session.duration_ms || 0
    duration_str = duration_ms > 0 ? Time.at(duration_ms / 1000.0).utc.strftime('%M:%S') : '00:00'
    
    header = "#{@session.title}\n"
    header << "Language: #{@session.language.upcase}\n"
    header << "Duration: #{duration_str}\n"
    header << "Date: #{@session.created_at.strftime('%B %d, %Y at %l:%M %p')}\n"
    header << "Issues Found: #{issues_count}\n"
    header << "\n" + "="*50 + "\n\n"
    
    content = header + transcript
    
    if issues_count > 0
      content << "\n\n" + "="*50 + "\n"
      content << "SPEECH ANALYSIS ISSUES\n"
      content << "="*50 + "\n\n"
      
      # Safely load issues to avoid N+1 queries and circular references
      issues_by_category = @session.issues.includes(:session).group_by(&:category)
      
      issues_by_category.each do |category, category_issues|
        next if category.blank?
        
        category_name = category.to_s.humanize
        content << "#{category_name.upcase} (#{category_issues.count})\n"
        content << "-" * (category_name.length + 10) + "\n\n"
        
        category_issues.each do |issue|
          # Safely handle timestamp calculation
          start_ms = issue.start_ms || 0
          timestamp = start_ms > 0 ? Time.at(start_ms / 1000.0).utc.strftime("%M:%S") : "00:00"
          
          # Safely handle text field to avoid circular references
          issue_text = issue.text.to_s.strip
          content << "[#{timestamp}] \"#{issue_text}\"\n"
          content << "💡 #{issue.coaching_note}\n" if issue.coaching_note.present?
          content << "Suggested rewrite: #{issue.rewrite}\n" if issue.rewrite.present?
          content << "\n"
        end
      end
    end
    
    content
  end
  
  def generate_csv_export
    require 'csv'
    
    CSV.generate(headers: true) do |csv|
      csv << ['Timestamp', 'Category', 'Issue Text', 'Coaching Note', 'Suggested Rewrite', 'Confidence', 'Severity']
      
      @session.issues.order(:start_ms).each do |issue|
        timestamp = Time.at(issue.start_ms / 1000.0).utc.strftime("%M:%S")
        csv << [
          timestamp,
          issue.category&.humanize,
          issue.text,
          issue.coaching_note,
          issue.rewrite,
          issue.label_confidence,
          issue.severity&.humanize
        ]
      end
    end
  end

  def extract_session_metrics(session)
    return {} unless session.analysis_data.present?
    
    analysis = session.analysis_data
    issues_count = session.issues.count
    
    {
      clarity_score: analysis['clarity_score'] || calculate_clarity_from_issues(session),
      words_per_minute: analysis['wpm'],
      filler_rate: analysis['filler_rate'],
      issues_count: issues_count
    }.compact
  end

  def calculate_clarity_from_issues(session)
    return nil unless session.duration_ms && session.duration_ms > 0
    
    total_issue_duration = session.issues.sum(&:duration_ms) || 0
    clarity_score = 1.0 - (total_issue_duration.to_f / session.duration_ms)
    [clarity_score, 0.0].max
  end

  def get_progress_info(session)
    case session.processing_state
    when 'pending'
      {
        step: 'Queued for processing',
        progress: 5,
        estimated_time: 'Starting analysis...'
      }
    when 'processing'
      # Better progress indication without confusing countdown
      processing_duration = Time.current - session.updated_at
      
      # Progressive status messages based on duration
      if processing_duration < 10
        step_message = 'Extracting audio...'
        progress = 15
      elsif processing_duration < 30
        step_message = 'Transcribing speech...'
        progress = 35
      elsif processing_duration < 60
        step_message = 'Analyzing speech patterns...'
        progress = 60
      elsif processing_duration < 90
        step_message = 'Generating insights...'
        progress = 80
      else
        step_message = 'Finalizing analysis...'
        progress = 90
      end
      
      {
        step: step_message,
        progress: progress,
        estimated_time: 'Analyzing your speech...'
      }
    when 'completed'
      {
        step: 'Analysis complete',
        progress: 100,
        estimated_time: 'Done'
      }
    when 'failed'
      {
        step: 'Processing failed',
        progress: 0,
        estimated_time: 'Please try again'
      }
    else
      {
        step: 'Unknown state',
        progress: 0,
        estimated_time: 'Please refresh the page'
      }
    end
  end
end