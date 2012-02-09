module Matching

  class Matcher
    attr_accessor :min_score
    attr_reader :left_store, :right_store
    attr_reader :join_pairs, :compare_pairs, :custom_functions, :filter_functions
    attr_reader :left_matches, :right_matches
    attr_reader :right_index

    def self.define(opts=nil, &block)
      m = new(opts)
      m.define(block)
      m
    end

    def initialize(opts={})
      @left_store = opts[:left_store]
      @right_store = opts[:right_store]
      @min_score = opts[:min_score] || 1.0

      @join_pairs = []
      @compare_pairs = []
      @custom_functions = []
      @filter_functions = []
      @right_matches = {} #hash keyed on right_class records, used during main rec loop
      @left_matches = {} #hash keyed on left_class records, created after main rec loop from reverse of @right_matches
      @left_losers = [] #array of left objects that were matched to right records then unmatched, requiring re-match attempt

      # Create @right_index using either a hash or Redis as the backing store
      if opts[:redis_db] && opts[:redis_db].to_i >= 1
        @right_index = RedisIndex.new(opts[:redis_db])
      else
        @right_index = HashIndex.new
      end
    end

    # Compare left and right arguments and return similarity as a floating point
    # value where 0.0 represents no similarity and 1.0 represents equality.
    def compare_values(left,right,opts={})
      return 0.0 unless left && right

      raise ArgumentError, "Cannot compare values of dissimilar type - left = #{left}, right = #{right}" unless left.class == right.class

      if opts[:fuzzy]
        raise ArgumentError, "Cannot calculate fuzzy comparison for type #{left.class}" unless left.respond_to?(:similarity_to)
        left.similarity_to(right,opts)
      else
        (left == right ? 1.0 : 0.0)
      end
    end

    def define(&block)
      instance_eval(&block)
    end

    # One or more join attributes are required for a match between two records
    # to occur. Attributes must be equal.
    def join(left_attr, right_attr, weight)
      @join_pairs << AttributePair.new(left_attr, right_attr, weight)
    end

    # For records matched via join attributes, comparisons may be applied to
    # adjust the score.
    def compare(left_attr, right_attr, weight, is_fuzzy = false)
      @compare_pairs << AttributePair.new(left_attr, right_attr, weight, is_fuzzy)
    end

    # Custom functions may adjust the score beyond the simple comparisons
    # performed via @compare_pairs.
    def custom(lmbda)
      @custom_functions << lmbda
    end

    # Filter lambdas must return a boolean. Returning true will prevent a match.
    def filter(lmbda)
      @filter_functions << lmbda
    end

    # Given join, compare, and custom rules, return the floating point
    # matching score of two objects.
    def score_pair(left_obj, right_obj)
      score = 0

      @join_pairs.each do |pair|
        score += pair.weight * compare_values(left_obj.send(pair.left_attr), right_obj.send(pair.right_attr))
      end

      @compare_pairs.each do |pair|
        score += pair.weight * compare_values(left_obj.send(pair.left_attr), right_obj.send(pair.right_attr), pair.is_fuzzy)
      end

      @custom_functions.each do |lmbda|
        score += lmbda.call(left_obj, right_obj)
      end

      @filter_functions.each do |lmbda|
        score = 0 unless lmbda.call(left_obj, right_obj)
      end

      score
    end

    # Perform matching
    def match
      unless @left_store && @right_store
        raise ArgumentError, "Matcher requires left_store and right_store attributes"
      end

      # Index right objects to speed search
      index_right_objects

      # Evaluate each left record for matches.
      # If more than one match is found, the best-possible match
      # will be awarded the match unless another object is already
      # matched to it. Conflicts are resolved in a separate method.
      @left_store.each do |left_obj|

        yield left_obj if block_given?

        # Results are pre-sorted with the best matches first
        ranked_matches = find_matches(left_obj)

        # Attempt to pair the left_object with one of the 
        # ranked right matches
        pair_matches(left_obj, ranked_matches)
      end #each left_obj

      # Call the recursive method evaluate_left_losers which will attempt to
      # find new matches
      evaluate_left_losers

      # Populate left_matches as the mirror of right_matches
      @right_matches.each { |right_obj, match| @left_matches[match.left_obj] = match }
    end

    # Indexes attribues from right object in @right_index (either hash or Redis, see
    # initialize). For each join_pair, store the attribute's values in the form:
    #  attr:val -> [array_of_ids]
    def index_right_objects

      # Require at least one exact_pair else would execute in quadratic time
      raise 'Matcher requires at least one join pair to be defined' unless @join_pairs.any?

      @right_store.each do |right_obj, id|
        @join_pairs.each { |jp| @right_index.put(jp.right_attr, right_obj.send(jp.right_attr), id) }
      end
    end

    # Return of scored matches for the left_object argument.
    # Results are in an ordered array of form [[right_obj_a, score_a], [right_obj_b, score_b], ...]
    def find_matches(left_obj)
      potential_matches = find_potential_matches(left_obj)
      ranked_pairs = []

      potential_matches.each do |right_obj|
        score = score_pair(left_obj, right_obj)
        ranked_pairs << [right_obj, score] if score >= @min_score
      end

      ranked_pairs.sort! { |a,b| a[1] <=> b[1] }
      ranked_pairs.reverse
    end

    # Return an array of right_objects that match the left_object by
    # join criteria. This is equivalent to an index lookup. No scoring
    # is done by this method.
    def find_potential_matches(left_obj)
      right_objects = []

      @join_pairs.each do |jp|
        left_val = left_obj.send(jp.left_attr)
        next if left_val.nil? || left_val == ''

        matches = @right_index.get(jp.right_attr, left_val)
        right_objects = right_objects | matches if matches
      end

      # At this point right_objects contains an array of right object ID's.
      # Retrieve the matching objects now.
      right_objects.map! { |r_id| @right_store.find(r_id) }
    end

    # Evaluate and possibly create Match objects to join the
    # left_object to one of the right_objects from the
    # ranked_matches array
    def pair_matches(left_obj, ranked_matches)

      ranked_matches.each do |pair|
        (right_obj, score) = pair

        if @right_matches[right_obj]
          # A match already exists. Determine which left_obj is the best fit.
          if score > @right_matches[right_obj].score
            # The current left_obj is a better fit.
            # Record the other left_obj as a loser then switch
            # the match for the right_obj.
            @left_losers << @right_matches[right_obj].left_obj
            @right_matches[right_obj] = Match.new(left_obj, right_obj, score)
            break
          else
            # Continue looping to try to find a better match
          end
        else
          # Assign first match for this right_obj
          @right_matches[right_obj] = Match.new(left_obj, right_obj, score)
          break
        end
      end
    end

    # Attempt to find matches while any left losers remain
    def evaluate_left_losers
      return unless @left_losers.any?

      # Use a copy of the array because it may be filled again as
      # find_matches is called
      working_losers = @left_losers
      @left_losers = []
      working_losers.each do |left_obj| 
        ranked_matches = find_matches(left_obj)
        pair_matches(left_obj, ranked_matches)
      end

      # To understand recursion you first must understand recursion
      evaluate_left_losers
    end

    # Returns array of non-matched left objects
    def left_exceptions
      return @left_exceptions if @left_exceptions
      @left_exceptions = exceptions(:left)
      @left_exceptions
    end

    # Returns array of non-matched right objects
    def right_exceptions
      return @right_exceptions if @right_exceptions
      @right_exceptions = exceptions(:right)
      @right_exceptions
    end

    def exceptions(side)
      if side == :left 
        store, matches = @left_store, @left_matches
      else 
        store, matches = @right_store, @right_matches
      end

      arr = []
      if arr.class == ArrayStore
        arr = store.arr - matches
      else
        store.each do |obj|
          arr << obj unless matches[obj]
        end
      end
      arr
    end

    def matches
      @left_matches.map do |left_obj, match|
        match
      end 
    end
  end #class
end #module
