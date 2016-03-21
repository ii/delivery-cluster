#
# Cookbook Name:: delivery-cluster
# Spec:: setup_delivery_server_spec
#
# Author:: Salim Afiune (<afiune@chef.io>)
#
# Copyright:: Copyright (c) 2015 Chef Software, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'

describe 'delivery-cluster::setup_delivery_server' do
  let(:insights_enabled) { false }

  let(:chef_run) do
    ChefSpec::SoloRunner.new do |node|
      node.set['delivery-cluster'] = cluster_data
      node.set['delivery-cluster']['delivery']['insights']['enable'] = insights_enabled
    end.converge(described_recipe)
  end

  before do
    allow_any_instance_of(Chef::Resource).to receive(:cluster_data_dir)
      .and_return('/repo/delivery-cluster-dir')
    allow_any_instance_of(Chef::Resource).to receive(:delivery_server_fqdn)
      .and_return(cluster_data['delivery']['fqdn'])
  end

  it 'includes _settings recipe' do
    expect(chef_run).to include_recipe('delivery-cluster::_settings')
  end

  it 'converge delivery machine' do
    expect(chef_run).to converge_machine('delivery-server-chefspec')
      .with_files(
        '/etc/delivery/delivery.pem' => '/repo/delivery-cluster-dir/delivery.pem',
        '/etc/delivery/builder_key' => '/repo/delivery-cluster-dir/builder_key',
        '/etc/delivery/builder_key.pub' => '/repo/delivery-cluster-dir/builder_key.pub'
      )
  end

  it 'download the credentials chefspec.creds' do
    expect(chef_run).to download_machine_file('/tmp/chefspec.creds')
      .with_machine('delivery-server-chefspec')
  end

  it 'download delivery-server-cert' do
    expect(chef_run).to download_machine_file('delivery-server-cert')
      .with_machine('delivery-server-chefspec')
  end

  it 'create an enterprise' do
    expect(chef_run).to run_machine_execute('Creating Enterprise')
      .with_machine('delivery-server-chefspec')
  end

  context 'when insights is enabled' do
    let(:insights_enabled) { true }

    it 'updates chef-server with delivery address' do
      extra_config = <<-EOM
external_rabbitmq['enable'] = true
external_rabbitmq['actions_vhost'] = '/insights'
external_rabbitmq['actions_exchange'] = 'chefspec-insights'
external_rabbitmq['vip'] = 'delivery-server.chef.io'
external_rabbitmq['node_port'] = '5672'
external_rabbitmq['actions_user'] = 'chefspec-insights'
external_rabbitmq['actions_password'] = 'chefspec-chefrocks'
      EOM

      mods = { 'chef-server-12' => { 'extra_config' => extra_config } }

      expect(chef_run).to converge_machine('chef-server-chefspec')
        .with_attributes(mods)
    end
  end

  context 'when insights is disabled' do
    let(:insights_enabled) { false }

    it 'updates chef-server with delivery address' do
      expect(chef_run).not_to converge_machine('chef-server-chefspec')
    end
  end
end
