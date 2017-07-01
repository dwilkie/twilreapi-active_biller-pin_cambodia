require "twilreapi/active_biller/base"
require "json"
require_relative "torasup"

class Twilreapi::ActiveBiller::PinCambodia::Biller < Twilreapi::ActiveBiller::Base
  OUTBOUND_DIRECTION = "outbound"
  OTHER_OPERATOR_KEY = "other"
  DEFAULT_COUNTRY_CODE = "855"
  DEFAULT_PER_MINUTE_CALL_RATE = 0
  DEFAULT_BILL_BLOCK_SECONDS = 60

  def calculate_price_in_micro_units
    calculate_price.to_i
  end

  private

  def calculate_price
    (billable_blocks * per_minute_call_rate / minute_to_billable_blocks) if outbound_call? && bill_sec > 0
  end

  def destination_torasup_number
    destination_number = normalized_destination_number
    @destination_torasup_number ||= Torasup::PhoneNumber.new(destination_number) if destination_number
  end

  def destination_operator
    destination_torasup_number && destination_torasup_number.operator
  end

  def normalized_destination_number
    number_to_normalize = variables["sip_to_user"].to_s.sub(/^0/, default_country_code)
    Phony.normalize(number_to_normalize) if Phony.plausible?(number_to_normalize)
  end

  def call_data_record
    options[:call_data_record]
  end

  def cdr
    @cdr ||= JSON.parse((call_data_record && call_data_record.file.read) || "{}")
  end

  def variables
    cdr["variables"] || {}
  end

  def bill_sec
    variables["billsec"].to_i
  end

  def outbound_call?
    variables["direction"] == OUTBOUND_DIRECTION
  end

  def minute_to_billable_blocks
    (60 / bill_block_seconds)
  end

  def billable_blocks
    ((bill_sec - 1) / bill_block_seconds) + 1
  end

  def bill_block_seconds
    (self.class.configuration("bill_block_seconds") || DEFAULT_BILL_BLOCK_SECONDS).to_i
  end

  def per_minute_call_rate
    gateway_name_or_host = variables["sip_gateway_name"] || variables["sip_to_host"]
    operator_id = destination_operator && destination_operator.id
    (
      self.class.configuration("per_minute_call_rate_#{gateway_name_or_host}_to_#{operator_id}") ||
      self.class.configuration("per_minute_call_rate_#{gateway_name_or_host}_to_#{OTHER_OPERATOR_KEY}") ||
      DEFAULT_PER_MINUTE_CALL_RATE
    ).to_i
  end

  def default_country_code
    (self.class.configuration("default_country_code") || DEFAULT_COUNTRY_CODE).to_s
  end

  def self.configuration(key)
    ENV["TWILREAPI_ACTIVE_BILLER_PIN_CAMBODIA_#{key.to_s.upcase}"]
  end
end
