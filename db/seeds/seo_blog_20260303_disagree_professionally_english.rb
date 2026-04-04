# SEO Blog Seed — 2026-03-03 (overnight sprint)
# Keyword: how to disagree professionally in English at work (~890/mo, low difficulty)
# Cluster: workplace assertiveness for non-native English speakers
# Adjacent posts: how-to-give-feedback-in-english, how-to-speak-up-at-work, how-to-ask-questions-in-english
# Intel tie-in: The "principled pushback" narrative (Anthropic vs DoW) is culturally resonant;
#               professional disagreement as a career skill maps directly to AITalkCoach practice scenarios

slug = "how-to-disagree-professionally-in-english-at-work"
title = "How to Disagree Professionally in English at Work"
meta_description = "Afraid disagreeing will damage relationships? This guide teaches non-native English speakers exact phrases to push back professionally — and be taken seriously."
excerpt = "Staying quiet when you disagree costs you credibility over time. Here's how to disagree professionally in English at work in a way that strengthens relationships instead of straining them."

body = File.read(Rails.root.join("blog/2026-03-03-how-to-disagree-professionally-in-english-at-work.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-03-03 02:00:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
