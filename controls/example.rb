# encoding: utf-8

title 'Sample profile on how to use the ec2_instance resource'

only_if do
  ec2_instance.exist?
end

# Uses the custom ec2_instance InSpec resource from ../libraries/
control 'ec2-instance-1.0' do
  impact 1.0
  title 'Ensure no sensitive information is passed via the user-data'
  describe ec2_instance do
    it { should exist }
    its('user-data') { should_not match /password|secret.?access/i }
  end
end
