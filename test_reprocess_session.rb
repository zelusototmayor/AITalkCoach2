#!/usr/bin/env ruby
# Test reprocessing Session 97 with the new AI filler word detection

require_relative 'config/environment'

session_id = 97
session = Session.find(session_id)

puts "=" * 80
puts "Reprocessing Session #{session_id}"
puts "=" * 80

# Clear existing filler word issues
filler_issues = session.issues.where(kind: 'filler_word')
puts "\nDeleting #{filler_issues.count} existing filler word issues..."
filler_issues.destroy_all

# Clear cached AI results
puts "Clearing AI cache..."
Rails.cache.clear

# Re-run AI analysis
puts "\nRunning AI refiner..."
transcript_data = {
  transcript: session.analysis_data['transcript'],
  words: session.analysis_data['words'],
  metadata: {
    duration: session.duration_seconds
  }
}

ai_refiner = Analysis::AiRefiner.new(session, {
  confidence_threshold: 0.6,
  cache_ttl: 1.hour
})

puts "Detecting filler words with AI..."
filler_issues_found = ai_refiner.send(:detect_filler_words_with_ai, transcript_data)

puts "\n" + "=" * 80
puts "Results:"
puts "=" * 80

puts "\nAI detected #{filler_issues_found.length} filler words:"

filler_issues_found.each_with_index do |issue, index|
  puts "\n#{index + 1}. Filler word: '#{issue[:filler_word]}'"
  puts "   Context: \"#{issue[:text]}\""
  puts "   Time: #{issue[:start_ms]}ms - #{issue[:end_ms]}ms"
  puts "   Confidence: #{issue[:ai_confidence]}"
  puts "   Tip: #{issue[:tip]}"

  # Create the issue record
  session.issues.create!(
    kind: issue[:kind],
    start_ms: issue[:start_ms],
    end_ms: issue[:end_ms],
    text: issue[:text],
    severity: issue[:severity],
    source: issue[:source],
    data: {
      filler_word: issue[:filler_word],
      rationale: issue[:rationale],
      ai_confidence: issue[:ai_confidence],
      tip: issue[:tip],
      category: issue[:category],
      matched_words: issue[:matched_words],
      validation_status: issue[:validation_status]
    }
  )
end

puts "\n" + "=" * 80
puts "Session #{session_id} reprocessed successfully!"
puts "Visit: https://localhost:3001/sessions/#{session_id}"
puts "=" * 80
