# frozen_string_literal: true

if defined?(Patron)
  module Patron
    class Session
      alias orig_request request
      def request(action_name, url, headers, options = {})
        log_enabled = HttpLog.url_approved?(url)

        if log_enabled
          HttpLog.log_request(action_name, url)
          HttpLog.log_headers(headers)
          HttpLog.log_data(options[:data]) # if action_name == :post
        end

        bm = Benchmark.realtime do
          @response = orig_request(action_name, url, headers, options)
        end

        if log_enabled
          headers = @response.headers
          HttpLog.log_compact(action_name, url, @response.status, bm)
          HttpLog.log_json(
            method: action_name,
            url: url,
            request_body: options[:data],
            request_headers: headers,
            response_code: @response.status,
            response_body: @response.body,
            response_headers: headers,
            benchmark: bm
          )
          HttpLog.log_status(@response.status)
          HttpLog.log_benchmark(bm)
          HttpLog.log_headers(headers)
          HttpLog.log_body(@response.body, headers['Content-Encoding'], headers['Content-Type'])
        end

        @response
      end
    end
  end
end
