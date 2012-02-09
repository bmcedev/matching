files = %w(
  attribute_pair 
  array_store 
  similarity
  hash_index 
  match 
  matcher
  deduplicator
)

files.each { |f| require File.expand_path(File.dirname(__FILE__) + "/matching/#{f}.rb") }
