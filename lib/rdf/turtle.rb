require 'rdf'

module RDF
  ##
  # **`RDF::Turtle`** is an Turtle plugin for RDF.rb.
  #
  # @example Requiring the `RDF::Turtle` module
  #   require 'rdf/turtle'
  #
  # @example Parsing RDF statements from an N3 file
  #   RDF::Turtle::Reader.open("etc/foaf.ttl") do |reader|
  #     reader.each_statement do |statement|
  #       puts statement.inspect
  #     end
  #   end
  #
  # @see http://rdf.rubyforge.org/
  # @see http://dvcs.w3.org/hg/rdf/raw-file/default/rdf-turtle/index.html
  #
  # @author [Gregg Kellogg](http://kellogg-assoc.com/)
  module Turtle
    require  'rdf/turtle/format'
    autoload :Lexer,   'rdf/turtle/lexer'
    autoload :Reader,  'rdf/turtle/reader'
    autoload :VERSION, 'rdf/turtle/version'
    autoload :Writer,  'rdf/turtle/writer'

    KEYWORDS  = %w(@base @prefix).map(&:to_sym)
  end
end
