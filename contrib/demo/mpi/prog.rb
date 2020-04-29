ncores = ARGV[0].to_f
data_file = ARGV[1]
size = /\d+/.match(data_file)[0].to_i

io_time = size * 2.0
compute_time = size * Math.sqrt(size) / ncores * 0.8

out = <<~OUT
  IO_TIME:#{format('%.2f', io_time)}
  COMPUTE_TIME:#{format('%.2f', compute_time)}
  TOTAL_TIME:#{format('%.2f', io_time + compute_time)}
OUT

puts out
