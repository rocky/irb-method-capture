# Load or require this code to be able to save classes, methods, modules
# and functions you type in into arrays CLASSES, METHODS, and MODULES.
# This may be useful if say you want to experiment and then save the
# string later to a file.

# How to use.
# $ irb
# >> load 'irb-hack-tf.rb' 
# >> # work, work, work... look at CLASSES, METHODS and MODULES

unless defined?(RUBY_DESCRIPTION) && 
    RUBY_DESCRIPTION.start_with?('ruby 1.9.2frame')
  puts 'Whoah there. this code only works with a patched 1.9.2'
  puts 'See https://github.com/rocky/rb-threadframe/wiki'
  exit 10
end
require 'rubygems'
require 'irb'
require 'trace'  # My YARV-patched-specific trace filtering gem rb-trace

include Trace
CLASSES = {}
METHODS = {}
MODULES = {}
CHECK_METHODS = %w(define_method method_added singleton_method_added CLASS)

def capture_hook(event, frame, arg=nil)
  return unless CHECK_METHODS.member?(frame.method)

  klass = eval('self.to_s', frame.binding)
  lines = $irb_stmts.split(/\n/)
  return unless frame.source_container[0] == 'string' && 
    lines.size + $irb_firstline >= frame.source_location[0]
  loc = frame.source_location[0]

  first_line = lines[loc - $irb_firstline]
  puts "checking #{first_line}..." if $IRBHACK_DEBUG
  if 'class' == event 
    if first_line =~ /^\s*class\s+(\S+)/
      puts "adding #{klass}" if $IRBHACK_DEBUG
      CLASSES[klass] = $irb_stmts 
      return
    end
  elsif first_line =~ /^\s*def\s+([^(; \t\n]+)(:?[ \t\n(;])?/
    puts "adding #{klass}::#{$1}" if $IRBHACK_DEBUG
    METHODS["#{klass}::#{$1}"] = $irb_stmts 
  end

  MODULES[$1] = $irb_stmts if $irb_stmts =~ /^\s*module\s+(\S+)\s+/
end

# Monkeypatch to save the current IRB statement to be run.
# Possibly not needed.
class IRB::Context
  alias original_evaluate evaluate
  def evaluate(line, line_no)
    $irb_stmts = line
    $irb_firstline = line_no
    original_evaluate(line, line_no)
  end
end

workspace = IRB::WorkSpace.new(binding)
irb = IRB::Irb.new(workspace)
trace_filter = Trace::Filter.new
trace_filter.add_trace_func(method(:capture_hook).to_proc,
                            C_CALL_EVENT_MASK | CLASS_EVENT_MASK)
irb.eval_input
