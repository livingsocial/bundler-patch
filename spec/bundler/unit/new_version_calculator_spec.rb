require_relative '../../spec_helper'

describe NewVersionCalculator do
  describe '#run' do
    let(:candidates) { %w(1.9.3-p550 2.1.4 ruby-2.1.4-p265 jruby-1.7.16.1) }

    def expect(old_version:, patched_versions: candidates)
      NewVersionCalculator.new(old_version, patched_versions).run
    end

    context 'ruby version' do
      it 'upgrades from 1.7 to 1.9.3-p550' do
        expect(old_version: '1.7').should eq '1.9.3-p550'
      end

      it 'upgrades from 1.8 to 1.9.3-p550' do
        expect(old_version: '1.8').should eq '1.9.3-p550'
      end

      it 'upgrades from 1.9 to 1.9.3-p550' do
        expect(old_version: '1.9').should eq '1.9.3-p550'
      end

      it 'upgrades 1.9.3-p484 to 1.9.3-p550' do
        expect(old_version: '1.9.3-p484').should eq '1.9.3-p550'
      end

      it 'upgrades from 2 to 2.1.4' do
        expect(old_version: '2').should eq '2.1.4'
      end

      it 'upgrades from 2.0.0-p95 to 2.1.4' do
        expect(old_version: '2.0.0-p95').should eq '2.1.4'
      end

      it 'upgrades 2.1.2 to 2.1.4' do
        expect(old_version: '2.1.2').should eq '2.1.4'
      end

      it 'upgrades from 2.1.2-p95 to 2.1.4' do
        expect(old_version: '2.1.2-p95').should eq '2.1.4'
      end

      it 'upgrades from ruby-2.1.2 to ruby-2.1.4-p265' do
        expect(old_version: 'ruby-2.1.2').should eq 'ruby-2.1.4-p265'
      end

      it 'upgrades from ruby-2.1.2-p0 to ruby-2.1.4-p265' do
        expect(old_version: 'ruby-2.1.2-p0').should eq 'ruby-2.1.4-p265'
      end

      it 'upgrades from ruby-2.1.2-p95 to ruby-2.1.4-p265' do
        expect(old_version: 'ruby-2.1.2-p95').should eq 'ruby-2.1.4-p265'
      end

      it 'upgrades from jruby-1.6.5 to jruby-1.7.16.1' do
        expect(old_version: 'jruby-1.6.5').should eq 'jruby-1.7.16.1'
      end

      it 'upgrades from jruby-1.7 to jruby-1.7.16.1' do
        expect(old_version: 'jruby-1.7').should eq 'jruby-1.7.16.1'
      end

      it 'upgrades jruby-1.7.16 to jruby-1.7.16.1' do
        expect(old_version: 'jruby-1.7.16').should eq 'jruby-1.7.16.1'
      end
    end

    context 'gem version' do
      it 'do not upgrade to major version' do
        expect(old_version: '2.4', patched_versions: %w(3.1.1)).should eq nil
      end

      it 'upgrade from rails 3.2.2 to 3.2.22.2' do
        expect(old_version: '3.2.2', patched_versions: %w(3.2.22.2)).should eq '3.2.22.2'
      end
    end
  end
end
