# SEO Blog Seed — 2026-03-11
# Keyword: how to handle difficult questions in presentations
# Cluster: presentation skills, Q&A techniques, public speaking confidence
# Volume est: ~1,900/mo | Difficulty: Medium

slug = "how-to-handle-difficult-questions-in-presentations"
title = "How to Handle Difficult Questions in Presentations (Without Freezing Up)"
meta_description = "Dreading Q&A? Learn exactly how to handle difficult questions in presentations — including hostile, off-topic, and 'I don't know' moments — with confidence."
excerpt = "The Q&A portion of a presentation is more nerve-wracking than the presentation itself for most professionals. Not because they don't know their material — but because they haven't practiced handling unexpected pressure in real time."

body = File.read(Rails.root.join("blog/2026-03-11-how-to-handle-difficult-questions-in-presentations.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-03-11 10:00:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
