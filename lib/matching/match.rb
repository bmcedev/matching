module Matching

  #Defines a pair of objects that have been matched by the matcher
  class Match
    attr_reader :left_obj, :right_obj
    attr_accessor :score

    def initialize(left_obj, right_obj, score)
      @left_obj = left_obj
      @right_obj = right_obj
      @score = score
    end
  end
end
