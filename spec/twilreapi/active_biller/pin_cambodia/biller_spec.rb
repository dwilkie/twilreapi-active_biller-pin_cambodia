require 'spec_helper'

describe Twilreapi::ActiveBiller::PinCambodia::Biller do
  include EnvHelpers

  class DummyCdr
    require 'json'

    attr_accessor :raw_cdr, :cdr

    def initialize(raw_cdr)
      self.raw_cdr = raw_cdr
      self.cdr = JSON.parse(raw_cdr)
    end
  end

  let(:sample_cdr_file) { "./spec/fixtures/cdr.json" }
  let(:sample_cdr) { File.read(sample_cdr_file) }
  let(:raw_cdr) { sample_cdr }
  let(:dummy_cdr) { DummyCdr.new(raw_cdr) }

  # Environment configuration
  let(:bill_block_seconds) { "15" }
  let(:default_country_code) { "855" }
  let(:per_minute_call_rate_pin_kh_01_to_smart) { 35000 }
  let(:per_minute_call_rate_pin_kh_01_to_other) { 75000 }
  let(:per_minute_call_rate_pin_kh_04_to_metfone) { 62000 }
  let(:per_minute_call_rate_pin_kh_04_to_other) { 52000 }

  def setup_scenario
    stub_env(
      :"twilreapi_active_biller_pin_cambodia_bill_block_seconds" => bill_block_seconds,
      :"twilreapi_active_biller_pin_cambodia_default_country_code" => default_country_code,
      :"twilreapi_active_biller_pin_cambodia_per_minute_call_rate_pin_kh_01_to_smart" => per_minute_call_rate_pin_kh_01_to_smart,
      :"twilreapi_active_biller_pin_cambodia_per_minute_call_rate_pin_kh_01_to_other" => per_minute_call_rate_pin_kh_01_to_other,
      :"twilreapi_active_biller_pin_cambodia_per_minute_call_rate_pin_kh_04_to_metfone" => per_minute_call_rate_pin_kh_04_to_metfone,
      :"twilreapi_active_biller_pin_cambodia_per_minute_call_rate_pin_kh_04_to_other" => per_minute_call_rate_pin_kh_04_to_other
    )
  end

  before do
    setup_scenario
  end

  describe "#calculate_price_in_micro_units" do
    let(:result) { subject.calculate_price_in_micro_units }
    let(:call_direction) { nil }
    let(:sip_gateway_name) { nil }
    let(:billsec) { nil }
    let(:sip_to_user) { nil }

    let(:raw_cdr) {
      cdr = JSON.parse(sample_cdr)
      cdr_variables.delete_if { |k, v| v.nil? }.each do |key, value|
        cdr["variables"][key] = value
      end
      cdr.to_json
    }

    def cdr_variables
      {
        "direction" => call_direction,
        "sip_gateway_name" => sip_gateway_name,
        "billsec" => billsec,
        "sip_to_user" => sip_to_user
      }
    end

    before do
      subject.options = {:cdr => dummy_cdr}
    end

    context "where the call direction is inbound" do
      let(:call_direction) { "inbound" }
      let(:billsec) { 100 }
      it { expect(result).to eq(0) }
    end

    context "where the call direction is outbound" do
      let(:call_direction) { "outbound" }

      context "and unless otherwise specified where the gateway is 'pin_kh_01', the destination operator is 'smart' and the billsec is:" do
        let(:sip_to_user) { "010234567" }
        let(:sip_gateway_name) { "pin_kh_01" }

        context "0" do
          let(:billsec) { 0 }
          it { expect(result).to eq(0) }
        end

        context "1" do
          let(:billsec) { 1 }

          context "pin_kh_01" do
            let(:sip_gateway_name) { "pin_kh_01" }

            context "to smart" do
              let(:sip_to_user) { "010234567" }
              it { expect(result).to eq(8750) }
            end

            context "to other" do
              let(:sip_to_user) { "012234567" }
              it { expect(result).to eq(18750) }
            end
          end

          context "pin_kh_02" do
            let(:sip_gateway_name) { "pin_kh_02" }
            it { expect(result).to eq(0) }
          end

          context "pin_kh_03" do
            let(:sip_gateway_name) { "pin_kh_03" }
            it { expect(result).to eq(0) }
          end

          context "pin_kh_04" do
            let(:sip_gateway_name) { "pin_kh_04" }

            context "to metfone" do
              let(:sip_to_user) { "0972345678" }
              it { expect(result).to eq(15500) }
            end

            context "to other" do
              let(:sip_to_user) { "012234567" }
              it { expect(result).to eq(13000) }
            end
          end

          context "pin_kh_05" do
            let(:sip_gateway_name) { "pin_kh_05" }
            it { expect(result).to eq(0) }
          end

          context "pin_kh_06" do
            let(:sip_gateway_name) { "pin_kh_06" }
            it { expect(result).to eq(0) }
          end

          context "pin_kh_07" do
            let(:sip_gateway_name) { "pin_kh_07" }
            it { expect(result).to eq(0) }
          end
        end

        context "15" do
          let(:billsec) { 15 }
          it { expect(result).to eq(8750) }
        end

        context "16" do
          let(:billsec) { 16 }
          it { expect(result).to eq(17500) }
        end

        context "30" do
          let(:billsec) { 30 }
          it { expect(result).to eq(17500) }
        end

        context "31" do
          let(:billsec) { 31 }
          it { expect(result).to eq(26250) }
        end

        context "45" do
          let(:billsec) { 45 }
          it { expect(result).to eq(26250) }
        end

        context "46" do
          let(:billsec) { 46 }
          it { expect(result).to eq(35000) }
        end

        context "60" do
          let(:billsec) { 60 }
          it { expect(result).to eq(35000) }
        end

        context "61" do
          let(:billsec) { 61 }
          it { expect(result).to eq(43750) }
        end
      end
    end
  end
end
