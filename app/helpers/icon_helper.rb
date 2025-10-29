# frozen_string_literal: true

module IconHelper
  def icon_svg(name, css_class: "icon", **options)
    svg_content = case name.to_sym
    when :mic, :microphone
      '<path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2M12 19v3"/>'
    when :chart, :bar_chart
      '<polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>'
    when :trending_up
      '<polyline points="23 6 13.5 15.5 8.5 10.5 1 18"/><polyline points="17 6 23 6 23 12"/>'
    when :target
      '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>'
    when :fire, :flame
      '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>'
    when :star
      '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>'
    when :lightbulb, :bulb
      '<line x1="9" y1="18" x2="15" y2="18"/><line x1="10" y1="22" x2="14" y2="22"/><path d="M15.09 14c.18-.98.65-1.74 1.41-2.5A4.65 4.65 0 0 0 18 8 6 6 0 0 0 6 8c0 1 .23 2.23 1.5 3.5A4.61 4.61 0 0 1 8.91 14"/>'
    when :rocket
      '<path d="M4.5 16.5c-1.5 1.26-2 5-2 5s3.74-.5 5-2c.71-.84.7-2.13-.09-2.91a2.18 2.18 0 0 0-2.91-.09z"/><path d="m12 15-3-3a22 22 0 0 1 2-3.95A12.88 12.88 0 0 1 22 2c0 2.72-.78 7.5-6 11a22.35 22.35 0 0 1-4 2z"/><path d="M9 12H4s.55-3.03 2-4c1.62-1.08 5 0 5 0"/><path d="M12 15v5s3.03-.55 4-2c1.08-1.62 0-5 0-5"/>'
    when :check, :check_circle
      '<path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/>'
    when :x, :x_circle
      '<circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/>'
    when :lock
      '<rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/>'
    when :refresh, :rotate
      '<polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/>'
    when :zap, :lightning, :bolt
      '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>'
    when :clock, :timer
      '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>'
    when :hourglass
      '<path d="M6 3h12v4l-6 5 6 5v4H6v-4l6-5-6-5V3z"/>'
    when :upload
      '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" y1="3" x2="12" y2="15"/>'
    when :download
      '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" y1="15" x2="12" y2="3"/>'
    when :file_text, :notes
      '<path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/>'
    when :clipboard
      '<path d="M16 4h2a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H6a2 2 0 0 1-2-2V6a2 2 0 0 1 2-2h2"/><rect x="8" y="2" width="8" height="4" rx="1" ry="1"/>'
    when :shuffle, :random, :dice
      '<polyline points="16 3 21 3 21 8"/><line x1="4" y1="20" x2="21" y2="3"/><polyline points="21 16 21 21 16 21"/><line x1="15" y1="15" x2="21" y2="21"/><line x1="4" y1="4" x2="9" y2="9"/>'
    when :activity
      '<polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/>'
    when :sparkles
      '<path d="M12 3v3m0 12v3m9-9h-3M6 12H3m15.364-6.364-2.121 2.121M8.757 15.243l-2.121 2.121m12.728 0-2.121-2.121M8.757 8.757 6.636 6.636"/><circle cx="12" cy="12" r="2"/>'
    when :info
      '<circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/>'
    when :calendar
      '<rect x="3" y="4" width="18" height="18" rx="2" ry="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/>'
    when :arrow_right
      '<line x1="5" y1="12" x2="19" y2="12"/><polyline points="12 5 19 12 12 19"/>'
    when :play
      '<polygon points="5 3 19 12 5 21 5 3"/>'
    when :x_simple
      '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>'
    when :link, :chain
      '<path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71"/><path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71"/>'
    when :search
      '<circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>'
    when :trash, :delete
      '<polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" y1="11" x2="10" y2="17"/><line x1="14" y1="11" x2="14" y2="17"/>'
    when :alert, :warning, :alert_triangle
      '<path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/>'
    when :shield, :security
      '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>'
    when :eye, :visibility
      '<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"/><circle cx="12" cy="12" r="3"/>'
    when :music, :musical_note
      '<path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/>'
    when :infinity
      '<path d="M18.178 8C17.286 6.742 15.714 6 14 6c-2.757 0-5 2.243-5 5s2.243 5 5 5c1.714 0 3.286-.742 4.178-2M5.822 8C6.714 6.742 8.286 6 10 6c2.757 0 5 2.243 5 5s-2.243 5-5 5c-1.714 0-3.286-.742-4.178-2"/>'
    when :briefcase, :business
      '<rect x="2" y="7" width="20" height="14" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>'
    when :message, :chat, :comment
      '<path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>'
    when :book
      '<path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20"/><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z"/>'
    when :question, :help
      '<circle cx="12" cy="12" r="10"/><path d="M9.09 9a3 3 0 0 1 5.83 1c0 2-3 3-3 3"/><line x1="12" y1="17" x2="12.01" y2="17"/>'
    when :wave, :waveform
      '<path d="M2 12h4l3-9 4 18 3-9h4"/>'
    when :bridge
      '<path d="M2 18h20M4 10c0-2.5 2-4 4-4h8c2 0 4 1.5 4 4M8 18v-6M16 18v-6"/>'
    else
      '<circle cx="12" cy="12" r="10"/>' # default fallback
    end

    # Build attributes
    attrs = {
      class: css_class,
      viewBox: "0 0 24 24",
      fill: "none",
      stroke: "currentColor",
      'stroke-width': "2",
      'stroke-linecap': "round",
      'stroke-linejoin': "round"
    }.merge(options)

    attr_string = attrs.map { |k, v| %(#{k}="#{v}") }.join(" ")

    %(<svg #{attr_string}>#{svg_content}</svg>).html_safe
  end

  # Map emoji to icon name for backend compatibility
  def emoji_to_icon(emoji_string)
    mapping = {
      "🎤" => :mic,
      "⭐" => :star,
      "🎯" => :target,
      "⏱️" => :clock,
      "🎵" => :music,
      "🗣️" => :mic,
      "👄" => :mic,
      "🔍" => :search,
      "💡" => :lightbulb,
      "⚡" => :lightning,
      "📖" => :book,
      "❓" => :question,
      "🎲" => :shuffle,
      "🔗" => :link,
      "🌊" => :wave,
      "📝" => :file_text,
      "🌉" => :bridge,
      "📋" => :clipboard,
      "💼" => :briefcase,
      "📊" => :chart,
      "🎓" => :star,
      "✓" => :check,
      "🚀" => :rocket,
      "🔥" => :fire,
      "🔒" => :lock,
      "✨" => :sparkles,
      "💬" => :message,
      "📈" => :trending_up,
      "🎙️" => :mic,
      "❌" => :x_circle,
      "⏳" => :hourglass,
      "🛡️" => :shield,
      "📅" => :calendar,
      "♾️" => :infinity,
      "🗑️" => :trash,
      "⚠️" => :alert,
      "👁️" => :eye,
      "📤" => :upload,
      "☆" => :star
    }

    mapping[emoji_string] || :info  # default fallback
  end

  # Render icon from emoji (for backend data)
  def icon_from_emoji(emoji_string, css_class: "icon-inline")
    icon_name = emoji_to_icon(emoji_string)
    icon_svg(icon_name, css_class: css_class)
  end
end
