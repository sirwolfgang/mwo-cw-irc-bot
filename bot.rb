require 'active_support/core_ext/numeric/time'
require 'cinch'

$planet_list_regexp = Regexp.union(File.read('planet_list.txt').lines.map{ |e| e.downcase.gsub("\n", '') }) 
$planets = {}

class Planet < Struct.new(:name, :groups)
  def player_count
    groups.select! { |group| (group.timestamp.to_i > Time.now.to_i) }
    count = 0
    groups.each { |group| count += group.player_count }
    
    if count < 0
      groups = []
      return 0
    end
    
    count
  end
  
  def to_s
    "[#{name} has queued #{player_count} players in the last 15 minutes]"
  end
end

class Group < Struct.new(:timestamp, :player_count)
end

bot = Cinch::Bot.new do
  configure do |c|
    c.server   = "irc.freenode.org"
    c.nick     = "CommunityWarfare"
    c.channels = ["#mechwarrior"]
  end

  on :message, "!status" do |m|
    $planets.select! { |symbol, planet| (planet.player_count > 0) }
    $planets.each do |symbol, planet|
      m.reply planet.to_s
    end
    
    if $planets.empty?
      m.reply "[No Recent Activitly found]"
    end
  end
  
  on :message, "!help" do |m|
    m.reply "Use `+# planet` to add your group to the list. Your group will have to be readded in 15 mins. If you quit, just `-# planet` to remove your group. Use `!status` to list recent activity.\nExample: +12 somerset"
  end
  
  on :message do |m|
    
    planet_name = m.message.downcase.match($planet_list_regexp)
    next if planet_name.nil?
    
    players = m.message.match /^[\-|\+]\d+/
    next if players.nil?
    
    planet_sym = planet_name.to_s.to_sym
    
    $planets[planet_sym] ||= Planet.new(planet_name, [])
    $planets[planet_sym].groups << Group.new(15.minutes.from_now, players.to_s.to_i)
    
    m.reply $planets[planet_sym].to_s
  end
  
  on :join do |m|
    m.reply "Welcome #{m.user.nick}! Use `!help` to get started."
  end
end

bot.start