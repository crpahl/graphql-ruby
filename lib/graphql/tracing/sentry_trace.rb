# frozen_string_literal: true

module GraphQL
  module Tracing
    module SentryTrace
      include PlatformTrace

      {
        "lex" => "graphql.lex",
        "parse" => "graphql.parse",
        "validate" => "graphql.validate",
        "analyze_query" => "graphql.analyze",
        "analyze_multiplex" => "graphql.analyze_multiplex",
        "execute_multiplex" => "graphql.execute_multiplex",
        "execute_query" => "graphql.execute",
        "execute_query_lazy" => "graphql.execute"
      }.each do |trace_method, platform_key|
        module_eval <<-RUBY, __FILE__, __LINE__
        def #{trace_method}(**data)
          instrument_execution("#{platform_key}", "#{trace_method}", data) { super }
        end
        RUBY
      end

      def platform_execute_field(platform_key, &block)
        instrument_execution(platform_key, "execute_field", &block)
      end

      def platform_execute_field_lazy(platform_key, &block)
        instrument_execution(platform_key, "execute_field_lazy", &block)
      end

      def platform_authorized(platform_key, &block)
        instrument_execution(platform_key, "authorized", &block)
      end

      def platform_authorized_lazy(platform_key, &block)
        instrument_execution(platform_key, "authorized_lazy", &block)
      end

      def platform_resolve_type(platform_key, &block)
        instrument_execution(platform_key, "resolve_type", &block)
      end

      def platform_resolve_type_lazy(platform_key, &block)
        instrument_execution(platform_key, "resolve_type_lazy", &block)
      end

      def platform_field_key(field)
        "graphql.field.#{field.path}"
      end

      def platform_authorized_key(type)
        "graphql.authorized.#{type.graphql_name}"
      end

      def platform_resolve_type_key(type)
        "graphql.resolve_type.#{type.graphql_name}"
      end

      private

      def instrument_execution(platform_key, trace_method, data=nil, &block)
        return yield unless Sentry.initialized?

        Sentry.with_child_span(op: platform_key, start_timestamp: Sentry.utc_now.to_f) do |span|
          result = yield
          return result unless span

          span.finish
          if trace_method == "execute_multiplex" && data.key?(:multiplex)
            operation_names = data[:multiplex].queries.map{|q| operation_name(q) }
            span.set_description(operation_names.join(", "))
          elsif trace_method == "execute_query" && data.key?(:query)
            span.set_description(operation_name(data[:query]))
            span.set_data('graphql.document', data[:query].query_string)
            span.set_data('graphql.operation.name', data[:query].selected_operation_name) if data[:query].selected_operation_name
            span.set_data('graphql.operation.type', data[:query].selected_operation.operation_type)
          end

          result
        end
      end

      def operation_name(query)
        selected_op = query.selected_operation
        if selected_op
          [selected_op.operation_type, selected_op.name].compact.join(' ')
        else
          'GraphQL Operation'
        end
      end
    end
  end
end
