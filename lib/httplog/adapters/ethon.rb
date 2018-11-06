# frozen_string_literal: true

if defined?(Ethon)
  module Ethon
    class Easy
      attr_accessor :action_name

      module Http
        alias orig_http_request http_request
        def http_request(url, action_name, options = {})
          @action_name = action_name # remember this for compact logging
          @options = options         # remember this for compact logging
          if HttpLog.url_approved?(url)
            HttpLog.log_request(action_name, url)
            HttpLog.log_headers(options[:headers])
            HttpLog.log_data(options[:body]) # if action_name == :post
          end

          orig_http_request(url, action_name, options)
        end
      end

      module Operations
        alias orig_perform perform
        def perform
          return orig_perform unless HttpLog.url_approved?(url)

          bm = Benchmark.realtime { orig_perform }

          # Not sure where the actual status code is stored - so let's
          # extract it from the response header.
          status   = response_headers.scan(%r{HTTP/... (\d{3})}).flatten.first
          encoding = response_headers.scan(/Content-Encoding: (\S+)/).flatten.first
          content_type = response_headers.scan(/Content-Type: (\S+(; charset=\S+)?)/).flatten.first

          # Hard to believe that Ethon wouldn't parse out the headers into
          # an array; probably overlooked it. Anyway, let's do it ourselves:
          headers = response_headers.split(/\r?\n/)[1..-1]

          HttpLog.log_compact(@action_name, @url, @return_code, bm)
          HttpLog.log_json(
            method: @action_name,
            url: @url,
            request_body: @options[:body],
            request_headers: @options[:headers],
            response_code: @return_code,
            response_body: response_body,
            response_headers: headers.map{ |header| header.split(/:\s/) }.to_h,
            benchmark: bm,
            encoding: encoding,
            content_type: content_type
          )
          HttpLog.log_status(status)
          HttpLog.log_benchmark(bm)
          HttpLog.log_headers(headers)
          HttpLog.log_body(response_body, encoding, content_type)
          return_code
        end
      end
    end
  end
end
