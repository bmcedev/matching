require 'text/levenshtein'
require 'date'

# Adds fuzzy methods to standard classes for
# comparing two instances on a rules-based scale
# between 0.0 and 1.0.

class Date
  # Calculates a score between 0.0 and 1.0 for all dates within :days_scale
  # of each other.
  def similarity_to(other_date, opts={})
    days_scale = opts[:days_scale] || 30
    raise ArgumentError, 'days_scale must be numeric' unless days_scale.class == Fixnum
    days_scale = days_scale.to_f

    delta = (self - other_date).to_f.abs
    (delta < days_scale ? (days_scale - delta) / days_scale : 0.0)
  end
end

class String

  def similarity_to(other_string, opts={})
    case opts[:comparison] 
      when :name
        name_similarity_to(other_string)
      else 
        ## use just levenshtein edit distance (see levenshtein.rb)
        return raw_similarity_to(other_string)
    end
  end
  
  #Given a string, return one or more tokens parsed with the following rules:
  # 1. Turn commas into spaces
  # 2. Split on spaces
  # 3. Strip periods
  # 4. Discard any tokens with single letters
  def tokenize
    tokens = self.gsub(/\,/,' ').gsub(/\./,'').split(' ')
    tokens.reject! { |p| p.size == 1 }
    tokens
  end

  # Given two names, return a floating-point evaluation 
  # of similarity in the range 0.0 - 1.0
  def name_similarity_to(other_string)
    return 0.0 if self.nil? || other_string.nil? || self.size == 0 || other_string.size == 0
    return 1.0 if self == other_string

    l_tokens = self.tokenize
    r_tokens = other_string.tokenize

    total_sim = 0.0
    l_tokens.each do |l|
      r_tokens.each do |r|
        total_sim += l.raw_similarity_to(r)
      end
    end

    avg_tokens = (l_tokens.size + r_tokens.size).to_f / 2.0
    score = total_sim / avg_tokens
    (score > 1.0 ? 1.0 : score)
  end

  # Returns a floating point value of the similarity
  # between this string and other.
  # Uses 'text' gem, http://rubyforge.org/projects/text
  def raw_similarity_to(other)
    delta = Text::Levenshtein::distance(self.downcase, other.downcase)
    return 0.0 unless delta
    return 1.0 if delta == 0

    avg_len = (size + other.size).to_f / 2.0
    return 0.0 if delta > avg_len
    (avg_len - delta.to_f) / avg_len
  end
end

