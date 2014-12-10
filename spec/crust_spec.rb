require_relative '../lib/crust'
require 'fleetctl'
require 'spec_helper'

describe Crust do

  describe '#list-units' do
    it '#get_services' do
      expect{Crust.new.get_services}.not_to raise_error
    end

    it '#destroy_build' do
      expect{Crust.new.destroy_build('tp', 'bb75c10')}.not_to raise_error
    end
  end
end
