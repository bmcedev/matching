module Matching

  #Stores and retrieves data from arrays for Matcher
  class ArrayStore

    attr_reader :arr

    def initialize(arr)
      @arr = arr
    end

    #Iterates over array, also returning index as a kind of ID
    def each(&blk)
      @arr.each_with_index(&blk)
    end

    #Return an object from the array by its index position
    def find(idx)
      @arr[idx]
    end

  end
end
