# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create guest user for v1 (no authentication required)
guest_user = User.find_or_create_by!(email: "guest@aitalkcoach.local") do |user|
  puts "Creating guest user..."
end

puts "Guest user exists with ID: #{guest_user.id}"
