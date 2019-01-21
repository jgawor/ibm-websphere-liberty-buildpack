# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2013-2014 the original author or authors.
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

require 'spec_helper'
require 'component_helper'
require 'fileutils'
require 'liberty_buildpack/jre/openj9'

module LibertyBuildpack::Jre

  describe OpenJ9 do
    include_context 'component_helper'

    let(:configuration) do
      { 'version' => '11.+',
        'type' => 'jre',
        'heap_size' => 'normal',
        'heap_size_ratio' => '0.75' }
    end

    let(:application_cache) { double('ApplicationCache') }

    let(:stubs) {
      LibertyBuildpack::Util::Cache::DownloadCache.stub(:new).and_return(application_cache)
      application_cache.stub(:get).with('https://api.adoptopenjdk.net/v2/info/releases/openjdk11?openjdk_impl=openj9&type=jre&arch=x64&os=linux&heap_size=normal').and_yield(File.open('spec/fixtures/openj9-releases.json'))
      application_cache.stub(:get).with('https://github.com/AdoptOpenJDK/openjdk11-binaries/releases/download/jdk-11%2B28/OpenJDK11-jre_x64_linux_openj9_11_28.tar.gz').and_yield(File.open('spec/fixtures/stub-ibm-java.tar.gz'))
    }

    it 'should detect with id of openjdk-<version>' do
      Dir.mktmpdir do |root|
        stubs
        detected = OpenJ9.new(
          app_dir: root,
          java_home: '',
          java_opts: [],
          configuration: configuration,
          jvm_type: 'openj9'
        ).detect

        expect(detected).to eq("openj9-jdk-11+28")
      end
    end

    it 'should extract Java from a GZipped TAR' do
      Dir.mktmpdir do |root|
        stubs
        OpenJ9.new(
          app_dir: root,
          configuration: configuration,
          java_home: '',
          java_opts: [],
        ).compile

        java = File.join(root, '.java', 'bin', 'java')
        expect(File.exist?(java)).to eq(true)
      end
    end

    it 'adds the JAVA_HOME to java_home' do
      Dir.mktmpdir do |root|
        java_home = ''

        OpenJ9.new(
          app_dir: root,
          java_home: java_home,
          java_opts: [],
          configuration: configuration
        )

        expect(java_home).to eq('.java')
      end
    end

=begin
    describe 'compile',
             java_home: '',
             java_opts: [],
             configuration: {},
             license_ids: { 'IBM_JVM_LICENSE' => '1234-ABCD' },
             service_release: service_release do

      before do |example|
        # get the application cache fixture from the application_cache double provided in the overall setup
        LibertyBuildpack::Util::Cache::ApplicationCache.stub(:new).and_return(application_cache)
        cache_fixture = example.metadata[:cache_fixture]
        application_cache.stub(:get).with(uri).and_yield(File.open("spec/fixtures/#{cache_fixture}")) if cache_fixture
      end

      # context is provided by component_helper, its default values are provided by 'describe' metadata, and
      # customized through test's metadata
      subject(:compiled) { IBMJdk.new(context).compile }

      it 'should extract Java from a bin script', cache_fixture: 'stub-ibm-java.bin' do
        compiled

        java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
        expect(File.exist?(java)).to eq(true)
      end

      it 'should extract Java from a tar gz', cache_fixture: 'stub-ibm-java.tar.gz' do
        compiled

        java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
        expect(File.exist?(java)).to eq(true)
      end

      it 'should fail when the license id is not provided', app_dir: '', license_ids: {} do
        expect { compiled }.to raise_error
      end

      it 'should fail when the license ids do not match', app_dir: '', license_ids: { 'IBM_JVM_LICENSE' => 'Incorrect' } do
        expect { compiled }.to raise_error
      end

      it 'should not fail when the license url is not provided', app_dir: '', license_ids: {}, cache_fixture: 'stub-ibm-java.tar.gz' do
        ibmjdk_config = [LibertyBuildpack::Util::TokenizedVersion.new(service_release), { 'uri' => uri }]
        LibertyBuildpack::Repository::ConfiguredItem.stub(:find_item).and_return(ibmjdk_config)

        compiled

        java = File.join(app_dir, '.java', 'jre', 'bin', 'java')
        expect(File.exist?(java)).to eq(true)
      end

      it 'places the killjava script (with appropriately substituted content) in the diagnostics directory', cache_fixture: 'stub-ibm-java.bin' do
        compiled

        expect(Pathname.new(File.join(LibertyBuildpack::Diagnostics.get_diagnostic_directory(app_dir), IBMJdk::KILLJAVA_FILE_NAME))).to exist
      end

      it 'should add 0.50 ratio when heap_size_ratio is set to 50%', configuration: { 'heap_size_ratio' => 0.50 } do
        compiled

        my_app_dir = component.instance_variable_get('@app_dir')
        memory_config = File.read("#{my_app_dir}/.memory_config/heap_size_ratio_config")
        expect(memory_config).to include('0.5')
      end

      it 'should add 0.75 ratio when heap_size_ratio is not set' do
        compiled

        my_app_dir = component.instance_variable_get('@app_dir')
        memory_config = File.read("#{my_app_dir}/.memory_config/heap_size_ratio_config")
        expect(memory_config).to include('0.75')
      end

    end # end of compile shared tests
=end
    describe 'release' do

      # context is provided by component_helper, its default values are provided by 'describe' metadata, and
      # customized through test's metadata
      subject(:released) do
        Dir.mktmpdir do |root|
          stubs
          component = OpenJ9.new(
            app_dir: root,
            java_home: '',
            java_opts: [],
            configuration: configuration,
            jvm_type: 'openj9'
          )
          component.detect
          component.release
        end
      end

      it 'should add default dump options that output data to the common dumps directory, if enabled' do
        expect(released).to include('-Xdump:none',
                                    '-Xshareclasses:none',
                                    '-Xdump:heap:defaults:file=./../dumps/heapdump.%Y%m%d.%H%M%S.%pid.%seq.phd',
                                    '-Xdump:java:defaults:file=./../dumps/javacore.%Y%m%d.%H%M%S.%pid.%seq.txt',
                                    '-Xdump:snap:defaults:file=./../dumps/Snap.%Y%m%d.%H%M%S.%pid.%seq.trc',
                                    '-Xdump:heap+java+snap:events=user')
      end

      it 'should provide troubleshooting info for JVM shutdowns' do
        expect(released).to include("-Xdump:tool:events=systhrow,filter=java/lang/OutOfMemoryError,request=serial+exclusive,exec=./#{LibertyBuildpack::Diagnostics::DIAGNOSTICS_DIRECTORY}/#{OpenJ9::KILLJAVA_FILE_NAME}")
      end
    end # end of release shared tests

  end
end
