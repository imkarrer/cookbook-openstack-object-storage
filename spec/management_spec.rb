# encoding: UTF-8
require_relative 'spec_helper'

describe 'openstack-object-storage::management-server' do
  describe 'ubuntu' do
    let(:runner) { ChefSpec::Runner.new(UBUNTU_OPTS) }
    let(:node) { runner.node }
    let(:chef_run) do
      runner.converge(described_recipe)
    end

    include_context 'swift-stubs'

    it 'upgrades swift swauth package' do
      expect(chef_run).to upgrade_package 'swauth'
    end

    describe '/etc/swift/dispersion.conf' do
      let(:file) { chef_run.template('/etc/swift/dispersion.conf') }

      it 'creates dispersion.conf' do
        expect(chef_run).to create_template(file.name).with(
          user: 'swift',
          group: 'swift',
          mode: 0600
        )
      end

      describe 'default attribute values' do
        it 'uses default attribute value for auth_url' do
          expect(chef_run.node['openstack']['object-storage']['auth_url']).to eq('http://127.0.0.1:8080/auth/v1.0')
        end

        it 'uses default attribute value for swift_secret_databag_name' do
          expect(chef_run.node['openstack']['object-storage']['swift_secret_databag_name']).to be_nil
        end

        it 'uses default attribute value for dispersion auth_user' do
          expect(chef_run.node['openstack']['object-storage']['dispersion']['auth_user']).to eq('test:test')
        end

        it 'uses default attribute value for dispersion auth_key' do
          expect(chef_run.node['openstack']['object-storage']['dispersion']['auth_key']).to eq('test')
        end
      end

      describe 'template contents' do
        it 'sets the auth_url' do
          node.set['openstack']['object-storage']['auth_url'] = 'auth_url_value'
          expect(chef_run).to render_file(file.name).with_content(/^auth_url = auth_url_value$/)
        end

        context 'with databag' do
          let(:swift_secrets) do
            { 'dispersion_auth_user' => 'dispersion_auth_user_value',
              'dispersion_auth_key' => 'dispersion_auth_key_value' }
          end

          before do
            node.set['openstack']['object-storage']['swift_secret_databag_name'] = 'swift_secret_databag_name_value'
            allow(Chef::EncryptedDataBagItem).to receive(:load)
              .with('secrets', 'swift_secret_databag_name_value')
              .and_return(swift_secrets)
          end

          %w(user key).each do |attr|
            it "sets the auth_#{attr}" do
              expect(chef_run).to render_file(file.name).with_content(/^auth_#{attr} = dispersion_auth_#{attr}_value$/)
            end
          end
        end

        context 'without databag' do
          before do
            node.set['openstack']['object-storage']['swift_secret_databag_name'] = nil
          end

          %w(user key).each do |attr|
            it "sets the auth_#{attr}" do
              node.set['openstack']['object-storage']['dispersion']["auth_#{attr}"] = "auth_#{attr}_value"
              expect(chef_run).to render_file(file.name).with_content(/^auth_#{attr} = auth_#{attr}_value$/)
            end
          end
        end
      end
    end

    describe '/usr/local/bin/swift-statsd-publish.py' do
      let(:file) { chef_run.template('/usr/local/bin/swift-statsd-publish.py') }

      it 'creates /usr/local/bin/swift-statsd-publish.py' do
        expect(chef_run).to create_template(file.name).with(
          user: 'root',
          group: 'root',
          mode: 0755
        )
      end

      describe 'default attribute values' do
        it 'uses default attribute value for statsd_host' do
          expect(chef_run.node['openstack']['object-storage']['statistics']['statsd_host']).to eq('127.0.0.1')
        end

        it 'uses default attribute value for statsd_port' do
          expect(chef_run.node['openstack']['object-storage']['statistics']['statsd_port']).to eq('8125')
        end

        it 'uses default attribute value for statsd_prefix' do
          expect(chef_run.node['openstack']['object-storage']['statistics']['statsd_prefix']).to eq('openstack.swift')
        end

        it 'uses default attribute value for enable_dispersion_report' do
          expect(chef_run.node['openstack']['object-storage']['statistics']['enable_dispersion_report']).to eq(true)
        end

        it 'uses default attribute value for enable_recon_report' do
          expect(chef_run.node['openstack']['object-storage']['statistics']['enable_recon_report']).to eq(true)
        end

        it 'uses default attribute value for enable_disk_report' do
          expect(chef_run.node['openstack']['object-storage']['statistics']['enable_disk_report']).to eq(true)
        end

        %w(account container object).each do |server_type|
          it "uses default attribute value for recon_#{server_type}_cache" do
            expect(chef_run.node['openstack']['object-storage']['statistics']["recon_#{server_type}_cache"]).to eq("/var/cache/swift/#{server_type}.recon")
          end
        end
      end

      describe 'template contents' do
        %w(statsd_host statsd_prefix recon_account_cache recon_container_cache recon_object_cache).each do |attr|
          it "sets the #{attr} attribute" do
            node.set['openstack']['object-storage']['statistics'][attr] = "#{attr}_value"
            expect(chef_run).to render_file(file.name).with_content(/self\.#{attr}\s*= '#{attr}_value'$/)
          end
        end

        it 'sets the statsd_port attribute' do
          node.set['openstack']['object-storage']['statistics']['statsd_port'] = 'statsd_port_value'
          expect(chef_run).to render_file(file.name).with_content(/self\.statsd_port\s*= statsd_port_value$/)
        end

        %w(enable_dispersion_report enable_recon_report enable_disk_report).each do |attr|
          [true, false].each do |value|
            it "sets the #{attr} attribute to #{value}" do
              node.set['openstack']['object-storage']['statistics'][attr] = value
              expect(chef_run).to render_file(file.name).with_content(/self\.#{attr}\s*= #{value.to_s.capitalize}$/)
            end
          end
        end
      end
    end
  end
end
