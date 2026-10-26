# frozen_string_literal: true

describe EventMailer do
  let(:event_mailer) { EventMailer.new('', '', '')}
  let(:event) {
    {:record=>
      {:user=>
        {:uid=>"ID8434CD6E8E",
         :email=>"admin@barong.io",
         :role=>"admin",
         :level=>1,
         :otp=>false,
         :state=>"active",
         :referral_uid=>nil,
         :created_at=>"2020-05-26T07:01:04Z",
         :updated_at=>"2020-05-26T08:30:54Z"},
       :user_ip=>"::1",
       :user_agent=>"PostmanRuntime/7.25.0"},
     :name=>"system.session.create",
     :state=>"sdasd"
    }
  }

  describe "#nested_hash_value" do
    it 'return event value' do
      expect(event_mailer.send(:safe_dig, event, %i[name])).to eq event[:name]
      expect(event_mailer.send(:safe_dig, event, %i[record user state])).to eq event[:record][:user][:state]
      expect(event_mailer.send(:safe_dig, event, %i[record user uid])).to eq event[:record][:user][:uid]
      expect(event_mailer.send(:safe_dig, event, %i[record user_agent])).to eq event[:record][:user_agent]
      expect(event_mailer.send(:safe_dig, event, %i[record user_ip])).to eq event[:record][:user_ip]
      expect(event_mailer.send(:safe_dig, event, %i[record name])).to eq nil
    end
  end

  describe "#skip_event" do
    context 'AND expression' do
      let(:expression) { {
        :and=>
          {:"record.user_ip"=>"::1", :"record.user.role"=>"member"}
        }
      }

      it 'should skip event' do
        expect(event_mailer.send(:skip_event, event, expression)).to eq true
      end

      it 'shouldnt skip event' do
        expression[:and][:"record.user.role"] = 'admin'
        expect(event_mailer.send(:skip_event, event, expression)).to eq false
      end
    end

    context 'OR expression' do
      let(:expression) { {
        :or=>
          {:"record.user_ip"=>"::1", :"record.user.role"=>"member"}
        }
      }

      it 'shouldnt skip event' do
        expect(event_mailer.send(:skip_event, event, expression)).to eq false
      end

      it 'should skip event' do
        expression[:or][:"record.user_ip"] = 'test'
        expect(event_mailer.send(:skip_event, event, expression)).to eq true
      end
    end

    context 'NOT expression' do
      let(:expression) { {
        :not=>
          {:"record.user_ip"=>"::1"}
        }
      }

      it 'shoul skip event' do
        expect(event_mailer.send(:skip_event, event, expression)).to eq true
      end

      it 'shouldnt skip event' do
        expression[:not][:"record.user_ip"] = 'test'
        expect(event_mailer.send(:skip_event, event, expression)).to eq false
      end

      it 'should skip event' do
        expression[:not][:'record.user.email'] = 'admin@barong.io'
        expect(event_mailer.send(:skip_event, event, expression)).to eq true
      end

      it 'shouldnt skip event' do
        expression[:not][:'record.user.email'] = 'admin1@barong.io'
        expect(event_mailer.send(:skip_event, event, expression)).to eq false
      end
    end

    context 'array value' do
      let(:withdraw) { { record: { state: 'accepted', currency: 'usd' } } }

      it 'should not skip event when the value is in the list (AND)' do
        expression = { and: { 'record.state': %w[accepted succeed rejected] } }
        expect(event_mailer.send(:skip_event, withdraw, expression)).to eq false
      end

      it 'should skip event when the value is not in the list (AND)' do
        expression = { and: { 'record.state': %w[succeed rejected] } }
        expect(event_mailer.send(:skip_event, withdraw, expression)).to eq true
      end

      it 'should combine array and scalar values (AND)' do
        expression = { and: { 'record.state': %w[accepted succeed], 'record.currency': 'btc' } }
        expect(event_mailer.send(:skip_event, withdraw, expression)).to eq true
      end

      it 'should not skip event when one value matches (OR)' do
        expression = { or: { 'record.state': %w[failed], 'record.currency': %w[usd try] } }
        expect(event_mailer.send(:skip_event, withdraw, expression)).to eq false
      end

      it 'should skip event when the value is in the list (NOT)' do
        expression = { not: { 'record.state': %w[processing accepted] } }
        expect(event_mailer.send(:skip_event, withdraw, expression)).to eq true
      end

      it 'should not skip event when the value is not in the list (NOT)' do
        expression = { not: { 'record.state': %w[processing confirming] } }
        expect(event_mailer.send(:skip_event, withdraw, expression)).to eq false
      end
    end
  end

  describe '#handle_message' do
    let!(:create_member_permission) { create :permission, role: 'member' }
    let(:user) { create(:user) }
    let(:events) {
      [{ name: 'Label Created', key: 'label.created', exchange: 'barong_model',
         expression: { and: { 'record.key': 'phone' } },
         templates: { en: { subject: 'Phone verified', template_path: 'label.en.html.erb' } } }]
    }
    let(:exchanges) { { barong_model: { name: 'barong.events.model', signer: 'barong' } } }
    let(:mailer) { EventMailer.new(events, exchanges, {}) }
    let(:channel) { double('channel', ack: true, reject: true) }
    let(:delivery_info) { OpenStruct.new(exchange: 'barong.events.model', routing_key: 'label.created', delivery_tag: 42) }
    let(:label_key) { 'phone' }
    let(:payload) {
      { verified: [:barong],
        payload: { event: { name: 'model.label.created', record: { key: label_key, user: { uid: user.uid } } } } }
    }

    before do
      mailer.instance_variable_set(:@bunny_channel, channel)
      allow(mailer).to receive(:verify_jwt).and_return(payload)
    end

    # EventMailer#initialize registers Kernel.at_exit { unlisten }
    after { mailer.instance_variable_set(:@bunny_channel, nil) }

    it 'delivers the email and acknowledges the message' do
      expect(Postmaster).to receive(:process_payload).and_return(double(deliver_now: true))
      mailer.send(:handle_message, delivery_info, {}, 'jwt')
      expect(channel).to have_received(:ack).with(42).once
      expect(channel).not_to have_received(:reject)
    end

    context 'event filtered out by the expression' do
      let(:label_key) { 'email' }

      it 'acknowledges the message without delivering' do
        expect(Postmaster).not_to receive(:process_payload)
        mailer.send(:handle_message, delivery_info, {}, 'jwt')
        expect(channel).to have_received(:ack).with(42).once
        expect(channel).not_to have_received(:reject)
      end
    end

    context 'unsupported user language' do
      let(:user) { create(:user, data: { language: 'de' }.to_json) }

      it 'acknowledges the message without delivering' do
        expect(Postmaster).not_to receive(:process_payload)
        mailer.send(:handle_message, delivery_info, {}, 'jwt')
        expect(channel).to have_received(:ack).with(42).once
        expect(channel).not_to have_received(:reject)
      end
    end

    context 'delivery error' do
      it 'rejects the message (dead letter -> retry queue)' do
        expect(Postmaster).to receive(:process_payload).and_raise(StandardError, 'smtp down')
        mailer.send(:handle_message, delivery_info, {}, 'jwt')
        expect(channel).to have_received(:reject).with(42).once
        expect(channel).not_to have_received(:ack)
      end
    end
  end
end
