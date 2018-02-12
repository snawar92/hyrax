RSpec.describe Hyrax::Analytics do
  before do
    described_class.send(:remove_instance_variable, :@config) if described_class.send(:instance_variable_defined?, :@config)
  end

  describe "configuration" do
    let(:config) { described_class.send(:config) }

    context "When the yaml file has values" do
      it "is valid" do
        expect(config).to be_valid
      end

      it 'reads its config from a yaml file' do
        expect(config.view_id).to eql 'XXXXXXXXX'
        expect(config.privkey_path).to eql '/tmp/privkey.json'
      end
    end

    context "When the yaml file has no values" do
      before do
        allow(File).to receive(:read).and_return("# Just comments\n# and comments\n")
      end

      it "is not valid" do
        expect(Rails.logger).to receive(:error)
          .with(starting_with("Unable to fetch any keys from"))
        expect(config).not_to be_valid
      end
    end
  end

  describe "#profile" do
    subject { described_class.profile }

    context "when the private key file is missing" do
      it "raises an error" do
        expect { subject }.to raise_error RuntimeError, "Private key file for Google Analytics was expected at '/tmp/privkey.json', but no file was found."
      end
    end

    context "when the config is not valid" do
      before do
        allow(File).to receive(:read).and_return("# Just comments\n# and comments\n")
      end

      it "returns nil" do
        expect(subject).to be_nil
      end
    end
  end
end
