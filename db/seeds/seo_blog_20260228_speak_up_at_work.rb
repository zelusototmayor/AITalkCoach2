# SEO Blog Seed — 2026-02-28
# Keyword: how to speak up at work in english (~1,100/mo, low difficulty)
# Target: Non-native English speakers → professional confidence → AITalkCoach CTA

slug = "how-to-speak-up-in-english-at-work-shy-uncertain"
title = "How to Speak Up More in English at Work When You're Shy or Unsure"
meta_description = "Non-native English speaker who goes quiet in meetings? Practical strategies to speak up confidently at work — from pre-loading contributions to the 3-second rule."
excerpt = "Most non-native speakers don't stay quiet in meetings because their English is bad. They stay quiet because they're calculating risk in real time — and the math keeps telling them to wait. Here's how to change that."

body = File.read(Rails.root.join("blog/2026-02-28-how-to-speak-up-in-english-at-work-shy-uncertain.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-02-28 02:00:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
