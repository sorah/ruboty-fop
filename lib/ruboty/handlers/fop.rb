require "ruboty-fop/version"
require 'ruboty/handlers/base'
require 'fop'

module Ruboty
  module Handlers
    class Fop < Base
      VERSION = RubotyFop::VERSION

      USEFUL_AIRPORT_ALIASES = {
        'HND' => 'TYO',
        'NRT' => 'TYO',
        'ITM' => 'OSA',
        'KIX' => 'OSA',
      }

      on(/fop\s+help$/, name: 'fop_help', description: 'JAL calculator help')
      on(/fop\s+list(?:(?:\s+airports?)?(?:\s+(?<filter>.+))?)?$/, name: 'fop_airports', description: 'JAL calculator: List airports')
      on(/fop\s+(?:I\s+)?prefer(?<options>(?:\s+-(?:class|(?:dom|intl)-fare|card|status)\s+[^\s]+)*)\s*$/i, name: 'fop_prefer', description: 'JAL calculator: Set preference')
      on(/fop\s+(?<from>[a-zA-Z0-9]+?)[\/-](?<to>[a-zA-Z0-9]+?)\s*(?<options>(?:\s+-(?:class|fare|card|status)\s+[^\s]+)*)\s*$/, name: 'fop_calc', description: 'JAL calculator')

      def fop_help(message)
        message.reply <<-EOF
Usage:
  ruboty fop help
  ruboty fop list {dom|intl} airports [filter]
  ruboty fop dom FROM-TO [-class CLASS] [-fare FARE] [-card CARD] [-status STATUS]
  ruboty fop intl FROM-TO [-fare FARE] [-card CARD] [-status STATUS]
  ruboty fop prefer [-class CLASS] [-fare-dom FARE] [-fare-intl FARE] [-card CARD] [-status STATUS]

Example:
  ruboty fop prefer -card global -status sapphire
  ruboty fop dom TYO-OKA -class J -fare discount

STATUS: #{fop.valid_statuses.map { |_| "`#{_.code}` #{_.name}" }.join(", ")}
CARD:
#{fop.valid_cards.map { |_| "- `#{_.code}` #{_.name}" }.join("\n")}

CLASS: #{fop.valid_dom_classes.map { |_| "`#{_.code}` #{_.name}" }.join(", ")}
FARE:
#{fop.valid_dom_fares.map { |_| "- dom: `#{_.code}` #{_.name}: #{_.remark}" }.join("\n")}
#{fop.valid_intl_fares.map { |_| "- intl: `#{_.code}` #{_.name}: #{_.remark}" }.join("\n")}
        EOF
      rescue ::Fop::Error
        message.reply e.inspect
      rescue StandardError => e
        message.reply e.inspect
      end

      def fop_airports(message)
        filter = message[:filter]
        filter = nil if filter.nil? || filter.strip.empty?
        filter = filter&.upcase

        if filter
          airports = (fop.valid_dom_airports + fop.valid_intl_airports_for_earning).select { |_| filter.nil? || _.code.include?(filter) || _.name.include?(filter) }
          message.reply airports.map{ |_| "- #{_.area ? 'intl' : 'dom'}: `#{_.code}` #{_.name}" }[0,15].join("\n")
        else
          message.reply "dom: #{fop.valid_dom_airports.map(&:code).join(", ")}\nintl: #{fop.valid_intl_airports_for_earning.map(&:code).join(", ")}"
        end
      rescue ::Fop::Error
        message.reply e.inspect
      rescue StandardError => e
        message.reply e.inspect
      end

      def fop_calc(message)
        from_name = USEFUL_AIRPORT_ALIASES[message[:from].upcase] || message[:from].upcase
        to_name = USEFUL_AIRPORT_ALIASES[message[:to].upcase] || message[:to].upcase

        intl_from = fop.valid_intl_airports_for_earning.find { |_| _.code == from_name }
        intl_to = fop.valid_intl_airports_for_earning.find { |_| _.code == to_name }
        dom_from = fop.valid_dom_airports.find { |_| _.code == from_name }
        dom_to = fop.valid_dom_airports.find { |_| _.code == to_name }

        raise ::Fop::Error, "airport #{from_name} is not valid" unless intl_from || dom_from
        raise ::Fop::Error, "airport #{to_name} is not valid" unless intl_to || dom_to

        is_intl = (intl_from && intl_to) && (dom_from.nil? || dom_to.nil?)
        if is_intl
          from, to = intl_from, intl_to
        else
          from, to = dom_from, dom_to
        end

        options = {
          status: '0',
          card: 'club-a',
        }
        parsed_options = parse_options(message[:options])
        if is_intl
          options.merge!(user_preference(message))
          options[:fare] = options.delete(:'intl-fare')
          options.merge!(parsed_options)
          fare = find_intl_fare(options[:fare])
        else
          options.merge!(class: 'J')
          options.merge!(user_preference(message))
          options[:fare] = options.delete(:'dom-fare')
          options.merge!(parsed_options)
          klass = find_dom_class(options[:class])
          fare = find_dom_fare(options[:fare])
        end

        card = find_card(options[:card])
        status = find_status(options[:status])

        if is_intl
          result = fop.intl_search(
            from: from,
            to: to,
            fare: fare,
            card: card,
            status: status,
          )
        else
          result = fop.dom_search(
            from: from,
            to: to,
            class: klass,
            fare: fare,
            card: card,
            status: status,
          )
        end

        message.reply <<-EOF
