# EC2 Instance - InSpec Profile

## Description

A library InSpec compliance profile containing a custom `ec2_instance` resource that can be used to test `meta-data` and `user-data` for AWS EC2 nodes. It does not require AWS API credentials since the resource is retrieving the data on the target ec2 nodes using the `http://169.254.169.254/` metadata API.

InSpec is an open-source run-time framework and rule language used to specify compliance, security, and policy requirements for testing any node in your infrastructure.

The controls you find in the `./controls` directory are sample ones to demonstrate how to use the `ec2_instance` resource.

### Requirements

* [InSpec](https://github.com/chef/inspec)

### Platforms

- Linux
- Windows

## Usage

- Add this to your profile's `inspec.yml` to ensure a correct InSpec version and define the profile dependency:

```yaml
supports:
  - inspec: '~> 1.0'
depends:
  - name: ec2-instance-profile
    git: https://github.com/alexpop/ec2-instance-profile
    version: '~> 0.1'
```

### Examples

- Use the `ec2_instance` resource in your profiles, the same way you'd use core InSpec resources like file, service, command, etc.

```ruby
control 'ec2-instance-1.1' do
  impact 1.0
  title 'Ensure no sensitive information is passed via the user-data'
  describe ec2_instance do
    it { should exist }
    its('user-data') { should_not match /password|secret.?access/i }
  end
end

control 'ec2-instance-1.2' do
  impact 0.6
  title 'Test the IP addresses by specifying meta-data API version'
  describe ec2_instance(version: '2016-06-30') do
    it { should exist }
    its('meta-data/public-ipv4') { should eq '' }
    its('meta-data/local-ipv4') { should match /^172\.31\..+/ }
  end
end
```

### `ec2_instance` resource parameters

Name | Required | Type | Description
--- | --- | --- | --
version | no | String | Defaults to 'latest' if not specified. Call this on your EC2 instance to find out all available versions: `http://169.254.169.254/`
timeout | no | Numeric | Number of seconds to wait for the HTTP connection to open. The default value is 2 seconds.
curl_path | no | String | Defaults to `curl` in `$PATH` if not specified.
wget_path | no | String | Defaults to `wget` in `$PATH` if not specified.

An HTTP client is required on the target node in order for the resource to work. `curl`, `wget` and `Invoke-WebRequest`(Windows) are currently supported.

Example of instantiating the resource with a Hash of the above parameters:
```ruby
describe ec2_instance(version: '2016-06-30', timeout: 3, curl_path: '/usr/bin/curl') do
  it { should exist }
end
```

### `ec2_instance` resource tests

```ruby
describe ec2_instance do
  # Returns true if the node is indeed an EC2 instance
  it { should exist }
  # Test the value returned by 'http://169.254.169.254/latest/SOMETHING', see examples below:
  its('SOMETHING') { should match /hello-world/i }
  # Test 'http://169.254.169.254/latest/meta-data/local-ipv4' if we write:
  its('meta-data/public-ipv4') { should eq '' }
  # Test 'http://169.254.169.254/latest/meta-data/instance-id' if we write:
  its('meta-data/instance-id') { should match /^.{19}+$/ }
end
```


## License and Author

* Author: Alex Pop [alexpop](https://github.com/alexpop)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
