# SEO Blog Seed — 2026-03-09
# Keyword: how to stop saying um and uh when speaking
# Cluster: filler words, public speaking, communication skills
# Volume est: 1,900/mo | Difficulty: Low

slug = "how-to-stop-saying-um-and-uh-when-speaking"
title = "How to Stop Saying Um and Uh When Speaking (5 Proven Techniques)"
meta_description = "Learn how to stop saying um and uh when speaking with 5 proven techniques. Cut filler words fast and sound more confident with AI-powered practice."
excerpt = "Filler words like 'um' and 'uh' undermine your credibility — even when your content is strong. Here are 5 proven techniques to eliminate them for good."
body = File.read(Rails.root.join("blog/2026-03-09-how-to-stop-saying-um-and-uh-when-speaking.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-03-09 10:00:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
