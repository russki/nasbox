Facter.add('drives') do
	setcode do
		drives = []
		lines = File.open('/proc/partitions')
		lines.each do |line|
			if line.chomp =~ /.*\d*.*\d*.*\d*.*(sd\D+|hd\D+|cciss\/c\d+d\d+)$/
				drives.push($1)
			end
		end
		drives.join(',')
	end
end

Facter.add('partitions') do
	setcode do
		partitions = []
		lines = File.open('/proc/partitions')
		lines.each do |line|
			if line.chomp =~ /.*\d*.*\d*.*\d*.*(sd\D+\d+|hd\D+\d+|cciss\/c\d+d\d+p\d+)$/
				partitions.push($1)
			end
		end
		partitions.join(',')
	end
end

