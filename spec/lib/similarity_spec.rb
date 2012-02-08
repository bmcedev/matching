require 'rspec'
require 'date'
require File.expand_path(File.dirname(__FILE__) + '/../../lib/matching.rb')
include Matching

describe Date do

  let(:a_date) { Date.new(2007,1,1) }

  it "requires days_scale parameter be numeric" do
    expect { a_date.similarity_to(Date.new(2007,1,15), :days_scale => 30) }.to_not raise_error
    expect { a_date.similarity_to(Date.new(2007,1,15), :days_scale => "thirty") }.to raise_error
  end

  it "scores date differences less than the days_scale as > 0.0 and < 1.0" do
    a_date.similarity_to(a_date).should == 1.0 
    a_date.similarity_to(Date.new(2007,1,15), :days_scale => 30).should be_within(0.05).of(0.5)
    a_date.similarity_to(Date.new(2007,1,2), :days_scale => 30).should be_within(0.05).of(1.0)
    a_date.similarity_to(Date.new(2007,1,30), :days_scale => 30).should be_within(0.05).of(0.0)
    a_date.similarity_to(Date.new(2007,2,1), :days_scale => 30).should == 0.0
    a_date.similarity_to(Date.new(2006,12,16), :days_scale => 30).should be_within(0.05).of(0.5)
    a_date.similarity_to(Date.new(2006,11,30), :days_scale => 30).should == 0.0
    a_date.similarity_to(Date.new(2006,11,30), :days_scale => 60).should be > 0.0
  end

  it "treats datetime as date" do
    dt1 = DateTime.new(2007,1,1)
    dt1.similarity_to(dt1).should == 1.0
    dt1.similarity_to(DateTime.new(2007,1,15)).should be > 0.0
  end

end

describe String do

  let(:a_string) { "Horse" }

  it "uses text gem to calculate Levenshtein distance between two strings" do
    Text::Levenshtein::distance(a_string,a_string).should == 0
    Text::Levenshtein::distance(a_string,"Hose").should == 1
    Text::Levenshtein::distance(a_string,"Hosse").should == 1
    Text::Levenshtein::distance(a_string,"Horsey").should == 1
    Text::Levenshtein::distance(a_string,"Hotel").should == 3
    Text::Levenshtein::distance(a_string,"horse").should == 1
    Text::Levenshtein::distance(a_string,"Apple").should == 4
  end

  it "scores raw similiarity between 0.0 and 1.0 using Levenshtein edit distance" do
    a_string.raw_similarity_to("Horse").should == 1.0
    a_string.raw_similarity_to("Hose").should be_within(0.1).of(0.75)
    a_string.raw_similarity_to("Trombone").should be_within(0.1).of(0.0)
  end

  it "performs case-insensitive raw similarity comparisons" do
    a_string.raw_similarity_to("hose").should be_within(0.1).of(0.75)
  end

  it "uses raw similarity to calculate overall similarity with no comparison argument" do
    a_string.similarity_to("Horsey").should be_within(0.1).of(0.75)
  end

  it "should tokenize strings according to rules" do
    "horse".tokenize.should == %w(horse)
    "horse ".tokenize.should == %w(horse)
    " horse".tokenize.should == %w(horse)
    " horse ".tokenize.should == %w(horse)
    "horse hoof".tokenize.should == %w(horse hoof)
    "horse m. hoof".tokenize.should == %w(horse hoof)
    "horse mildred hoof".tokenize.should == %w(horse mildred hoof)
    "horse .mildred - hoof".tokenize.should == %w(horse mildred hoof)
  end

  it "compares the similarity of names" do
    name1 = "Ruth Ginsburg"
    name1.similarity_to("Ruth Ginsburg", :comparison => :name).should == 1.0
    name1.similarity_to("Ginsburg Ruth", :comparison => :name).should == 1.0
    name1.similarity_to("Ginsburg, Ruth", :comparison => :name).should == 1.0
    name1.similarity_to("Ginsburg,Ruth", :comparison => :name).should == 1.0
    name1.similarity_to("Baby Ruth", :comparison => :name).should == 0.5
    name1.similarity_to("Ruth Ginsberg", :comparison => :name).should be_within(0.05).of(0.9)
    name1.similarity_to("Roth Ginsburg", :comparison => :name).should be_within(0.05).of(0.9)
    name1.similarity_to("Roth Ginsberg", :comparison => :name).should be_within(0.1).of(0.8)
    name1.similarity_to("Ruth Bader Ginsburg", :comparison => :name).should be > 0.5
    name1.similarity_to("Ruth Joan Bader Ginsburg", :comparison => :name).should be > 0.5
    name1.similarity_to("Antonin Scalia", :comparison => :name).should be_within(0.09).of(0.1)
  end

end
