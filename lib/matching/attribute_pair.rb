module Matching

  #Defines the comparison of two attributes, one from the "left" class
  #and one from the "right"
  class AttributePair
    attr_reader :left_attr, :right_attr, :weight, :is_fuzzy

    def initialize(left_attr, right_attr, weight, is_fuzzy = false)
      @left_attr = left_attr
      @right_attr = right_attr
      @weight = weight
      @is_fuzzy = is_fuzzy

      raise "Weight must be > 0.0" unless weight > 0.0
    end
  end
end
