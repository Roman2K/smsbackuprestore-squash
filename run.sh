for mode in sms calls; do
  for dir in data/archive-$mode-*; do
    ls "$dir" | while read p; do
      echo "$dir"/"$p"
    done
  done | ruby squash.rb $mode > $mode.xml
done
