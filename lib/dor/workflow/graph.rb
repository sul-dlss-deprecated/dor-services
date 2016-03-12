require 'graphviz'

module Dor
module Workflow
class Graph

  FILL_COLORS = { 'waiting' => 'white', 'ready' => 'white', 'error' => '#8B0000', 'blocked' => 'white', 'completed' => 'darkgreen', 'unknown' => '#CFCFCF' }.freeze
  TEXT_COLORS = { 'waiting' => 'black', 'ready' => 'black', 'error' => 'white', 'blocked' => '#8B0000', 'completed' => 'white', 'unknown' => 'black' }.freeze
  PATTERNS    = { 'waiting' => 'diagonals', 'ready' => 'filled', 'error' => 'filled', 'blocked' => 'diagonals', 'completed' => 'filled', 'unknown' => 'filled' }.freeze
  RESERVED_KEYS = %w(repository name).freeze

  attr_reader :repo, :name, :processes, :graph, :root

  def self.from_config(name, config, parent = nil)
    wf = new(config['repository'], name, parent)
    config.keys.each { |p| wf.add_process(p.to_s) unless RESERVED_KEYS.include?(p) }
    config.keys.each { |p|
      next unless wf.processes[p]
      Array(config[p]['prerequisite']).each { |prereq|
        prereq.sub!(/^#{config['repository']}:#{name}:/e, '')
        if wf.processes[prereq]
          wf.processes[p].depends_on(wf.processes[prereq])
        else
          wf.processes[p].depends_on(wf.add_process(prereq).set_status('external'))
        end
      }
    }
    wf.finish
    wf
  end

  def self.from_processes(repo, name, processes, parent = nil)
    wf = new(repo, name, parent)
    processes.each { |p|
      wf.add_process(p.name).status = p.state || 'unknown'
    }
    processes.each { |p|
      p.prerequisite.each { |prereq|
        prereq.sub!(/^#{repo}:#{name}:/e, '')
        if wf.processes[prereq]
          wf.processes[p.name].depends_on(wf.processes[prereq])
        else
          wf.processes[p.name].depends_on(wf.add_process(prereq).set_status('external'))
        end
      }
    }
    wf.finish
    wf
  end

  def initialize(repo, name, parent = nil)
    @repo = repo
    @name = name
    if parent.nil?
      @graph = GraphViz.new(qname)
      @root = add_nodes(name)
    else
      @graph = parent.subgraph(qname)
      @root = parent.add_nodes(name)
    end
    @graph[:truecolor => true]
    @root.shape = 'plaintext'
    @processes = {}
  end

  def qname
    [@repo, @name].join(':')
  end

  def add_process(name, external = false)
    pqname = name.split(/:/).length == 3 ? name : [qname, name].join(':')
    p = Process.new(self, pqname, name)
    @processes[name] = p
    p
  end

  def finish
    @processes.values.each do |process|
      process.node.fontname = 'Helvetica'
      if process.id =~ %r{^#{qname}} && process.prerequisites.length == 0
        (@root << process.node)[:arrowhead => 'none', :arrowtail => 'none', :dir => 'both', :style => 'invisible']
      end
    end

    @root.fontname = 'Helvetica'
    self
  end

  def inspect
    "#{to_s[0..-2]} #{repo}:#{name} (#{processes.keys.join(', ')})>"
  end

  def method_missing(sym, *args)
    if @graph.respond_to?(sym)
      @graph.send(sym, *args)
    else
      super
    end
  end

  class Process

    attr_reader :name, :status, :node, :prerequisites

    def initialize(graph, id, name)
      @name = name
      @graph = graph
      @node = @graph.add_nodes(id)
      @node.shape = 'box'
      @node.label = name
      @prerequisites = []
      set_status('unknown')
    end

    def id
      @node.id
    end

    def status=(s)
      @status = s
      if s == 'external'
        @node.fillcolor = 'gray'
        @node.fontcolor = 'black'
        @node.style = 'dashed'
      else
        @node.fillcolor = FILL_COLORS[s] || 'yellow'
        @node.fontcolor = TEXT_COLORS[s]
        @node.style = PATTERNS[s]
      end
    end

    def set_status(s)
      self.status = s
      self
    end

    def depends_on(*processes)
      wf1 = id.split(/:/)[0..1].join(':')
      processes.each { |process|
        wf2 = process.id.split(/:/)[0..1].join(':')
        edge = (process.node << @node)
        edge.dir = 'both'
        edge.arrowhead = 'none'
        edge.arrowtail = 'none'
        edge.style = 'dashed' if (wf1 != wf2)
        prerequisites << process
      }
      self
    end

    def same_as(process)
      @node = process.node
    end

    def all_prerequisites
      prerequisites.collect { |p| p.all_prerequisites + [p.name] }.flatten.uniq
    end

  end

end
end
end
