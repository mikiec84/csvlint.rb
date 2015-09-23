module Csvlint
  module Csvw
    class NumberFormat

      attr_reader :pattern, :prefix, :numeric_part, :suffix, :grouping_separator, :decimal_separator, :primary_grouping_size, :secondary_grouping_size, :fractional_grouping_size

      def initialize(pattern=nil, grouping_separator=nil, decimal_separator=".")
        @pattern = pattern
        @grouping_separator = grouping_separator || (@pattern.nil? ? nil : ",")
        @decimal_separator = decimal_separator || "."
        if pattern.nil?
          @regexp = Regexp.new("^(([-+]?[0-9]+(#{Regexp.escape(@decimal_separator)}[0-9]+)?([Ee][-+]?[0-9]+)?[%‰]?)|NaN|INF|-INF)$")
        else
          numeric_part_regexp = Regexp.new("(?<numeric_part>([0#Ee]|#{Regexp.escape(@grouping_separator)}|#{Regexp.escape(@decimal_separator)})+)")
          number_format_regexp = Regexp.new("^(?<prefix>.*?)#{numeric_part_regexp}(?<suffix>.*?)$")
          match = number_format_regexp.match(pattern)
          raise Csvw::NumberFormatError, "invalid number format" if match.nil?

          @prefix = match["prefix"]
          @numeric_part = match["numeric_part"]
          @suffix = match["suffix"]

          parts = @numeric_part.split("E")
          mantissa_part = parts[0]
          exponent_part = parts[1] || ""
          mantissa_parts = mantissa_part.split(@decimal_separator)
          # raise Csvw::NumberFormatError, "more than two decimal separators in number format" if parts.length > 2
          integer_part = mantissa_parts[0]
          fractional_part = mantissa_parts[1] || ""

          @integer_pattern = exponent_part == "" && fractional_part == ""

          min_integer_digits = integer_part.gsub(@grouping_separator, "").gsub("#", "").length
          min_fraction_digits = fractional_part.gsub(@grouping_separator, "").gsub("#", "").length
          max_fraction_digits = fractional_part.gsub(@grouping_separator, "").length
          min_exponent_digits = exponent_part.gsub("#", "").length
          max_exponent_digits = exponent_part.length

          integer_parts = integer_part.split(@grouping_separator)[1..-1]
          @primary_grouping_size = integer_parts[-1].length rescue 0
          @secondary_grouping_size = integer_parts[-2].length rescue @primary_grouping_size

          fractional_parts = fractional_part.split(@grouping_separator)[0..-2]
          @fractional_grouping_size = fractional_parts[0].length rescue 0

          numeric_part_regexp = "[-+]?"

          if @primary_grouping_size == 0
            integer_regexp = "[0-9]*[0-9]{#{min_integer_digits}}"
          else
            leading_regexp = "([0-9]{0,#{@secondary_grouping_size - 1}}#{Regexp.escape(@grouping_separator)})?"
            secondary_groups = "([0-9]{#{@secondary_grouping_size}}#{Regexp.escape(@grouping_separator)})*"
            final_optional_digits = @primary_grouping_size - min_integer_digits > 0 ? "[0-9]{1,#{@primary_grouping_size - min_integer_digits}}" : ""
            integer_regexp = "(#{leading_regexp}#{secondary_groups}#{final_optional_digits})?[0-9]{#{min_integer_digits}}"
          end

          numeric_part_regexp += integer_regexp

          if max_fraction_digits > 0
            if @fractional_grouping_size == 0
              fractional_regexp = ""
              fractional_regexp += "[0-9]{#{min_fraction_digits}}" if min_fraction_digits > 0
              fractional_regexp += "[0-9]{0,#{max_fraction_digits - min_fraction_digits}}" unless min_fraction_digits == max_fraction_digits
              fractional_regexp = "#{Regexp.escape(@decimal_separator)}#{fractional_regexp}"
              fractional_regexp = "(#{fractional_regexp})?" if min_fraction_digits == 0
              numeric_part_regexp += fractional_regexp
            else
              fractional_regexp = ""
              fractional_regexp += "[0-9]{#{min_fraction_digits}}" if min_fraction_digits > 0
              fractional_regexp += "[0-9]{0,#{@fractional_grouping_size - min_fraction_digits}}" unless min_fraction_digits == @fractional_grouping_size
              fractional_regexp += "(#{Regexp.escape(@grouping_separator)}[0-9]{#{@fractional_grouping_size}}){0,#{max_fraction_digits / @fractional_grouping_size}}" if max_fraction_digits / @fractional_grouping_size > 0
              fractional_regexp += "(#{Regexp.escape(@grouping_separator)}[0-9]{0,#{max_fraction_digits % @fractional_grouping_size}})?" if max_fraction_digits % @fractional_grouping_size > 0
              fractional_regexp = "#{Regexp.escape(@decimal_separator)}#{fractional_regexp}"
              fractional_regexp = "(#{fractional_regexp})?" if min_fraction_digits == 0
              numeric_part_regexp += fractional_regexp
            end
          end

          if max_exponent_digits > 0
            numeric_part_regexp += "E"
            numeric_part_regexp += "[0-9]{0,#{max_exponent_digits - min_exponent_digits}}" unless max_exponent_digits == min_exponent_digits
            numeric_part_regexp += "[0-9]{#{min_exponent_digits}}" unless min_exponent_digits == 0
          end

          @regexp = Regexp.new("^(?<prefix>#{Regexp.escape(@prefix)})(?<numeric_part>#{numeric_part_regexp})(?<suffix>#{suffix})$")
        end
      end

      def match(value)
        value =~ @regexp ? true : false
      end

      def parse(value)
        if @pattern.nil?
          return nil if !@grouping_separator.nil? && value =~ Regexp.new("((^#{Regexp.escape(@grouping_separator)})|#{Regexp.escape(@grouping_separator)}{2})")
          value.gsub!(@grouping_separator, "") unless @grouping_separator.nil?
          if value =~ INTEGER_REGEXP
            case value[-1]
            when "%"
              return value.to_f / 100
            when "‰"
              return value.to_f / 1000
            else
              return value.to_i
            end
          elsif value =~ @regexp
            case value
            when "NaN"
              return Float::NAN
            when "INF"
              return Float::INFINITY
            when "-INF"
              return -Float::INFINITY
            else
              case value[-1]
              when "%"
                return value.to_f / 100
              when "‰"
                return value.to_f / 1000
              else
                return value.to_f
              end
            end
          else
            return nil
          end
        else
          match = @regexp.match(value)
          return nil if match.nil?
          number = match["numeric_part"].gsub(@grouping_separator, "")
          return number.to_i if @integer_pattern
          return number.to_f
        end
      end

      private
        INTEGER_REGEXP = /^[-+]?[0-9]+[%‰]?$/

    end

    class NumberFormatError < StandardError

    end
  end
end