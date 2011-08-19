require 'rdf/turtle/meta'
require 'rdf/ll1/parser'

module RDF::Turtle
  ##
  # A parser for the Turtle 2
  class Reader < RDF::Reader
    format Format
    include RDF::Turtle::Meta
    include RDF::LL1::Parser
    include RDF::Turtle::Tokens

    # Tokens passed to lexer. Order matters!
    terminal(:ANON,                 ANON) do |reader, prod, token, input|
      input[:resource] = reader.bnode
    end
    terminal(:BLANK_NODE_LABEL,     BLANK_NODE_LABEL) do |reader, prod, token, input|
      input[:resource] = reader.bnode(token.scanner[1])
    end
    terminal(:IRI_REF,              IRI_REF) do |reader, prod, token, input|
      input[:resource] = reader.process_iri(token.scanner[1])
    end
    terminal(:DOUBLE,               DOUBLE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.double)
    end
    terminal(:DOUBLE_NEGATIVE,      DOUBLE_NEGATIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.double)
    end
    terminal(:DOUBLE_POSITIVE,      DOUBLE_POSITIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.double)
    end
    terminal(:DECIMAL,              DECIMAL) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.decimal)
    end
    terminal(:DECIMAL_NEGATIVE,     DECIMAL_NEGATIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.decimal)
    end
    terminal(:DECIMAL_POSITIVE,     DECIMAL_POSITIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.decimal)
    end
    terminal(:INTEGER,              INTEGER) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.integer)
    end
    terminal(:INTEGER_NEGATIVE,     INTEGER_NEGATIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.integer)
    end
    terminal(:INTEGER_POSITIVE,     INTEGER_POSITIVE) do |reader, prod, token, input|
      input[:resource] = reader.literal(token.value, :datatype => RDF::XSD.integer)
    end
    terminal(:PNAME_LN,             PNAME_LN) do |reader, prod, token, input|
      prefix = token.scanner[1]
      suffix = token.scanner[2]
      raise RDF::ReaderError, "undefined prefix used in PNAME_LN #{token.value}" unless reader.prefix(prefix)
      input[:resource] = reader.ns(prefix, suffix)
    end
    terminal(:PNAME_NS,             PNAME_NS) do |reader, prod, token, input|
      input[:prefix] = token.scanner[1]
    end
    terminal(:STRING_LITERAL_LONG1, STRING_LITERAL_LONG1) do |reader, prod, token, input|
      input[:string_value] = token.scanner[1]
    end
    terminal(:STRING_LITERAL_LONG2, STRING_LITERAL_LONG2) do |reader, prod, token, input|
      input[:string_value] = token.scanner[1]
    end
    terminal(:STRING_LITERAL1,      STRING_LITERAL1) do |reader, prod, token, input|
      input[:string_value] = token.scanner[1]
    end
    terminal(:STRING_LITERAL2,      STRING_LITERAL2) do |reader, prod, token, input|
      input[:string_value] = token.scanner[1]
    end
    terminal(nil,                  %r([\(\),.;\[\]a]|\^\^|@base|@prefix|true|false)) do |reader, prod, token, input|
      case token.value
      when 'a'             then input[:resource] = RDF.type
      when 'true', 'false' then input[:resource] = RDF::Literal::Boolean.new(token.value)
      else                      input[:string] = token.value
      end
    end
    terminal(:LANGTAG,              LANGTAG)do |reader, prod, token, input|
      input[:lang] = token.scanner[1]
    end

    # Productions
    
    # [4] prefixID defines a prefix mapping
    production(:prefixID) do |reader, phase, input, current, callback|
      prefix = current[:prefix]
      iri = current[:resource]
      callback.call(:trace, "prefixID", "Defined prefix #{prefix} mapping to #{iri}")
      reader.namespace(prefix, iri)
    end
    
    # [5] base set base_uri
    production(:base) do |reader, phase, input, current, callback|
      iri = current[:resource]
      callback.call(:trace, "base", "Defined base as #{iri}")
      reader.options[:base_uri] = iri
    end
    
    # [9] verb ::= predicate | "a"
    production(:verb) do |reader, phase, input, current, callback|
      input[:predicate] = current[:resource] if phase == :finish
    end

    # [10] subject ::= IRIref | blank
    production(:subject) do |reader, phase, input, current, callback|
      input[:subject] = current[:resource] if phase == :finish
    end

    # [12] object ::= IRIref | blank | literal
    production(:object) do |reader, phase, input, current, callback|
      next unless phase == :finish
      if input[:object_list]
        input[:object_list] << current[:resource]
      else
        callback.call(:statement, "object", input[:subject], input[:predicate], current[:resource])
      end
    end

    # [15] blankNodePropertyList ::= "[" predicateObjectList "]"
    production(:blankNodePropertyList) do |reader, phase, input, current, callback|
      if phase == :start
        current[:subject] = reader.bnode
      else
        input[:object] = current[:subject]
      end
    end
    
    # [16] collection ::= "(" object* ")"
    production(:collection) do |reader, phase, input, current, callback|
      if phase == :start
        current[:object_list] = []  # Tells the object production to collect and not generate statements
      else
        # Create an RDF list
        objects = current[:object_list]

        last = objects.pop
        first_bnode = bnode = reader.bnode
        objects.each do |object|
          callback.call(:statement, "collection", first_bnode, RDF.first, object)
          rest_bnode = reader.bnode
          callback.call(:statement, "collection", first_bnode, RDF.rest, rest_bnode)
          first_bnode = rest_bnode
        end
        if last
          callback.call(:statement, "collection", first_bnode, RDF.first, last)
          callback.call(:statement, "collection", first_bnode, RDF.rest, RDF.nil)
        else
          bnode = RDF.nil
        end
        
        # Generate the triple for which the collection is an object
        callback.call(:statement, "collection", input[:subject], input[:predicate], bnode)
      end
    end
    
    # [60s] RDFLiteral ::= String ( LANGTAG | ( "^^" IRIref ) )? 
    production(:RDFLiteral) do |reader, phase, input, current, callback|
      next unless phase == :finish
      opts = {}
      opts[:datatype] = current[:iri] if current[:iri]
      opts[:language] = current[:lang] if current[:lang]
      input[:resource] = reader.literal(current[:string_value], opts)
    end

    ##
    # Missing in 0.3.2
    def base_uri
      @options[:base_uri]
    end

    ##
    # Initializes a new parser instance.
    #
    # @param  [String, #to_s]          input
    # @param  [Hash{Symbol => Object}] options
    # @option options [Hash]     :prefixes     (Hash.new)
    #   the prefix mappings to use (for acessing intermediate parser productions)
    # @option options [#to_s]    :base_uri     (nil)
    #   the base URI to use when resolving relative URIs (for acessing intermediate parser productions)
    # @option options [#to_s]    :anon_base     ("b0")
    #   Basis for generating anonymous Nodes
    # @option options [Boolean] :resolve_uris (false)
    #   Resolve prefix and relative IRIs, otherwise, when serializing the parsed SSE
    #   as S-Expressions, use the original prefixed and relative URIs along with `base` and `prefix`
    #   definitions.
    # @option options [Boolean]  :validate     (false)
    #   whether to validate the parsed statements and values
    # @option options [Boolean] :progress
    #   Show progress of parser productions
    # @option options [Boolean] :debug
    #   Detailed debug output
    # @return [RDF::Turtle::Reader]
    def initialize(input = nil, options = {}, &block)
      super do
        @options = {:anon_base => "b0", :validate => false}.merge(options)

        debug("def prefix", "#{base_uri.inspect}")
        namespace(nil, iri("#{base_uri}#"))

        debug("validate", "#{validate?.inspect}")
        debug("canonicalize", "#{canonicalize?.inspect}")
        debug("intern", "#{intern?.inspect}")

        if block_given?
          case block.arity
            when 0 then instance_eval(&block)
            else block.call(self)
          end
        end
      end
    end

    def inspect
      sprintf("#<%s:%#0x(%s)>", self.class.name, __id__, base_uri.to_s)
    end

    ##
    # Iterates the given block for each RDF statement in the input.
    #
    # @yield  [statement]
    # @yieldparam [RDF::Statement] statement
    # @return [void]
    def each_statement(&block)
      @callback = block

      parse(@input, START.to_sym, @options.merge(:branch => BRANCH)) do |context, *data|
        case context
        when :statement
          add_triple(*data)
        when :trace
          debug(*data)
        end
      end
    rescue RDF::LL1::Parser::Error => e
      raise RDF::ReaderError, e.message
    end
    
    ##
    # Iterates the given block for each RDF triple in the input.
    #
    # @yield  [subject, predicate, object]
    # @yieldparam [RDF::Resource] subject
    # @yieldparam [RDF::URI]      predicate
    # @yieldparam [RDF::Value]    object
    # @return [void]
    def each_triple(&block)
      each_statement do |statement|
        block.call(*statement.to_triple)
      end
    end

    # add a statement, object can be literal or URI or bnode
    #
    # @param [Nokogiri::XML::Node, any] node:: XML Node or string for showing context
    # @param [URI, Node] subject:: the subject of the statement
    # @param [URI] predicate:: the predicate of the statement
    # @param [URI, Node, Literal] object:: the object of the statement
    # @return [Statement]:: Added statement
    # @raise [RDF::ReaderError]:: Checks parameter types and raises if they are incorrect if parsing mode is _validate_.
    def add_triple(node, subject, predicate, object)
      statement = RDF::Statement.new(subject, predicate, object)
      debug(node, statement.to_s)
      @callback.call(statement)
    end

    def process_iri(iri)
      iri(base_uri, RDF::NTriples.unescape(iri))
    end

    # Create IRIs
    def iri(value, append = nil)
      value = RDF::URI.new(value)
      value = value.join(append) if append
      value.validate! if validate? && value.respond_to?(:validate)
      value.canonicalize! if canonicalize?
      value = RDF::URI.intern(value) if intern?
      value
    end

    # Create a literal
    def literal(value, options = {})
      options = options.dup
      options[:datatype] = RDF::XSD.string if options.empty?
      RDF::Literal.new(value, options.merge(:validate => validate?, :canonicalize => canonicalize?))
    end

    def namespace(prefix, iri)
      debug("namespace", "'#{prefix}' <#{iri}>")
      prefix(prefix, iri(iri))
    end
    
    def ns(prefix, suffix)
      base = prefix(prefix).to_s
      suffix = suffix.to_s.sub(/^\#/, "") if base.index("#")
      debug("ns", "base: '#{base}', suffix: '#{suffix}'")
      iri(base + suffix.to_s)
    end
    
    # Keep track of allocated BNodes
    def bnode(value = nil)
      @bnode_cache ||= {}
      @bnode_cache[value.to_s] ||= RDF::Node.new(value)
    end

    ##
    # Progress output when debugging
    # @param [String] str
    def debug(node, message, options = {})
      depth = options[:depth] || self.depth
      str = "[#{@lineno}]#{' ' * depth}#{node}: #{message}"
      @options[:debug] << str if @options[:debug].is_a?(Array)
      $stderr.puts(str) if RDF::Turtle.debug?
    end
  end # class Reader
end # module RDF::Turtle
