# SEO Blog Seed — 2026-03-01 (overnight sprint)
# Keyword: how to sound confident on video calls (~1,400/mo, low difficulty)
# Target: Non-native English professionals on Zoom/Teams → confidence gap → AITalkCoach CTA
# Intel tie-in: COVID-era video call work pattern still dominant; 747-pilot deskilling essay;
#               remote-first teams = video calls are the primary visibility surface for career growth

slug = "how-to-sound-confident-on-video-calls-english-non-native"
title = "How to Sound Confident on Video Calls When English Isn't Your First Language"
meta_description = "Non-native English speaker who freezes up on Zoom or Teams calls? These 8 techniques will help you sound clearer, more confident, and more authoritative — starting with your next meeting."
excerpt = "Video calls remove most of the things non-native speakers rely on to communicate: body language, proximity, real-time visual feedback. Here's how to build the specific confidence you need for the remote English speaking environment."

body = File.read(Rails.root.join("blog/2026-03-01-how-to-sound-confident-on-video-calls-english-non-native.md"))

BlogPost.find_or_initialize_by(slug: slug).tap do |post|
  post.title = title
  post.meta_description = meta_description
  post.excerpt = excerpt
  post.content = body
  post.published_at = Time.zone.parse("2026-03-01 02:00:00")
  post.save!
  puts "✅ Seeded: #{title}"
end
