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
    if opts.class.to_s == 'Hash'
      set_version(opts[:version])
      set_timeout(opts[:timeout])
      set_curl(opts[:curl_path])
      set_wget(opts[:wget_path])
      if inspec.command(@curl).exist?
        @wget = nil
      elsif inspec.command(@wget).exist?
        @curl = nil
      elsif inspec.os.windows?
        @curl = nil
        @wget = nil
        # Using Invoke-WebRequest cmdlet, introduced in Windows PowerShell 3.0
      else
        return skip_resource "'curl' or 'wget' are required on the instance for the resource to work."
      end
    else
      return skip_resource "Unsupported parameter #{opts.inspect}. Must be a Hash, for example: ec2_instance(curl_path: '/usr/bin/curl')"
    end
  end

  # Called by: it { should exist }
  # It's an ec2 instance if meta-data includes ami(Amazon Machine Image) id
  def exists?
    return get('meta-data/').match(/^ami-id$/)
  end

  # Catching: its(name) { should ... }
  def method_missing(name)
    return get(name.to_s)
  end

  private

  # Return the property using the EC2 instance metadata URL
  def get(property)
    return 'Invalid character in property' unless property =~ /^[\w\/-]+$/
    url = "http://169.254.169.254/#{@version}/#{property}"
    if !@curl.nil?
      inspec.command("#{@curl} --silent --fail --connect-timeout #{@timeout} '#{url}'").stdout
    elsif !@wget.nil?
      inspec.command("#{@wget} --quiet --connect-timeout #{@timeout} --output-document - '#{url}'").stdout
    elsif inspec.os.windows?
      # Tried Invoke-RestMethod(PowerShell 3.0) but it parses stuff in output, like powershell script in user-data
      # The Invoke-WebRequest(PowerShell 3.0) RawContent method returns the header as well, so have to remove it
      # -OutFile works fine for both RestMethod and WebRequest, but wanted to avoid creating a reading a file
      inspec.powershell("(Invoke-WebRequest #{url} -TimeoutSec #{@timeout}).RawContent").stdout.strip[/\r\n\r\n([\s\S]*)/, 1]
    else
      'No http client available on the node'
    end
  end

  # Set a default value for version or validate the one received as a parameter
  def set_version(value)
    if value.nil?
      @version = 'latest'
    else
      return skip_resource 'Invalid character in version' unless value.to_s =~ /^(latest|[\d\.-]+)$/
      @version = value
    end
  end

  # Set a default value for timeout or validate the one received as a parameter
  def set_timeout(value)
    if value.nil?
      @timeout = 2
    else
      return skip_resource 'timeout is not numeric' unless value.to_s =~ /^\d+$/
      @timeout = value
    end
  end

  # Set a default value for curl or validate the one received as a parameter
  def set_curl(value)
    if value.nil?
      @curl = 'curl'
    else
      return skip_resource 'Invalid character in curl_path' unless value =~ /^[\w\\\/\. :-]+$/
      @curl = value.to_s
    end
  end

  # Set a default value for wget or validate the one received as a parameter
  def set_wget(value)
    if value.nil?
      @wget = 'wget'
    else
      return skip_resource 'Invalid character in wget_path' unless value =~ /^[\w\\\/\. :-]+$/
      @wget = value.to_s
    end
  end
end
