# SEO Blog Seed — 2026-03-02 (morning sprint)
# Keyword: how to ask questions in english at work (~1,100/mo, low difficulty)
# Target: Non-native English professionals afraid to ask questions → look ignorant fear → AITalkCoach CTA
# Intel tie-in: Daily Intel "ask dumb questions" fear is career-limiting for non-native speakers;
#               the question-framing skill is learnable — perfect for AITalkCoach practice loop

slug = "how-to-ask-questions-in-english-at-work"
title = "How to Ask Questions in English at Work Without Sounding Ignorant"
meta_description = "Non-native English speaker afraid that asking questions will make you look uninformed? This guide shows you the exact phrases and techniques to ask smart, confident questions at work — and get taken seriously."
excerpt = "The question you don't ask costs more than the question that exposes a gap. Here's how to ask questions in English at work in a way that positions you as engaged and sharp — not uncertain or lost."

body = File.read(Rails.root.join("blog/2026-03-02-how-to-ask-questions-in-english-at-work.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-03-02 08:00:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
