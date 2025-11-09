# frozen_string_literal: true

module Libcall
  # Handles reading output parameters after FFI calls
  class OutputReader
    def initialize(out_refs)
      @out_refs = out_refs
    end

    def read
      @out_refs.map do |ref|
        case ref[:kind]
        when :out
          read_single_output(ref)
        when :out_array
          read_array_output(ref)
        else
          raise Error, "Unknown out reference kind: #{ref[:kind]}"
        end
      end
    end

    def empty?
      @out_refs.empty?
    end

    private

    def read_single_output(ref)
      value = TypeMap.read_output_pointer(ref[:ptr], ref[:type])
      { index: ref[:index], type: ref[:type].to_s, value: value }
    end

    def read_array_output(ref)
      values = TypeMap.read_array(ref[:ptr], ref[:base], ref[:count])
      {
        index: ref[:index],
        type: "#{ref[:base]}[#{ref[:count]}]",
        value: values
      }
    end
  end
end
