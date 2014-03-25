#
# Cookbook Name:: rackspace_cloudbackup
#
# Copyright 2014, Rackspace, US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rspec_helper'

require_relative '../../../libraries/RcbuBackupWrapper.rb'

module RcbuBackupWrapperTestHelpers
  def dummy_bootstrap_data
    return {
      'TestData' => true, # A dummy test key
      'AgentId'  => 'Test Agent ID'
    }
  end
  module_function :dummy_bootstrap_data

  def load_backup_config_stub(rcbu_bootstrap_file)
    # Merge in the argument so we can test for it
    return dummy_bootstrap_data.merge({'BootstrapFile' => rcbu_bootstrap_file})
  end
  module_function :load_backup_config_stub

  def get_backup_obj_stub(api_username, api_key, region)
    return "STUB: ARGS: #{api_username}, #{api_key}, #{region}"
  end
  module_function :get_backup_obj_stub
  
  class RcbuApiWrapperStub
    attr_accessor :api_username, :api_key, :region, :agent_id
    def initialize(api_username, api_key, region, agent_id)
      @api_username = api_username
      @api_key = api_key
      @region = region
      @agent_id = agent_id
    end
  end      
end

describe 'RcbuBackupWrapper' do
  describe 'initialize' do
    before :each do
      # Stub _load_backup_config and _get_backup_obj, they will be tested separately.
      Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.any_instance.stub(:_load_backup_config) do |arg|
        RcbuBackupWrapperTestHelpers.load_backup_config_stub(arg)
      end

      Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.any_instance.stub(:_get_backup_obj) do |arg1, arg2, arg3|
        RcbuBackupWrapperTestHelpers.get_backup_obj_stub(arg1, arg2, arg3)
      end

      @test_obj = Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.new('Test Username', 'Test Key', 'Test Region', 'Test Label', 'Test Mocking', 'Test Bootstrap File')
    end

    it 'sets the mocking variable' do
      @test_obj.mocking.should eql 'Test Mocking'
    end

    it 'sets the agent_config variable' do
      @test_obj.agent_config.should eql RcbuBackupWrapperTestHelpers.load_backup_config_stub('Test Bootstrap File')
    end

    it 'sets the backup_obj variable' do
      @test_obj.backup_obj.should eql RcbuBackupWrapperTestHelpers.get_backup_obj_stub('Test Username', 'Test Key', 'Test Region')
    end

    it 'sets the direct_name_map variable' do
      # Don't bother checking the exact content, just check that it is set
      @test_obj.direct_name_map.should be_an_instance_of Hash
    end
  end

  describe '_load_backup_config' do
    it 'fails when Opscode::Rackspace::CloudBackup.gather_bootstrap_data returns nil' do
      Opscode::Rackspace::CloudBackup.stub(:gather_bootstrap_data).and_return(nil)
      expect { Opscode::Rackspace::CloudBackup::RcbuBackupWrapper._load_backup_config(nil) }.to raise_exception
    end

    it 'fails when Opscode::Rackspace::CloudBackup.gather_bootstrap_data is missing AgentId' do
      Opscode::Rackspace::CloudBackup.stub(:gather_bootstrap_data).and_return({'foo' => 'bar'})
      expect { Opscode::Rackspace::CloudBackup::RcbuBackupWrapper._load_backup_config(nil) }.to raise_exception
    end
    
    it 'returns data from Opscode::Rackspace::CloudBackup.gather_bootstrap_data when data is valid' do
      Opscode::Rackspace::CloudBackup.stub(:gather_bootstrap_data) do |arg|
        RcbuBackupWrapperTestHelpers.load_backup_config_stub(arg)
      end
      
      Opscode::Rackspace::CloudBackup::RcbuBackupWrapper._load_backup_config('Test Bootstrap File').should eql RcbuBackupWrapperTestHelpers.load_backup_config_stub('Test Bootstrap File')
    end
  end

  describe '_get_api_obj' do
    before :each do
      # This method calls Chef debug prints
      # Include ChefSpec here to avoid colissions with WebMock
      require 'chefspec_helper'

      # Stub _load_backup_config and _get_backup_obj so the constructor loads smoothly
      Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.any_instance.stub(:_load_backup_config) do |arg|
        RcbuBackupWrapperTestHelpers.load_backup_config_stub(arg)
      end

      Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.any_instance.stub(:_get_backup_obj) do |arg1, arg2, arg3|
        RcbuBackupWrapperTestHelpers.get_backup_obj_stub(arg1, arg2, arg3)
      end
    end
    
    it 'returns a Opscode::Rackspace::CloudBackup::MockRcbuApiWrapper class when mocking is true' do
      test_obj = Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.new('Test Username', 'Test Key', 'Test Region', 'Test Label', true, 'Test Bootstrap File')
      test_obj.mocking.should eql true
      test_obj._get_api_obj('Mock Test Username', 'Test Key', 'Test Region').should be_an_instance_of Opscode::Rackspace::CloudBackup::MockRcbuApiWrapper
    end

    it 'returns a Opscode::Rackspace::CloudBackup::RcbuApiWrapper class when mocking is false' do
      # Stub out the Opscode::Rackspace::CloudBackup::RcbuApiWrapper class as we don't want to actually open an API connection.
      stub_const('Opscode::Rackspace::CloudBackup::RcbuApiWrapper', RcbuBackupWrapperTestHelpers::RcbuApiWrapperStub)

      test_obj = Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.new('Test Username', 'Test Key', 'Test Region', 'Test Label', false, 'Test Bootstrap File')
      test_obj.mocking.should eql false

      test_obj._get_api_obj('API Test Username', 'Test Key', 'Test Region').should be_an_instance_of RcbuBackupWrapperTestHelpers::RcbuApiWrapperStub
    end

    it 'passes proper variables to Opscode::Rackspace::CloudBackup::RcbuApiWrapper' do
      # Use our stub class to check the variables
      stub_const('Opscode::Rackspace::CloudBackup::RcbuApiWrapper', RcbuBackupWrapperTestHelpers::RcbuApiWrapperStub)

      test_obj = Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.new('Test Username', 'Test Key', 'Test Region', 'Test Label', false, 'Test Bootstrap File')
      test_obj.mocking.should eql false

      # rspec doesn't reinitialize class variables, so use a unique username to avoid a cache hit from previous tests.
      api_obj = test_obj._get_api_obj('Variable Test Username', 'Variable Test Key', 'Variable Test Region')
      api_obj.should be_an_instance_of RcbuBackupWrapperTestHelpers::RcbuApiWrapperStub
      
      api_obj.api_username.should eql 'Variable Test Username'
      api_obj.api_key.should eql 'Variable Test Key'
      api_obj.region.should eql 'Variable Test Region'
      api_obj.agent_id.should eql RcbuBackupWrapperTestHelpers.dummy_bootstrap_data['AgentId']
    end      

    it 'returns cached values on cache hit' do
      # Utilize Ruby class object_ids for verifying cache hits
      # http://ruby-doc.org/core-2.1.1/Object.html#method-i-object_id
      
      # Stub out the Opscode::Rackspace::CloudBackup::RcbuApiWrapper class as we don't want to actually open an API connection.
      stub_const('Opscode::Rackspace::CloudBackup::RcbuApiWrapper', RcbuBackupWrapperTestHelpers::RcbuApiWrapperStub)

      test_obj_1 = Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.new('Test Username', 'Test Key', 'Test Region', 'Test Label', false, 'Test Bootstrap File')
      test_obj_1.mocking.should eql false
      api_obj_1 = test_obj_1._get_api_obj('Cache Test Username', 'Cache Test Key', 'Cache Test Region')

      test_obj_2 = Opscode::Rackspace::CloudBackup::RcbuBackupWrapper.new('Test Username', 'Test Key', 'Test Region', 'Test Label', false, 'Test Bootstrap File')
      test_obj_2.mocking.should eql false
      api_obj_2 = test_obj_2._get_api_obj('Cache Test Username', 'Cache Test Key', 'Cache Test Region')
      
      # The test objects must be different
      test_obj_1.object_id.should_not eql test_obj_2.object_id
      
      # The API Objects should be the same
      api_obj_1.object_id.should eql api_obj_2.object_id
    end
  end
    
  describe '_get_backup_obj' do
  end    
  
end