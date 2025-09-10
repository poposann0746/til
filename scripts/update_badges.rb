

require "csv"
require "json"
require "date"
require "fileutils"

REPO_ROOT  = File.expand_path("..", __dir__)
CSV_PATH   = File.join(REPO_ROOT, "data", "study_log.csv")
BADGES_DIR = File.join(REPO_ROOT, "badges")

FileUtils.mkdir_p(BADGES_DIR)

def load_logs
  return [] unless File.exist?(CSV_PATH)

  logs = []
  CSV.foreach(CSV_PATH, headers: true) do |row|
    begin
      date = Date.strptime(row["date"], "%Y-%m-%d")
      minutes = Integer(row["minutes"])
      logs << [date, minutes]
    rescue StandardError
    end
  end
  logs
end

def to_hm(minutes)
  h = minutes / 60
  m = minutes % 60
  if h.positive? && m.positive?
    "#{h}h#{m}m"
  elsif h.positive?
    "#{h}h"
  else
    "#{m}m"
  end
end

def write_badge(filename:, label:, message:, color:)
  payload = {
    schemaVersion: 1,
    label: label,
    message: message,
    color: color
  }
  File.write(File.join(BADGES_DIR, filename), JSON.pretty_generate(payload))
end

def jst_today
  # JST(+09:00)の今日
  Time.now.getlocal("+09:00").to_date
end

logs = load_logs
today = jst_today

# 今日の学習時間
today_minutes = logs.select { |(d, _)| d == today }.sum { |(_, m)| m }
write_badge(
  filename: "daily.json",
  label: "today (JST)",
  message: to_hm(today_minutes),
  color: today_minutes.positive? ? "informational" : "lightgrey"
)

# 直近7日合計（今日を含む）
start = today - 6
weekly_minutes = logs.select { |(d, _)| (start..today).cover?(d) }.sum { |(_, m)| m }
weekly_color =
  if weekly_minutes.zero?
    "lightgrey"
  elsif weekly_minutes < 300 # <5h
    "orange"
  elsif weekly_minutes < 600 # <10h
    "yellow"
  else
    "green"
  end
write_badge(
  filename: "weekly.json",
  label: "last 7 days",
  message: to_hm(weekly_minutes),
  color: weekly_color
)

# 連続日数（0分の日で途切れる）
date_to_minutes = logs.to_h { |d, m| [d, m] }
streak = 0
cursor = today
loop do
  minutes = date_to_minutes[cursor] || 0
  break if minutes <= 0

  streak += 1
  cursor -= 1
end

streak_color =
  if streak >= 7
    "success"
  elsif streak >= 3
    "green"
  elsif streak >= 1
    "yellow"
  else
    "lightgrey"
  end

write_badge(
  filename: "streak.json",
  label: "streak",
  message: "#{streak} days",
  color: streak_color
)

puts "Generated badges: daily, weekly, streak -> #{BADGES_DIR}"
