# unit tests for the hirsute language

require 'test/unit'
require 'lib/hirsute_utils.rb'
require 'lib/hirsute.rb'
require 'lib/hirsute_make_generators.rb'
require 'lib/hirsute_collection.rb'

class TestHirsute < Test::Unit::TestCase
  include Hirsute::GeneratorMakers
  include Hirsute::Support
  
  # test functionality of the histogram distribution
  def testIntegerFromHistogram1
    
    # define a very skewed histogram
    histogram_a = [0.9,0.05,0.05]
    values_a = Array.new(histogram_a.length,0)
    
    (1..1000).each do |i|
      index = integer_from_histogram(histogram_a)
      values_a[index] = values_a[index] + 1
    end
    
    # check for 5% tolerance
    assert(values_a[0] > 855 && values_a[0] < 945)
    
  end
  
  def testHistogramGreaterThanList
    begin
      random_item_with_histogram([1,2],[1,2,3,4])
      fail
    rescue Exception => e
      assert(true)
    end
  end
  
  def testHistogramDoesntEqualOne
    histogram = [0.2,0.1]
    values = Array.new
    
    (1..1000).each do |i|
      values << random_item_with_histogram([1,2],histogram)
    end
    
    one_values = values.select {|item| item == 1}
    two_values = values.select {|item| item == 2}
    
    assert(one_values.length > 667 * 0.95 && one_values.length < 667 * 1.05)
    assert(two_values.length > 333 * 0.95 && two_values.length < 333 * 1.05)
  end
  
  def testOneOfWithHistogram
    results = []
    list = ["a","b","c"]
    histogram = [0.9,0.05,0.05]
    gen = one_of(list,histogram)
    (1..1000).each do |i|
      results << gen.generate(nil)
    end
    
    a_count = (results.select {|item| item == 'a'}).length
    assert(a_count > 855 && a_count < 945)
  end
  
  def testGeneratorBlockRunWithinInstance
     template = make_template("testGeneratorBlockRunWithinInstance") {
        has :id => counter(3),
            :triple => depending_on(:id,
                                    Hirsute::DEFAULT => "") {|result| id * 3}
     }
     obj = template.make
     assert(obj.triple == (obj.id * 3))
  end
  
  
  def testOneOfGenerator
    
    domains = ["gmail.com","yahoo.com","ea.com"]
    domain = one_of(domains).generate(nil)
    assert(domain == 'gmail.com' || domain == 'yahoo.com' || domain = 'ea.com')
  end
  
  def testFileRead
    gen = read_from_file('tests/first_names.txt',:linear)
    line = gen.generate(nil)
    assert(line == 'Derrick')
    
    # toss the rest
    (1..7).each do |i|
      line = gen.generate(nil)
    end
    
    line = gen.generate(nil) # should have wrapped around
    assert(line == 'Derrick')
  end
  
  def testCollectionCreationWithObject
    coll = Hirsute::Collection.new("String")
    begin
      coll << 3
      flunk "Collection should not allow an inconsistent type"
    rescue Exception => e
      assert(coll.length == 0)
    end
  end
  
  def testCollectionCreationWithoutObject
    coll = Hirsute::Collection.new('fixnum')
    coll << 3
    begin
      coll << "test"
      flunk "Strings should not be allowed in a collection created as an integer"
    rescue
      assert(coll.length == 1)
    end
  end
  
  def testCollectionChoice
    coll = Hirsute::Collection.new("String")
    coll << "a"
    coll << "b"
    coll << "c"
    
    str = one_of(coll).generate(nil)
    assert(str=='a' || str == 'b' || str == 'c')
  end
  
  def testPostGenerateBlockExecution
    list = ['abc','apple','asparagus']
    gen = one_of(list) {|value| value[0,1]}
    result = gen.generate(nil)
    assert(result == 'a')
  end
  
  # ensure that when you create a collection for an object, that it registers itself as a holder of that object type
  def testCollectionsRegisterForObject
    objName = 'testObj'
    
    #setup, copied from hirsute.rb
    objClass = Class.new(Hirsute::Fixed)
    objClassName = Kernel.const_set(objName.capitalize.to_sym,objClass)
    
    template = Hirsute::Template.new(objName)
    
    coll1 = template * 2
    coll2 = template * 3
    all_colls = Hirsute::Collection.collections_holding_object(objName)
    assert(all_colls.length == 2)
  end
  
  # tests that is_template works
  def testIsTemplate
    testObj2 = Hirsute::Template.new('testObj2') 
    assert(is_template(testObj2))    
  end
  
  def testCollectionRejectsDifferentObject
    template1 = make_template('testCollectionRejectsDifferentObject1')
    template2 = make_template('testCollectionRejectsDifferentObject2')
    
    coll1 = template1 * 2
    
    begin
       coll1 << template2
       assert(false)
    rescue
       assert(true)
    end
  end
  
  def testMakeAddsToSingleCollection
    template = make_template('testMakeAddsToSingleCollection')
    coll = collection_of template
    template.make
    assert(coll.length == 1)
  end

  
  # ensure that the << operator works properly when appending a template (i.e., it makes a new object rather than appending the template)
  def testAppendWithTemplate
    testObj3 = make_template('testObj3') {
       has :id => counter(1)
    }
     
    coll = testObj3 * 1
    coll << testObj3
    
    # either line would have raised an exception if the collection thought it was an invalid type (see test above)
    assert(true)
  end
  
  def testNestedGenerators
    template = make_template('testNestedGenerators') {
      has :id => one_of([one_of([1,2,3]),one_of([4,5,6])])
    }
    obj = template.make
    assert(obj.id == 1 || obj.id == 2 || obj.id == 3 || obj.id == 4 || obj.id == 5 || obj.id == 6)
  end  
  
  def testSubset
    template = make_template('testSubset') {
        has :item => subset(one_of([1,2,3]),
                            one_of(['a','b','c']),
                            one_of([4,5,6]))
    }
    obj = template.make
    assert(obj.item.length <= 3 && obj.item.length > 0)
  end
  
  def testAppendCollectionToCollection
    template = make_template('testAppendCollectionToCollection')
    coll1 = template * 3
    coll2 = template * 4
    coll1 << coll2
    assert(coll1.length == 7)
  end
  
  def testAnyObject
    template = make_template('testAnyObject') {
      has :objid => counter(1)
    }
    coll1 = template * 3
    coll2 = template * 4
    greaterThan5 = any(template) {|item| item.objid > 5}
    assert(greaterThan5.objid > 5)
    
    equals2 = any(template) do |item|
      item.objid == 2
    end
    assert(equals2.objid == 2)
  end
  
  def testReadFromSequence
    template = make_template('testReadFromSequence') {
       has :looper => read_from_sequence([1,2,3,4])
    }
    
    # 5 objects should exercise the loop of 4 items
    template1 = template.make
    template2 = template.make
    template3 = template.make
    template4 = template.make
    template5 = template.make
    
    assert(template4.looper == 4)
    assert(template5.looper == template1.looper)
      
  end 
  
  def testDependentGeneratorCircularDependencyException
    template = make_template("testDependentGeneratorCircularDependencyException") {
      has :a => depending_on(:b, 3 => 3),
          :b => depending_on(:a, 4 => 4)
    }
    begin
      template.make
      fail
    rescue
      assert(true)
    end
  end
  
  def testDependencyBasics
    template = make_template("testDependencyBasics") {
      has :value => read_from_sequence([1,2,3]),
          :name => depending_on(:value,
                                1 => 'a')
    }
    template1 = template.make
    template2 = template.make
    assert(template1.name == 'a')
    assert(template2.name.nil?)
  end  
    
  def testDependencyBasicsWithDefault
    template = make_template("testDependencyBasicsWithDefault") {
      has :value => read_from_sequence([1,2,3]),
          :name => depending_on(:value, 
                                    1 => 'a',
                                    Hirsute::DEFAULT => 'z')
    }
    
    template1 = template.make
    template2 = template.make
    template3 = template.make
    
    assert(template1.value == 1 && template1.name == 'a')
    assert(template2.value == 2 && template2.name == 'z')
    assert(template3.value == 3 && template3.name == 'z')
  end
  
  def testRequiresField
    template = make_template("testRequiresField") {
      has :value => requires_field(:literal,counter(20)) {|value| self.literal = value},
          :literal => 1
    }
    
    template1 = template.make
    assert(template1.literal == template1.value)
  end
  
  def testRangeArrayCaching
    range1 = 1..3
    range2 = 1..3 # ensure that the same conceptual range maps to the same array
    
    range3 = 1..4
    
    ary = Hirsute::Support.get_range_array(range1)
    ary2 = Hirsute::Support.get_range_array(range2)
    ary3 = Hirsute::Support.get_range_array(range2)
    ary4 = Hirsute::Support.get_range_array(range3)
    assert(ary.equal?(ary2))
    assert(ary.equal?(ary3))
    assert(!ary.equal?(ary4))
  end
  
  def testRangeResultsBecomeElements
    template = make_template("testRangeResultsBecomeElements") {
      has :rating => one_of([1..10])
    }
    obj = template.make
    assert(obj.rating >= 1 && obj.rating <= 10)
  end
  
  # just to measure that range caching is worth it
  def testRangeCachingSpeed
    iterations = 100000
    range = 1..10
    
    start = Time.new
    (1..iterations).each {|i| range.to_a}
    
    avg_to_a_time = (Time.new - start).to_f / iterations
    
    start = Time.new
    (1..iterations).each {|i| Hirsute::Support.get_range_array(range)}
    avg_cached_time = (Time.new - start).to_f / iterations
    
    assert(avg_cached_time < avg_to_a_time)
    
  end
  
  # for testing outputter behavior.
  class TestOutputter < Hirsute::Outputter
    def _outputItem(item)
    end
  end
  
  def testFieldsInOutputter
    # build up the collection
    template = make_template("testFieldsInOutputter") {
       has :id => counter(1)
    }
    collection = template * 4
    
    outputter = TestOutputter.new(collection)
    assert(outputter.fields[0] == :id)
  end
  
end