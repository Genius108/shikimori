require 'cancan/matchers'

describe Version do
  describe 'relations' do
    it { is_expected.to belong_to :user }
    it { is_expected.to belong_to :moderator }
    it { is_expected.to belong_to :item }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of :item }
    it { is_expected.to validate_presence_of :item_diff }
  end

  describe 'state_machine' do
    let(:anime) { build_stubbed :anime }
    let(:video) { create :anime_video, anime: anime, episode: 2 }
    let(:moderator) { build_stubbed :user }
    subject(:version) { create :version_anime_video, item_id: video.id, item_diff: { episode: [1,2] }, state: state }

    before { allow(version).to receive :apply_changes! }
    before { allow(version).to receive :rollback_changes! }

    describe '#accept' do
      before { version.accept! moderator }

      describe 'from pending' do
        let(:state) { :pending }

        it do
          expect(version).to be_accepted
          expect(version.moderator).to eq moderator
          expect(version).to have_received :apply_changes!
          expect(version).to_not have_received :rollback_changes!
        end
      end
    end

    describe '#take' do
      before { version.take! moderator }

      describe 'from pending' do
        let(:state) { :pending }

        it do
          expect(version).to be_taken
          expect(version.moderator).to eq moderator
          expect(version).to have_received :apply_changes!
          expect(version).to_not have_received :rollback_changes!
        end
      end
    end

    describe '#reject' do
      before { version.reject! moderator }

      describe 'from accepted_pending' do
        let(:state) { :accepted_pending }

        it do
          expect(version).to be_rejected
          expect(version).to_not have_received :apply_changes!
          expect(version).to have_received :rollback_changes!
        end
      end

      describe 'from pending' do
        let(:state) { :pending }

        it do
          expect(version).to be_rejected
          expect(version.moderator).to eq moderator
          expect(version).to_not have_received :apply_changes!
          expect(version).to_not have_received :rollback_changes!
        end
      end
    end
  end

  describe 'instance methods' do
    let(:anime) { create :anime, episodes: 10 }
    let(:version) { create :version, item: anime, item_diff: { episodes: [1,2] } }

    describe '#apply_changes' do
      before { version.apply_changes! }

      it do
        expect(anime.reload.episodes).to eq 2
        expect(version.reload.item_diff['episodes'].first).to eq 10
      end
    end

    describe '#rollback_changes' do
      before { version.rollback_changes! }
      it { expect(anime.reload.episodes).to eq 1 }
    end
  end

  describe 'permissions' do
    let(:version) { build_stubbed :version }

    context 'user_chagnes_moderator' do
      subject { Ability.new build_stubbed(:user, :user_changes_moderator) }
      it { is_expected.to be_able_to :manage, version }
    end

    context 'guest' do
      subject { Ability.new nil }

      describe 'own version' do
        let(:version) { build_stubbed :version, user_id: User::GuestID }

        it { is_expected.to be_able_to :create, version }
        it { is_expected.to_not be_able_to :destroy, version }
        it { is_expected.to_not be_able_to :manage, version }
      end

      describe 'user version' do
        it { is_expected.to_not be_able_to :create, version }
        it { is_expected.to_not be_able_to :destroy, version }
        it { is_expected.to_not be_able_to :manage, version }
      end
    end

    context 'user' do
      let(:user) { build_stubbed :user, :user }
      subject { Ability.new user }

      describe 'own version' do
        let(:version) { build_stubbed :version, user: user }

        it { is_expected.to be_able_to :create, version }
        it { is_expected.to be_able_to :destroy, version }
        it { is_expected.to_not be_able_to :manage, version }
      end

      describe 'user version' do
        it { is_expected.to_not be_able_to :create, version }
        it { is_expected.to_not be_able_to :destroy, version }
        it { is_expected.to_not be_able_to :manage, version }
      end
    end
  end
end
