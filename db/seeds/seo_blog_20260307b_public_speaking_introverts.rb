# SEO Blog Seed — 2026-03-07b
# Keyword: public speaking tips for introverts
# Cluster: presentation skills, introverts, communication coaching
# Volume est: 2,900/mo | Difficulty: Medium

slug = "public-speaking-tips-for-introverts"
title = "Public Speaking Tips for Introverts: How to Present Without Draining Yourself"
meta_description = "Practical public speaking tips for introverts: energy management, deliberate pauses, eye contact systems, and AI practice that works with your nature."
excerpt = "Introverts can become powerful speakers — not by faking extroversion, but by building a system that works with their neurology."

body = File.read(Rails.root.join("blog/2026-03-07-public-speaking-tips-for-introverts.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-03-07 10:30:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
