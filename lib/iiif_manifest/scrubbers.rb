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
        STOP
      end

      private

        def sanitize_all(node)
          if node.type == Nokogiri::XML::Node::TEXT_NODE || node.type == Nokogiri::XML::Node::CDATA_SECTION_NODE
            CONTINUE
          else
            STOP
          end
        end
    end
  end
end
