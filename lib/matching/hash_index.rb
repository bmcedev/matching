module Matching
  class HashIndex

    attr_reader :hashes

    def initialize
      #one hash for each attribute
      @hashes = {}
    end

    # Add a value to the index for a given attribute and object id
    def put(attr, val, id)
      unless val.nil?
        h = @hashes[attr] || (@hashes[attr] = {})
        (h[val] ? h[val] << id : h[val] = [id])
      end
    end

    # Return an array of object ids for a given attribute and value
    def get(attr, val)
      (@hashes[attr] ? @hashes[attr][val] : nil)
    end

  end
end