#{from.code} (#{from.name}) - #{to.code} (#{to.name})
#{klass ? "#{klass.name}, " : nil}#{fare.name}, #{status.name} (#{card.name})

*single-trip #{result.miles} miles, #{result.fop} FOP*
*round-trip #{result.miles * 2} miles, #{result.fop * 2} FOP*

Mileage:
- #{result.flight_miles} (#{result.flight_miles_remark})
#{result.bonus_miles ? "- #{result.bonus_miles} (#{result.bonus_miles_remark})" : nil}
FOP:
- #{result.flight_miles} * #{result.fop_rate}
#{result.fop_bonus ? "- #{result.fop_bonus } (#{result.fop_bonus_remark})" : nil}
        EOF
      rescue ::Fop::Error => e
        message.reply e.message
      rescue StandardError => e
        message.reply e.inspect
      end

      def fop_prefer(message)
        options = parse_options(message[:options])
        preference = user_preference(message)
        if options.empty?
          message.reply "Your preference is:\n#{preference.inspect}"
        else
          options.each do |k, v|
            case k
            when :class; find_dom_class(v)
            when :'dom-fare'; find_dom_fare(v)
            when :'intl-fare'; find_intl_fare(v)
            when :card; find_card(v)
            when :status; find_status(v)
            end
          end

          preference.merge!(options)
          message.reply "preference updated:\n#{preference.inspect}"
        end
      rescue ::Fop::Error => e
        message.reply e.message
      rescue StandardError => e
        message.reply e.inspect
      end

      private

      def fop
        @fop ||= ::Fop::Client.new
      end

      def find_dom_class(str)
        klass = fop.valid_dom_classes.find { |_| _.code == str }
        unless klass
          list = fop.valid_dom_classes.map { |_| "- `#{_.code}` #{_.name}" }.join("\n")
          if str
            raise ::Fop::Error, "class #{str.inspect} is not valid\n#{list}"
          else
            raise ::Fop::Error, "class is required\n#{list}"
          end
        end
        klass
      end

      def find_dom_fare(str)
        fare = fop.valid_dom_fares.find { |_| _.code == str }
        unless fare
          list = fop.valid_dom_fares.map { |_| "- `#{_.code}` #{_.name}: #{_.remark}" }.join("\n")
          if str
            raise ::Fop::Error, "fare #{str.inspect} is not valid\n#{list}"
          else
            raise ::Fop::Error, "fare is required\n#{list}"
          end
        end
        fare
      end

      def find_intl_fare(str)
        fare = fop.valid_intl_fares.find { |_| _.code == str }
        unless fare
          list = fop.valid_intl_fares.map { |_| "- `#{_.code}` #{_.name}: #{_.remark}" }.join("\n")
          if str
            raise ::Fop::Error, "fare #{str.inspect} is not valid\n#{list}"
          else
            raise ::Fop::Error, "fare is required\n#{list}"
          end
        end
        fare
      end

      def find_card(str)
        card = fop.valid_cards.find { |_| _.code == str }
        unless card
          list = fop.valid_cards.map { |_| "- `#{_.code}` #{_.name}" }.join("\n")
          if str
            raise ::Fop::Error, "card #{str.inspect} is not valid\n#{list}"
          else
            raise ::Fop::Error, "card is required\n#{list}"
          end
        end
        card
      end

      def find_status(str)
        status = fop.valid_statuses.find { |_| _.code == str }
        unless status
          list = fop.valid_statuses.map { |_| "- `#{_.code}` #{_.name}" }.join("\n")
          if str
            raise ::Fop::Error, "status #{str.inspect} is not valid\n#{list}"
          else
            raise ::Fop::Error, "status is required\n#{list}"
          end
        end
        status
      end

      def user_preference(message)
        u = message.original.dig(:user, 'id') || message.from_name
        (robot.brain.data['fop.preference'] ||= {})[u] ||= {}
      end

      def parse_options(str)
        str&.scan(/-(.+?) (.+?)(?:\s+|$)/)&.map{ |_| [_[0].to_sym, _[1]] }.to_h || {}
      end
    end
  end
end
