# encoding: utf-8
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
#
# InSpec custom resource for EC2 instance meta-data and user-data testing
# Author: Alex Pop (https://github.com/alexpop)
# Source from https://github.com/alexpop/ec2-instance-profile

# Custom resource based on the InSpec resource DSL
class Ec2Instance < Inspec.resource(1)
  name 'ec2_instance'

  desc "
    The `ec2_instance` resource provides the ability to test meta-data and user-data for compute instances in AWS.
  "

  example "
    describe ec2_instance do
      it { should exist }
      its('user-data') { should_not match /password/i }
      its('meta-data/public-ipv4') { should eq "" }
    end

    describe ec2_instance(curl_path: '/usr/bin/curl', version: '2016-06-30', timeout: 3) do
      its('meta-data/local-ipv4') { should match /172\.16\..+/ }
    end
  "
  def initialize(opts = {})
    @curl = 'curl'
    @wget = 'wget'
    if opts.class.to_s == 'Hash'
      if opts[:version].nil?
        @version = 'latest'
      else
        return skip_resource 'Invalid character in version' unless opts[:version].to_s =~ /^(latest|[\d\.-]+)$/
        @version = opts[:version]
      end
      if opts[:timeout].nil?
        @timeout = 1
      else
        return skip_resource 'timeout is not numeric' unless opts[:timeout].to_s =~ /^\d+$/
        @timeout = opts[:timeout]
      end
      if inspec.os.linux?
        unless opts[:curl_path].nil?
          return skip_resource 'Invalid character in curl_path' unless opts[:curl_path] =~ /^[\w\\\/\. :-]+$/
          @curl = opts[:curl_path].to_s
        end
        unless opts[:wget_path].nil?
          return skip_resource 'Invalid character in wget_path' unless opts[:wget_path] =~ /^[\w\\\/\. :-]+$/
          @wget = opts[:wget_path].to_s
        end
        if inspec.command(@curl).exist?
          # using 'curl'
        elsif inspec.command(@wget).exist?
          @curl = nil
        else
          return skip_resource 'curl or wget are required on the instance for the resource to work.'
        end
      elsif inspec.os.windows?
        # TODO: is Powershell enough?
      else
        return skip_resource "Only Linux OS is supported at the moment"
      end
    else
      return skip_resource "Unsupported parameter #{opts.inspect}. Must be a Hash, for example: ec2_instance(curl_path: '/usr/bin/curl')"
    end
  end

  # Called by: it { should exist }
  def exists?
    get('meta-data/').match(/^ami-id$/)
  end

  # Needed to catch its(name) and send it to get
  def method_missing(name)
    return get(name.to_s)
  end

  private

  # Get the property using the EC2 instance metadata URL
  def get(property)
    return 'Invalid character in property' unless property =~ /^[\w\/-]+$/
    url = "http://169.254.169.254/#{@version}/#{property}"
    if inspec.os.linux?
      if @curl
        inspec.command("#{@curl} --silent --fail --connect-timeout #{@timeout} '#{url}'").stdout
      elsif @wget
        inspec.command("#{@wget} --quiet --connect-timeout #{@timeout} --output-document - '#{url}'").stdout
      else
        'No http client available on the node'
      end
    elsif inspec.os.windows?
      # The Invoke-RestMethod cmdlet was introduced in Windows PowerShell 3.0. I tried it but it parses stuff in output, like powershell script in user-data
      # The Invoke-WebRequest cmdlet was introduced in Windows PowerShell 3.0. RawContent returns the header as well, so have to remove it
      # -OutFile works fine for both RestMethod and WebRequest, but wanted to avoid creating a reading a file
      inspec.powershell("(Invoke-WebRequest #{url} -TimeoutSec #{@timeout}).RawContent").stdout.strip[/\r\n\r\n([\s\S]*)/,1]
    end
  end
end
