module Search
  module Dsl
    class Visitor < Arel::Visitors::Reduce
      def compile(node)
        accept(node, {})
      end

      private


      def visit_Arel_Nodes_Casted o, collector
        o.val
      end

      def visit_Arel_Nodes_Quoted o, collector
        collector << quoted(o.expr, nil).to_s
      end

      def visit_Arel_Nodes_True o, collector
        true
      end

      def visit_Arel_Nodes_False o, collector
        false
      end

      def visit_Arel_Nodes_Grouping o, collector
        visit(o.expr, collector)
      end

      def visit_Arel_SelectManager(o, collector)
        visit(o.ast, collector)
      end

      def visit_Arel_Nodes_SelectStatement(o, collector)
        collector = o.cores.inject(collector) { |c,x|
          visit_Arel_Nodes_SelectCore(x, c)
        }

        unless o.orders.empty?
          orders = o.orders.map { |x, i|
            visit(x, collector)
          }
          collector[:query][:sort] = orders
        end

        visit_Arel_Nodes_SelectOptions(o, collector)

        collector
      end


      def visit_Arel_Nodes_SelectOptions o, collector
        collector = maybe_visit o.limit, collector
        collector = maybe_visit o.offset, collector
      end

      def visit_Arel_Nodes_Offset o, collector
        collector[:offset] = visit o.expr, collector
        collector
      end

      def visit_Arel_Nodes_Limit o, collector
        collector[:per_page] = visit o.expr, collector
        collector
      end

      def visit_Arel_Nodes_SelectCore(o, collector)
        # collector << "SELECT"
        #
        # collector = maybe_visit o.top, collector
        #
        # collector = maybe_visit o.set_quantifier, collector

        query = {}

        unless o.projections.empty?
          projections = o.projections.map do |x|
            attribute(visit(x, collector))
          end
          query[:projection] = projections
        end

        unless o.wheres.empty?
          filters = if o.wheres.size == 1
                      {filter: visit(o.wheres.first, collector)}
                    else
                      {and: o.wheres.map {|x| visit(x, collector)}}
                    end
          query[:filter] = filters
        end

        #
        # unless o.groups.empty?
        #   collector << GROUP_BY
        #   len = o.groups.length - 1
        #   o.groups.each_with_index do |x, i|
        #     collector = visit(x, collector)
        #     collector << COMMA unless len == i
        #   end
        # end
        #
        # collector = maybe_visit o.having, collector
        #
        # unless o.windows.empty?
        #   collector << WINDOW
        #   len = o.windows.length - 1
        #   o.windows.each_with_index do |x, i|
        #     collector = visit(x, collector)
        #     collector << COMMA unless len == i
        #   end
        # end

        collector[:query] = query
        collector
      end

      def maybe_visit thing, collector
        return collector unless thing
        visit thing, collector
      end

      def attribute(name)
        { name: name }
      end

      def sort(name, order = :ascending)
        {
          attribute: attribute(name),
          order: order
        }
      end

      def filter(name, parameter)
        {
            filter: {
                attribute: attribute(name),
                parameter: parameter
            }
        }
      end

      def not_filter(filter)
        { not: filter }
      end

      def visit_Arel_Attributes_Attribute(o, collector)
        o.name
      end

      alias :visit_Arel_Attributes_Integer :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Float :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Decimal :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_String :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Time :visit_Arel_Attributes_Attribute
      alias :visit_Arel_Attributes_Boolean :visit_Arel_Attributes_Attribute

      def literal(o, _)
        o.to_s
      end

      def identity(o, _)
        o
      end

      alias :visit_Bignum                :identity
      alias :visit_Fixnum                :identity
      alias :visit_Arel_Nodes_SqlLiteral :literal

      def visit_Arel_Nodes_Equality(o, collector)
        left = visit(o.left, collector)
        right = o.right

        if right.nil?
          filter(left, is_null: true)
        else
          filter(left, eq: visit(o.right, collector))
        end
      end

      def visit_Arel_Nodes_NotEqual(o, collector)
        left = visit(o.left, collector)
        right = o.right

        if right.nil?
          filter(left, is_null: false)
        else
          not_filter(filter(left, eq: visit(o.right, collector)))
        end
      end

      def visit_Arel_Nodes_And o, collector
        { and: [visit(o.left, collector), visit(o.right, collector)] }
      end

      def visit_Arel_Nodes_Or o, collector
        { or: [visit(o.left, collector), visit(o.right, collector)] }
     end

      def visit_Arel_Nodes_Ascending o, collector
        sort(visit(o.expr, collector), :ascending)
      end

      def visit_Arel_Nodes_Descending o, collector
        sort(visit(o.expr, collector), :descending)
      end
    end
  end
end