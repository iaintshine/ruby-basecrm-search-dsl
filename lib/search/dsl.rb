require "arel"

require "search/dsl/version"
require "search/dsl/visitor"

module Search
  module Dsl
    def to_search
      Search::Dsl::Visitor.new.accept @ast, {}
    end
  end
end

module Arel
  class TreeManager
    include Search::Dsl
  end
end