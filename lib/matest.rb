require "matest/version"

module Matest
  class Runner
    attr_reader :example_groups

    def initialize
      @example_groups = []
    end

    def <<(example_group)
      example_groups << example_group
    end

    def load_file(file)
      load(file)
    end

    def execute!
      example_groups.each do |current_group|
        current_group.execute!
      end
    end
  end

  class SpecStatus
    attr_reader :block
    attr_reader :description
    attr_reader :result
    
    def initialize(block, result, description=nil)
      @block = block
      @result = result
      @description = description
    end

    def location
      "%s:%d" % block.source_location
    end

  end

  class SpecPassed < SpecStatus
    def to_s
      "."
    end

    def name
      "PASSING"
    end
  end
  class SpecFailed < SpecStatus
    def to_s
      "F"
    end

    def name
      "FAILING"
    end
  end
  class SpecSkipped < SpecStatus
    def to_s
      "S"
    end

    def name
      "SKIPPED"
    end
  end
  class NotANaturalAssertion < SpecStatus
    def to_s
      "N"
    end

    def name
      "NOT A NATURAL ASSERTION"
    end
  end

  class ExceptionRaised < SpecStatus
    attr_reader :exception
    def to_s
      "E"
    end

    def name
      "ERROR"
    end
  end

  class SkipMe; end

  class ExampleGroup
    attr_reader :scope_block
    attr_reader :specs
    attr_reader :statuses

    def initialize(scope_block)
      @scope_block = scope_block
      @specs       = []
      @statuses    = []
    end

    def execute!
      instance_eval(&scope_block)
      specs.each do |spec, desc|
        res = run_spec(spec, desc)
        print res
      end

      puts
      puts
      puts "### Messages ###"
      statuses.each do |status|
        unless status.is_a? Matest::SpecPassed
          puts
          puts "[#{status.name}] #{status.description}"
          if status.is_a?(Matest::NotANaturalAssertion)
            puts "RESULT >> #{status.result.inspect}"
          end
          if status.is_a?(Matest::ExceptionRaised)
            puts "EXCEPTION >> #{status.result}"
            status.result.backtrace.each do |l|
              puts "  #{l}"
            end
            
          end
          puts "  #{status.location}"
        end
      end
    end

    def spec(description=nil, &block)
      current_example = block_given? ? block : -> { Matest::SkipMe.new }
      specs << [current_example, description]
    end

    def xspec(description=nil, &block)
      spec(description)
    end

    [:it, :spec, :test, :example].each do |m|
      alias m :spec
      alias :"x#{m}" :xspec
    end

    def run_spec(spec, description)
      status = begin
                 result = spec.call
                 status_class = case result
                                when true
                                  Matest::SpecPassed
                                when false
                                  Matest::SpecFailed
                                when Matest::SkipMe
                                  Matest::SpecSkipped
                                else
                                  Matest::NotANaturalAssertion
                                end
                 status_class.new(spec, result, description)
               rescue Exception => e
                 Matest::ExceptionRaised.new(spec, e, description)
               end
      statuses << status
      status
    end

  end
end


def scope(description=nil, &block)

  Matest::ExampleGroup.new(block).execute!
end
