# How to use.
# $ irb
# >> load 'irb-hack-no-tf.rb' # Substitute file path. NOTE: 'load', not 'require'
# >> # work, work, work... look at CLASSES, METHODS and MODULES
require 'irb'

$IRBHACK_DEBUG = true
# irb-hack.rb without threadframe and trace modules. However since
# there is still a bug in the way Ruby handles c-call events (it calls the
# hook before pushing the the frame), this doesn't catch "define-method"
# calls properly.
CLASSES = {}
METHODS = {}
MODULES = {}
CHECK_METHODS = %w(define_method method_added singleton_method_added CLASS)

def capture_hook(event, file, line, id, binding, classname)
  return unless CHECK_METHODS.member?(id.to_s)

  # Work around what is probably a bug in the way classname
  # is set inside the Ruby 1.9 callback hook.
  klass = eval('self.to_s', binding)  

  p [event, file, id, klass, classname] if $IRBHACK_DEBUG

  lines = $irb_stmts.split(/\n/)
  return unless lines.size + $irb_firstline >= line
  loc = line

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
set_trace_func(method(:capture_hook).to_proc)
irb.eval_input
