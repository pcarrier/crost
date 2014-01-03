HASH_CHUNK_SIZE = 65536
UINT64_MAX = 2**64 - 1

# opensubtitles.org hashing, easy peasy
def hashFile(file)
  # beginning of file
  file.seek(0, IO::SEEK_SET)
  buffer = file.sysread(HASH_CHUNK_SIZE)
  file.seek(-HASH_CHUNK_SIZE, IO::SEEK_END)
  buffer << file.sysread(HASH_CHUNK_SIZE)

  bufsize = buffer.size
  if bufsize != 2 * HASH_CHUNK_SIZE
    raise "Only read #{bufsize} bytes"
  end

  buffhash = buffer.unpack('Q*').reduce do |acc, v|
    (acc + v) & UINT64_MAX
  end

  return (file.pos + buffhash) & UINT64_MAX
end

puts '%x' % hashFile(File.open ARGV[0])
