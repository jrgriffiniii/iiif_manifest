require 'loofah'

module IIIFManifest
  module Scrubbers
    class EscapeAll < ::Loofah::Scrubber
      def initialize
        @direction = :top_down
      end

      def scrub(node)
        return CONTINUE if sanitize_all(node) == CONTINUE
        node.add_next_sibling Nokogiri::XML::Text.new(node.to_s, node.document)
        node.remove
        return STOP
      end

      private

        def sanitize_all(node)
          case node.type
          when Nokogiri::XML::Node::ELEMENT_NODE
          when Nokogiri::XML::Node::TEXT_NODE, Nokogiri::XML::Node::CDATA_SECTION_NODE
            return ::Loofah::Scrubber::CONTINUE
          end
          ::Loofah::Scrubber::STOP
        end
    end
  end
end
