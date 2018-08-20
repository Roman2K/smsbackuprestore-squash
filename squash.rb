require 'ox'
require 'set'
require 'pp'

module Modes
  module SMS
    EL_VALUE = "smses"
    ITEM_VALUE = "sms"
    HASH_ATTRS = [
      :address,
      :date,
      :subject,
      :body,
    ]
  end

  module Calls
    EL_VALUE = "calls"
    ITEM_VALUE = "call"
    HASH_ATTRS = [
      :number,
      :date,
      :duration,
    ]
  end
end

MODES = {
  "sms" => Modes::SMS,
  "calls" => Modes::Calls,
}

if ARGV.size != 1
  raise ArgumentError, "usage: %s <%s>" % [
    File.basename($0),
    MODES.keys * "|",
  ]
end
mode = MODES.fetch(ARGV.fetch(0))

out = nil
main = nil
seen = Set.new

counts = Hash.new(0).update \
  files: 0,
  total: 0,
  uniques: 0

def newer?(a, b)
  da = a[:backup_date] \
    and db = b[:backup_date] \
    and da > db
end

$stdin.each_line do |path|
  path.chomp!
  $stderr.puts "opening %s" % path
  if File.extname(path).downcase != ".xml"
    $stderr.puts "skipping non-XML"
    next
  end
  counts[:files] += 1
  doc = Ox.load(File.read(path), mode: :generic, convert_special: false)
  if !doc
    $stderr.puts "skipping empty"
    next
  end
  processed = false
  doc.each do |node|
    next if node.value != mode::EL_VALUE
    raise "double <main/>" if processed
    processed = true
    if !main
      main = node
      out = doc
    end
    if newer? node, main
      [:backup_date, :backup_set].each do |attr|
        if new_val = node[attr]
          main[attr] = new_val
        end
      end
    end
    node.nodes.each do |item|
      if item.value == mode::ITEM_VALUE # <call/> or <sms/>
        counts[:total] += 1
        hash = item.attributes.values_at(*mode::HASH_ATTRS).hash
        next if seen.include? hash
        seen << hash
        counts[:uniques] += 1
      end
      main << item unless main == node
    end
  end
  if !processed
    $stderr.puts "skipping unexpected mode element"
    next
  end
  $stderr.puts "%p" % counts
end

if !main
  $stderr.puts "no files processed"
  exit 0
end
main[:count] = "%d" % main.nodes.size

puts Ox.dump(out).gsub(/&amp;#(\d+);/, '&#\1;')
