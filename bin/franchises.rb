#!/usr/bin/env ruby
puts 'loading rails...'
ENV['RAILS_ENV'] = ARGV.first || ENV['RAILS_ENV'] || 'development'
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")

franchise_yml = "#{ENV['HOME']}/develop/neko-achievements/priv/rules/_franchises.yml"

HARDCODED_THRESHOLD = {
  ehon_yose: 50,
  dmatsu_san: 50,
  mazinkaiser: 60,
  hetalia: 90,
  pokemon: 80,
  gundam: 60,
  dragon_ball: 80,
  yes_precure: 80,
  doraemon: 50,
}
ALLOWED_SPECIAL_IDS = [15711, 2269, 14007, 20667, 24371, 2336]

puts 'loading franchises...'
raw_data = YAML.load_file(franchise_yml)

data = raw_data.dup

puts 'excluding recaps...'
data.each do |rule|
  recap_ids = Anime
    .where(franchise: rule['filters']['franchise'])
    .select(&:kind_special?)
    .select do |v|
      next if ALLOWED_SPECIAL_IDS.include?(v.id)
      v.name.match?(/\brecaps?\b|compilation movie|picture drama/i) ||
        v.description_en&.match?(/\brecaps?\b|compilation movie|picture drama/i) ||
        v.description_ru&.match?(/\bрекап\b|\bобобщение\b|\bчиби\b|краткое содержание/i)
    end
    .map(&:id)

  if recap_ids.any?
    rule['filters']['not_anime_ids'] = ((rule['filters']['not_anime_ids'] || []) + recap_ids).uniq.sort
  end
end

def duration anime
  episodes =
    if anime.anons?
      0
    elsif anime.released?
      anime.episodes
    else
      anime.episodes_aired.zero? ? anime.episodes : anime.episodes_aired
    end

  episodes * anime.duration
end

# data = data.select { |v| v['filters']['franchise'] == 'naruto' }
# data = data.select { |v| v['filters']['franchise'] == 'zero_no_tsukaima' }

puts 'generating thresholds...'
data.each do |rule|
  franchise = Anime.where(franchise: rule['filters']['franchise'])
  if rule['filters']['not_anime_ids'].present?
    franchise = franchise.where.not(id: rule['filters']['not_anime_ids'])
  end
  franchise = franchise.reject(&:anons?)

  ova = franchise.select(&:kind_ova?)
  long_specials = franchise.select(&:kind_special?).select { |v| v.duration >= 22 }
  short_specials = franchise.select(&:kind_special?).select { |v| v.duration < 22 && v.duration > 5 }
  mini_specials = (franchise.select(&:kind_special?) + franchise.select(&:kind_ona?)).select { |v| v.duration <= 5 }

  important_titles = franchise.reject(&:kind_special?)

  total_duration = franchise.sum { |v| duration v }
  ova_duration = ova.sum { |v| duration v }
  long_specials_duration = long_specials.sum { |v| duration v }
  short_specials_duration = short_specials.sum { |v| duration v }
  mini_specials_duration = mini_specials.sum { |v| duration v }

  ova_duration_subtract = 
    if ova_duration * 1.0 / total_duration <= 0.1 && franchise.size > 5 && ova.size > 2
      ova_duration / 2
    else
      0
    end

  long_specials_duration_subtract =
    if long_specials_duration * 1.0 / total_duration <= 0.1
      (long_specials.size > 2 ? long_specials_duration / 2.0 : long_specials_duration)
    else
      0
    end

  short_specials_duration_subtract = short_specials.size <= 3 ? short_specials_duration : short_specials_duration / 2.0

  threshold = (
    total_duration -
    ova_duration_subtract -
    long_specials_duration_subtract -
    short_specials_duration_subtract -
    mini_specials_duration
  ) * 100.0 / total_duration

  if total_duration > 20_000
    threshold = [60, threshold].min
  elsif total_duration > 10_000
    threshold = [80, threshold].min
  elsif total_duration > 5_000
    threshold = [90, threshold].min
  end

  if franchise.size >= 7 || total_duration > 2_000
    threshold = [95, threshold].min
  end

  animes_with_year = franchise.reject(&:kind_special?).select(&:year)
  average_year = animes_with_year.sum(&:year) * 1.0 / animes_with_year.size
  if average_year < 1987
    threshold -= 15
  elsif average_year < 1991
    threshold -= 10
  elsif average_year < 1996
    threshold -= 5
  end

  important_durations = important_titles
    .map { |v| duration v }
    .sort
    .reverse

  important_duration = important_durations[0..[(important_titles.size * 0.4).round, 3].max].sum
  important_threshold = important_duration * 100.0 / total_duration

  threshold = [important_threshold, threshold].max

  current_threshold = rule['threshold'].gsub('%', '').to_f
  new_threshold = HARDCODED_THRESHOLD[rule['filters']['franchise'].to_sym] || threshold.floor(1)

  if current_threshold != new_threshold
    ap(
      franchise: rule['filters']['franchise'],
      new_threshold: new_threshold
    )
    rule['threshold'] = "#{new_threshold}%".gsub(/\.0%$/, '%')
  end
end

if data.any? && data.size == raw_data.size
  File.open(franchise_yml, 'w') { |f| f.write data.to_yaml }
  puts "\n" + data.map { |v| v['filters']['franchise'] }.join(' ')
end

begin
  puts "\nsorting by popularity...\n"
  data = data
    .sort_by do |v|
        Anime
        .where(franchise: v['filters']['franchise'], status: 'released')
        .sum { |v| v.rates.where(status: %i[completed rewatching]).size }
    end
    .reverse

  if data.any? && data.size == raw_data.size
    File.open(franchise_yml, 'w') { |f| f.write data.to_yaml }
    puts data.map { |v| v['filters']['franchise'] }.join(' ')
  end
rescue Interrupt
end