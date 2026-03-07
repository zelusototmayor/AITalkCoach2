# SEO Blog Seed — 2026-03-07 (overnight sprint)
# Keyword: how to sound more confident speaking english in meetings (long-tail)
# Cluster: workplace communication confidence for non-native English speakers
# Adjacent posts: ask-questions-in-english-at-work, disagree-professionally, speak-up-at-work

slug = "how-to-sound-more-confident-speaking-english-in-meetings"
title = "How to Sound More Confident Speaking English in Meetings (Even If You're Not Fluent Yet)"
meta_description = "Learn how to sound more confident speaking English in meetings with a practical framework: entry phrases, 3-sentence structure, filler control, and daily drills for non-native professionals."
excerpt = "A practical system for non-native professionals who want to speak clearly and confidently in English meetings — without memorizing perfect scripts."

body = File.read(Rails.root.join("blog/2026-03-07-how-to-sound-more-confident-speaking-english-in-meetings.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-03-07 01:30:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
