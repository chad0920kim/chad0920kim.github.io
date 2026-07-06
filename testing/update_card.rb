#!/usr/bin/env ruby
# Updates one app-card's version/build/date badges in testing/index.html and
# pushes the change, so the page stays in sync with each Fastlane deploy.
#
# Usage:
#   ruby update_card.rb --title "슬라이드 100" --version 1.0.0 --build 2 [--date 2026-07-08] [--track "내부 테스트"]

require "optparse"
require "time"
require "fileutils"

options = { date: Time.now.strftime("%Y-%m-%d") }
OptionParser.new do |opts|
  opts.on("--title TITLE") { |v| options[:title] = v }
  opts.on("--version VERSION") { |v| options[:version] = v }
  opts.on("--build BUILD") { |v| options[:build] = v }
  opts.on("--date DATE") { |v| options[:date] = v }
  opts.on("--track TRACK") { |v| options[:track] = v }
end.parse!(ARGV)

abort "usage: update_card.rb --title TITLE --version VERSION --build BUILD [--date DATE] [--track TRACK]" \
  unless options[:title] && options[:version] && options[:build]

REPO_ROOT = File.expand_path("..", __dir__)
INDEX_PATH = File.join(__dir__, "index.html")

html = File.read(INDEX_PATH)

# Split into app-card blocks while keeping the delimiter, so we can find and
# replace exactly the block whose <h2> matches --title.
blocks = html.split(/(?=<div class="app-card">)/)
title_pattern = /<h2>#{Regexp.escape(options[:title])}<\/h2>/

matched = false
updated_blocks = blocks.map do |block|
  next block unless block =~ title_pattern

  matched = true
  new_block = block.sub(/v[\d.]+\s*\(빌드\s*\d+\)/, "v#{options[:version]} (빌드 #{options[:build]})")
  new_block = new_block.sub(/\d{4}-\d{2}-\d{2}|빌드일 미정/, options[:date])
  if options[:track]
    # Track is the 4th <span> in the .meta block; replace it specifically to
    # avoid accidentally touching the version/date spans again.
    spans = new_block.scan(/<span>.*?<\/span>/)
    if spans.length >= 4
      new_block = new_block.sub(spans[3], "<span>#{options[:track]}</span>")
    end
  end
  new_block
end

abort "no app-card found with <h2>#{options[:title]}</h2> in #{INDEX_PATH}" unless matched

File.write(INDEX_PATH, updated_blocks.join)
puts "updated #{options[:title]} -> v#{options[:version]} (빌드 #{options[:build]}), #{options[:date]}"

Dir.chdir(REPO_ROOT) do
  system("git", "add", "testing/index.html", exception: true)
  status = `git status --porcelain -- testing/index.html`.strip
  if status.empty?
    puts "no changes to commit (page already up to date)"
  else
    system("git", "commit", "-m", "chore: update #{options[:title]} to v#{options[:version]} (build #{options[:build]})", exception: true)
    system("git", "push", exception: true)
    puts "pushed testing/index.html update"
  end
end
