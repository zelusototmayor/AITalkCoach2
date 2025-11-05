namespace :admin do
  desc "Make a user an admin"
  task :create, [:email] => :environment do |t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rails admin:create[user@example.com]"
      exit 1
    end

    user = User.find_by(email: email)

    if user.nil?
      puts "User with email '#{email}' not found"
      exit 1
    end

    if user.admin?
      puts "User '#{email}' is already an admin"
    else
      user.update!(admin: true)
      puts "User '#{email}' is now an admin"
    end
  end

  desc "Remove admin privileges from a user"
  task :remove, [:email] => :environment do |t, args|
    email = args[:email]

    if email.blank?
      puts "Usage: rails admin:remove[user@example.com]"
      exit 1
    end

    user = User.find_by(email: email)

    if user.nil?
      puts "User with email '#{email}' not found"
      exit 1
    end

    if !user.admin?
      puts "User '#{email}' is not an admin"
    else
      user.update!(admin: false)
      puts "Admin privileges removed from '#{email}'"
    end
  end

  desc "List all admin users"
  task :list => :environment do
    admins = User.where(admin: true)

    if admins.empty?
      puts "No admin users found"
    else
      puts "Admin users:"
      admins.each do |admin|
        puts "  - #{admin.email} (#{admin.name})"
      end
    end
  end
end
